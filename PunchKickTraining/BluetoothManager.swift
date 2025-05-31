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
    @Published var currentForcePercentage: Double = 0.0
    @Published var sumForceInRound: Double = 0.0
    @Published var strikeCountInRound: Int = 0

    private var lastAxisDirection: [String: Double] = [:]
    private var motionStartTime: Date? = nil

    private var currentMotionStartTime: Date?
    private var currentMotionMagnitudes: [Double] = []
    private var isMovementActive = false
    private var motionStartVector: SIMD3<Double>?
    private var waitingForMotionToSettle = false
    private var lastStrikeTime: Date?

    private let motionManager = CMMotionManager()

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

    // MARK: - CBCentralManagerDelegate
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

    // MARK: - Phone Accelerometer
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

    // MARK: - Motion Logic
    func processMotion(x: Double, y: Double, z: Double) {
        let now = Date()
        let currentVector = SIMD3<Double>(x, y, z)
        let magnitude = simd_length(currentVector)
        let settlingThreshold = accelerationThreshold * 0.9

        if let lastStrike = lastStrikeTime,
           now.timeIntervalSince(lastStrike) < postStrikeCooldown {
            return
        }

        if waitingForMotionToSettle {
            if magnitude < settlingThreshold {
                waitingForMotionToSettle = false
                print("[Motion Settled] Magnitude dropped to \(String(format: "%.2f", magnitude)) < \(String(format: "%.2f", settlingThreshold))")
            }
            return
        }

        if !isMovementActive {
            if magnitude >= settlingThreshold {
                currentMotionStartTime = now
                currentMotionMagnitudes = [magnitude]
                motionStartVector = currentVector
                isMovementActive = true
            }
            return
        }

        currentMotionMagnitudes.append(magnitude)
        let duration = now.timeIntervalSince(currentMotionStartTime ?? now)
        let maxMagnitude = currentMotionMagnitudes.max() ?? 0.0

        print("""
        [Motion Check - Vector]
        Duration: \(String(format: "%.3f", duration))s
        Max Magnitude: \(String(format: "%.2f", maxMagnitude))
        Threshold: \(accelerationThreshold)
        """)

        if duration >= 2.0, maxMagnitude < accelerationThreshold {
            print("[Motion Auto-Reset] Idle motion for \(String(format: "%.2f", duration))s with max \(String(format: "%.2f", maxMagnitude))")
            isMovementActive = false
            currentMotionStartTime = nil
            currentMotionMagnitudes = []
            motionStartVector = nil
            return
        }

        if duration >= minMotionDuration, maxMagnitude >= accelerationThreshold {
            let averageMagnitude = currentMotionMagnitudes.reduce(0.0, +) / Double(currentMotionMagnitudes.count)
            let force = averageMagnitude * duration * 9.81 * 3.0
            print("[*** New Strike ***] Force: \(String(format: "%.2f", force))N")
            simulateStrike(force: force)

            lastStrikeTime = now
            isMovementActive = false
            currentMotionStartTime = nil
            currentMotionMagnitudes = []
            motionStartVector = nil
            waitingForMotionToSettle = true
        }
    }

    // MARK: - Strike Handling
    private func simulateStrike(force: Double) {
        guard isTrainingActive else { return }

        totalStrikes += 1
        totalForce += force
        strikeCountInRound += 1
        sumForceInRound += force

        if force > maxForce { maxForce = force }
        averageForce = totalStrikes > 0 ? (totalForce / Double(totalStrikes)) : 0
        currentForce = force

        if let currentGoal = sessionManager?.currentRoundGoal, currentGoal > 0 {
            currentForcePercentage = min((sumForceInRound / currentGoal) * 100.0, 100.0)
            if currentForcePercentage >= 100.0 {
                sessionManager?.advanceToNextRound()
                sumForceInRound = 0
                strikeCountInRound = 0
                currentForcePercentage = 0
            }
        }

        if trainingProgressPercentage >= 100.0 {
            stopTrainingCallback?()
        }
    }

    var trainingProgressPercentage: Double {
        guard let sessionManager = sessionManager, !sessionManager.rounds.isEmpty else { return 0.0 }
        let totalTrainingGoal = sessionManager.rounds.map { $0.goalForce }.reduce(0.0, +)
        guard totalTrainingGoal > 0 else { return 0.0 }
        return min((totalForce / totalTrainingGoal) * 100.0, 100.0)
    }

    func resetMetrics() {
        totalStrikes = 0
        totalForce = 0.0
        maxForce = 0.0
        averageForce = 0.0
        currentForce = 0.0
        currentForcePercentage = 0.0
        sumForceInRound = 0.0
        strikeCountInRound = 0
        lastAxisDirection = [:]
        motionStartTime = nil
    }

    func updateMetricsFromWatch(totalStrikes: Int, totalForce: Double, maxForce: Double, averageForce: Double, timestamp: TimeInterval) {
        guard isTrainingActive else { return }

        DispatchQueue.main.async {
            self.totalStrikes = totalStrikes
            self.totalForce = totalForce
            self.maxForce = maxForce
            self.averageForce = averageForce

            if let currentGoal = self.sessionManager?.currentRoundGoal, currentGoal > 0 {
                self.currentForcePercentage = min((self.sumForceInRound / currentGoal) * 100.0, 100.0)
            }

            print("""
            📈 Metrics Updated from Watch:
            Strikes: \(totalStrikes)
            Force: \(totalForce)
            Max: \(maxForce)
            Avg: \(String(format: "%.2f", averageForce))
            """)
        }
    }

    func updateMetricsFromWatch(_ update: MetricUpdate) {
        updateMetricsFromWatch(
            totalStrikes: update.totalStrikes,
            totalForce: update.totalForce,
            maxForce: update.maxForce,
            averageForce: update.averageForce,
            timestamp: update.timestamp
        )
    }
}

