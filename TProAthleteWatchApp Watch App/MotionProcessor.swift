//  MotionProcessor.swift (for Watch App)
//  Handles accelerometer motion analysis and metric tracking

import Foundation
import CoreMotion
import simd
import WatchConnectivity

class MotionProcessor: ObservableObject {
    static let shared = MotionProcessor()

    // MARK: - Settings (to be injected from iPhone)
    var accelerationThreshold: Double = 1.5
    var postStrikeCooldown: TimeInterval = 0.2
    var minMotionDuration: TimeInterval = 0.15

    // MARK: - Motion Tracking
    private let motionManager = CMMotionManager()
    private var currentMotionStartTime: Date?
    private var currentMotionMagnitudes: [Double] = []
    private var motionStartVector: SIMD3<Double>?
    private var isMovementActive = false
    private var waitingForMotionToSettle = false
    private var lastStrikeTime: Date?

    // MARK: - Metrics
    private(set) var totalStrikes = 0
    private(set) var totalForce: Double = 0.0
    private(set) var maxForce: Double = 0.0
    private(set) var averageForce: Double = 0.0

    private var metricSendTimer: Timer?

    private init() {}

    
    //---
    func startProcessing() {
        guard motionManager.isAccelerometerAvailable else {
            print("Accelerometer not available on Watch")
            return
        }

        resetMetrics()

        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            self.processMotion(x: data.acceleration.x, y: data.acceleration.y, z: data.acceleration.z)
        }

        metricSendTimer?.invalidate()
        metricSendTimer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            print("⏱ Timer fired - attempting to send metrics")
            self?.sendMetricsToPhone()
        }

        // ✅ ADD TIMER TO RUNLOOP
        if let timer = metricSendTimer {
            RunLoop.main.add(timer, forMode: .common)
        }

        print("📡 Watch accelerometer processing started")
    }
    //---

    func stopProcessing() {
        motionManager.stopAccelerometerUpdates()
        metricSendTimer?.invalidate()
        metricSendTimer = nil
        print("📴 Watch accelerometer processing stopped")
    }

    
    private func processMotion(x: Double, y: Double, z: Double) {
        let now = Date()
        let currentVector = SIMD3<Double>(x, y, z)
        let magnitude = simd_length(currentVector)

        let settlingThreshold = accelerationThreshold * 0.8
        let validationThreshold = accelerationThreshold * 1.1  // relaxed from 1.25

        // Prevent too-frequent strikes (cooldown)
        if let lastStrike = lastStrikeTime,
           now.timeIntervalSince(lastStrike) < postStrikeCooldown {
            return
        }

        // Wait for motion to settle before reactivating
        if waitingForMotionToSettle {
            if magnitude < settlingThreshold {
                waitingForMotionToSettle = false
                print("[Motion Settled] Magnitude dropped to \(String(format: "%.2f", magnitude))")
            }
            return
        }

        // Begin new motion tracking
        if !isMovementActive {
            if magnitude >= settlingThreshold {
                currentMotionStartTime = now
                currentMotionMagnitudes = [magnitude]
                motionStartVector = currentVector
                isMovementActive = true
            }
            return
        }

        // Ongoing motion tracking
        currentMotionMagnitudes.append(magnitude)
        let duration = now.timeIntervalSince(currentMotionStartTime ?? now)
        let maxMagnitude = currentMotionMagnitudes.max() ?? 0.0

        print("[Motion Check] Duration: \(String(format: "%.3f", duration))s, Max: \(String(format: "%.2f", maxMagnitude))")

        // Idle reset
        if duration >= 2.0 && maxMagnitude < accelerationThreshold {
            print("[Auto-Reset] Idle segment")
            resetMotionState()
            return
        }

        // Check for valid strike
        if duration >= minMotionDuration && maxMagnitude >= validationThreshold {
            // Directional filtering
            if let startVector = motionStartVector {
                let normalizedStart = simd_normalize(startVector)
                let normalizedCurrent = simd_normalize(currentVector)
                let dotProduct = simd_dot(normalizedStart, normalizedCurrent)
                print("[Direction Check] Dot product: \(String(format: "%.2f", dotProduct))")

                if dotProduct < 0.8 {
                    print("[Direction Reversal] Ignoring reversed motion")
                    resetMotionState()
                    return
                }
            }

            // Compute force and register strike
            let averageMagnitude = currentMotionMagnitudes.reduce(0.0, +) / Double(currentMotionMagnitudes.count)
            let force = averageMagnitude * duration * 9.81 * 3.0
            simulateStrike(force: force)
            lastStrikeTime = now
            resetMotionState(settle: true)
        }
        // If duration was valid but max magnitude was just below threshold
        else if duration >= minMotionDuration && maxMagnitude >= (validationThreshold - 0.05) {
            print("[Near Miss] Max \(String(format: "%.2f", maxMagnitude)) < Threshold \(String(format: "%.2f", validationThreshold))")
            resetMotionState()
        }
        // Invalid motion, reset silently
        else if duration >= minMotionDuration && maxMagnitude < validationThreshold {
            print("[Weak Motion] Max \(String(format: "%.2f", maxMagnitude)) < Validation Threshold \(String(format: "%.2f", validationThreshold)) — not a strike")
            resetMotionState()
        }
    }

    // MARK: - Motion Reset Helper
    private func resetMotionState(settle: Bool = false) {
        isMovementActive = false
        currentMotionStartTime = nil
        currentMotionMagnitudes = []
        motionStartVector = nil
        waitingForMotionToSettle = settle
    }
    
    private func simulateStrike(force: Double) {
        totalStrikes += 1
        totalForce += force
        if force > maxForce { maxForce = force }
        averageForce = totalStrikes > 0 ? totalForce / Double(totalStrikes) : 0

        print("[Strike] Force: \(String(format: "%.2f", force)) N | Total: \(totalStrikes)")
    }

    private func sendMetricsToPhone() {
        let session = WCSession.default

        guard session.activationState == .activated else {
            print("⚠️ WCSession is not activated. Metrics not sent.")
            return
        }

        guard session.isReachable else {
            print("📵 Phone not reachable — metrics not sent")
            return
        }

        let payload: [String: Any] = [
            "totalStrikes": totalStrikes,
            "totalForce": totalForce,
            "maxForce": maxForce,
            "averageForce": averageForce,
            "timestamp": Date().timeIntervalSince1970
        ]

        
        print("📤 Attempting to send metrics: \(payload)")
        session.sendMessage(payload, replyHandler: nil) { error in
            print("❌ Failed to send metrics to phone: \(error.localizedDescription)")
        }
    }

    func resetMetrics() {
        totalStrikes = 0
        totalForce = 0.0
        maxForce = 0.0
        averageForce = 0.0
    }
}
