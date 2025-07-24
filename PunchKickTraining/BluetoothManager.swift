// Refactored BluetoothManager.swift

import Foundation
import CoreBluetooth
import SwiftUI
import Combine
import CoreMotion
import simd
import WatchConnectivity

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // MARK: - BLE
    private var centralManager: CBCentralManager!
    private var punchPeripheral: CBPeripheral?
    
    let punchServiceUUID = CBUUID(string: "FFE0")
    let accelerometerCharUUID = CBUUID(string: "FFE1")
    
    // MARK: - Settings & State
    @AppStorage("accelerationThreshold") var accelerationThreshold: Double = 1.5
    @AppStorage("postStrikeCooldown") var postStrikeCooldown: TimeInterval = 0.2
    @AppStorage("minMotionDuration") var minMotionDuration: TimeInterval = 0.15
    
    @AppStorage("sensorSource") var sensorSource: String = "Phone" {
        didSet {
            print("[Sensor] Sensor source changed to: \(sensorSource)")
            configureSensorSource()
            
            if sensorSource == "Phone" {
                centralManager.stopScan()
                if let peripheral = punchPeripheral {
                    centralManager.cancelPeripheralConnection(peripheral)
                    print("[Bluetooth] Disconnected from Arduino (Phone mode active)")
                }
            }
        }
    }
    
    var connectionStatusText: String {
        switch sensorSource {
        case "Watch":
            return WCSession.default.isReachable ? "Connected to Watch" : "Disconnected from Watch"
        case "Arduino":
            return isConnected ? "Connected to Arduino" : "Disconnected from Arduino"
        default:
            return "Phone Sensors"
        }
    }
    
    var isSensorConnected: Bool {
        switch sensorSource {
        case "Watch":
            return WCSession.default.isReachable
        case "Arduino":
            return isConnected
        default:
            return true
        }
    }
    
    @Published var isConnected = false
    @Published var isTrainingActive = false
    weak var announcer: Announcer?
    weak var sessionManager: TrainingSessionManager?
    var stopTrainingCallback: (() -> Void)?
    
    // MARK: - Metrics
    @Published var totalStrikes = 0
    @Published var totalForce: Double = 0.0
    @Published var maxForce: Double = 0.0
    @Published var averageForce: Double = 0.0
    @Published var currentForce: Double = 0.0
    //@Published var currentForcePercentage: Double = 0.0
    @Published var currentRoundProgressPercentage: Double = 0.0
    @Published var sumForceInRound: Double = 0.0
    @Published var strikeCountInRound: Int = 0
    @Published var totalPoints: Double = 0.0
    
    @Published var forcePerRound: [Double] = []
    @Published var strikesPerRound: [Int] = []
    
    private var lastAxisDirection: [String: Double] = [:]
    private var motionStartTime: Date? = nil
    private var currentMotionStartTime: Date?
    private var currentMotionMagnitudes: [Double] = []
    private var isMovementActive = false
    private var motionStartVector: SIMD3<Double>?
    private var waitingForMotionToSettle = false
    private var lastStrikeTime: Date?
    
    private let motionManager = CMMotionManager()
    private var hasCalledStop = false
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        configureSensorSource()
    }
    
    // MARK: - Sensor Configuration
    func configureSensorSource() {
        motionManager.stopAccelerometerUpdates()
        
        if sensorSource == "Phone" {
            centralManager.stopScan()
            if let peripheral = punchPeripheral {
                centralManager.cancelPeripheralConnection(peripheral)
            }
            startSimulatedSensor()
        } else if sensorSource == "Arduino" {
            if centralManager.state == .poweredOn {
                centralManager.scanForPeripherals(withServices: [punchServiceUUID], options: nil)
            }
        } else {
            centralManager.stopScan()
            if let peripheral = punchPeripheral {
                centralManager.cancelPeripheralConnection(peripheral)
            }
            print("[Sensor] Awaiting external motion data from \(sensorSource)")
        }
    }
    
    // MARK: - CBCentralManagerDelegate and Peripheral
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn && sensorSource == "Arduino" {
            centralManager.scanForPeripherals(withServices: [punchServiceUUID], options: nil)
        } else {
            centralManager.stopScan()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        punchPeripheral = peripheral
        punchPeripheral?.delegate = self
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        peripheral.discoverServices([punchServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.forEach { service in
            if service.uuid == punchServiceUUID {
                peripheral.discoverCharacteristics([accelerometerCharUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        service.characteristics?.forEach {
            if $0.uuid == accelerometerCharUUID {
                peripheral.setNotifyValue(true, for: $0)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard announcer?.trainingStarted == true, isTrainingActive else { return }
        guard let value = characteristic.value, characteristic.uuid == accelerometerCharUUID else { return }
        
        let expectedSize = MemoryLayout<Float>.size * 3
        guard value.count == expectedSize else { return }
        
        let x = value.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Float.self) }
        let y = value.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Float.self) }
        let z = value.withUnsafeBytes { $0.load(fromByteOffset: 8, as: Float.self) }
        
        processMotion(x: Double(x), y: Double(y), z: Double(z))
    }
    
    private func startSimulatedSensor() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self,
                  self.sensorSource == "Phone",
                  self.isTrainingActive,
                  let data = data else { return }
            
            self.processMotion(x: data.acceleration.x, y: data.acceleration.y, z: data.acceleration.z)
        }
    }
    //---
    // MARK: - Motion Detection with Logging

    func processMotion(x: Double, y: Double, z: Double) {
        //print("📦 processMotion called")
        guard isTrainingActive, announcer?.trainingStarted == true else {
            print("⛔️ Motion ignored - training inactive or not started")
            return
        }
        if sessionManager?.isResting == true {
            //print("⏸ Ignoring motion during rest")
            return
        }

        let now = Date()
        let currentVector = SIMD3<Double>(x, y, z)
        let magnitude = simd_length(currentVector)
        let settlingThreshold = accelerationThreshold * 0.9

        if let lastStrike = lastStrikeTime,
           now.timeIntervalSince(lastStrike) < postStrikeCooldown {
            print("🕒 Cooling down: \(now.timeIntervalSince(lastStrike).rounded())s elapsed")
            return
        }

        if waitingForMotionToSettle {
            if magnitude < settlingThreshold {
                waitingForMotionToSettle = false
                print("🧘 Motion settled (mag: \(magnitude.rounded()))")
            }
            return
        }

        if !isMovementActive {
            if magnitude >= settlingThreshold {
                currentMotionStartTime = now
                currentMotionMagnitudes = [magnitude]
                motionStartVector = currentVector
                isMovementActive = true
                print("🏁 Movement started (mag: \(magnitude.rounded()))")
            }
            return
        }

        currentMotionMagnitudes.append(magnitude)
        let duration = now.timeIntervalSince(currentMotionStartTime ?? now)
        let maxMagnitude = currentMotionMagnitudes.max() ?? 0.0

        // Auto-reset for long low-motion sequences
        if duration >= 2.0, maxMagnitude < accelerationThreshold {
            print("🧹 Auto-reset motion: \(duration.rounded())s with max mag \(maxMagnitude.rounded())")
            isMovementActive = false
            currentMotionStartTime = nil
            currentMotionMagnitudes = []
            motionStartVector = nil
            return
        }

        // Trigger a strike
        if duration >= minMotionDuration, maxMagnitude >= accelerationThreshold {
            let averageMagnitude = currentMotionMagnitudes.reduce(0.0, +) / Double(currentMotionMagnitudes.count)
            let force = averageMagnitude * duration * 9.81 * 3.0

            print("""
            🎯 New Strike Detected
            print("- Duration: \(String(format: "%.3f", duration))s")
            - Avg Mag: \(averageMagnitude.rounded())
            - Force: \(force.rounded())N
            """)

            simulateStrike(force: force)

            lastStrikeTime = now
            isMovementActive = false
            currentMotionStartTime = nil
            currentMotionMagnitudes = []
            motionStartVector = nil
            waitingForMotionToSettle = true
        }
    }
    //----
    
    // MARK: - Simulate Strike with Logs

    private func simulateStrike(force: Double) {
        guard isTrainingActive else { return }

        totalStrikes += 1
        totalForce += force
        strikeCountInRound += 1
        sumForceInRound += force

        if force > maxForce { maxForce = force }
        averageForce = totalStrikes > 0 ? (totalForce / Double(totalStrikes)) : 0
        currentForce = force

        announcer?.updateStrikeCount(to: totalStrikes)
        announcer?.maybeAnnounceForce(totalForce)
        announcer?.maybeAnnounceProgress(trainingProgressPercentage)

        if let currentRoundIndex = sessionManager?.currentRoundIndex {
            if currentRoundIndex >= forcePerRound.count {
                forcePerRound += Array(repeating: 0.0, count: currentRoundIndex - forcePerRound.count + 1)
            }
            if currentRoundIndex >= strikesPerRound.count {
                strikesPerRound += Array(repeating: 0, count: currentRoundIndex - strikesPerRound.count + 1)
            }
            forcePerRound[currentRoundIndex] += force
            strikesPerRound[currentRoundIndex] += 1
        }

        if let currentRoundName = sessionManager?.currentRound?.name,
           let exercise = ExerciseManager.shared.getExercise(named: currentRoundName) {
            let addedPoints = force * exercise.pointsFactor
            totalPoints += addedPoints
            print("⭐️ Points: +\(addedPoints.rounded()) [\(exercise.pointsFactor)x]")
        }
        
        //Round Goal tracking
        if let sessionManager = sessionManager,
           sessionManager.trainingType == .forceDriven || sessionManager.trainingType == .strikesDriven,
           let goal = sessionManager.currentRoundGoal, goal > 0 {

            let progressSoFar: Double = sessionManager.trainingType == .forceDriven
                ? sumForceInRound
                : Double(strikeCountInRound)

            currentRoundProgressPercentage = min((progressSoFar / goal) * 100.0, 100.0)
            print("📈 Round Progress: \(currentRoundProgressPercentage.rounded())% of goal \(goal)")

            
            if !sessionManager.hasHandledCurrentRound && progressSoFar >= goal {
                print("✅ Round goal met — triggering round completion flow.")
                sumForceInRound = 0
                strikeCountInRound = 0
                currentRoundProgressPercentage = 0
                sessionManager.handleRoundCompletion()
            }
        }
        
       

        // Training completion
        let progress = trainingProgressPercentage
        print("📉 Training Progress: \(progress.rounded())%")
        

        if progress >= 100.0, !hasCalledStop {
            hasCalledStop = true
            print("🏁 Training Completed — Total Force: \(totalForce.rounded()), Total Strikes: \(totalStrikes)")
            sessionManager?.stopSessionTimer()
            announcer?.trainingStarted = false

            if let callback = stopTrainingCallback {
                stopTrainingCallback = nil // Prevent future calls
                callback()
            }
        }
    }

    var trainingProgressPercentage: Double {
        guard let sessionManager = sessionManager, !sessionManager.rounds.isEmpty else { return 0.0 }

        switch sessionManager.trainingType {
        case .timeDriven:
            let totalTime = sessionManager.rounds.map { $0.roundTime ?? 0 }.reduce(0, +)
            guard totalTime > 0 else { return 0.0 }
            let activeElapsed = sessionManager.activeElapsedTime
            return min((Double(activeElapsed) / Double(totalTime)) * 100.0, 100.0)

        case .forceDriven, .strikesDriven:
            let rounds = sessionManager.rounds

            let currentProgress = rounds.enumerated().map { index, round in
                if sessionManager.trainingType == .forceDriven,
                   let goalForce = round.goalForce, goalForce > 0 {
                    let achieved = forcePerRound.indices.contains(index) ? forcePerRound[index] : 0.0
                    return min(achieved, goalForce)
                } else if sessionManager.trainingType == .strikesDriven,
                          let goalStrikes = round.goalStrikes, goalStrikes > 0 {
                    let achieved = strikesPerRound.indices.contains(index) ? Double(strikesPerRound[index]) : 0.0
                    return min(achieved, Double(goalStrikes))
                }
                return 0.0
            }.reduce(0.0, +)

            let totalGoal = rounds.map { round in
                if sessionManager.trainingType == .forceDriven {
                    return round.goalForce ?? 0
                } else {
                    return Double(round.goalStrikes ?? 0)
                }
            }.reduce(0.0, +)

            guard totalGoal > 0 else { return 0.0 }
            return min((currentProgress / totalGoal) * 100.0, 100.0)
        }
    }

    func resetMetrics() {
        totalStrikes = 0
        totalForce = 0.0
        maxForce = 0.0
        averageForce = 0.0
        currentForce = 0.0
        currentRoundProgressPercentage = 0.0
        sumForceInRound = 0.0
        strikeCountInRound = 0
        totalPoints = 0.0
        lastAxisDirection = [:]
        motionStartTime = nil
        hasCalledStop = false
        
       

        if let sessionManager = sessionManager {
            let roundCount = sessionManager.rounds.count
            forcePerRound = Array(repeating: 0.0, count: roundCount)
            strikesPerRound = Array(repeating: 0, count: roundCount)
        } else {
            forcePerRound = []
            strikesPerRound = []
        }
    }

    func updateMetricsFromWatch(_ update: MetricUpdate) {
        guard isTrainingActive else { return }
        DispatchQueue.main.async {
            self.totalStrikes = update.totalStrikes
            self.totalForce = update.totalForce
            self.maxForce = update.maxForce
            self.averageForce = update.averageForce
            self.announcer?.updateStrikeCount(to: update.totalStrikes)
        }
    }
    
    func resetMotionState() {
        isMovementActive = false
        currentMotionStartTime = nil
        currentMotionMagnitudes = []
        motionStartVector = nil
        waitingForMotionToSettle = false
        print("🔄 Motion state reset")
    }
    
    
}
