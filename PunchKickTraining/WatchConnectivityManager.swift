import Foundation
import WatchConnectivity

// MARK: - Struct for Watch Metrics

struct MetricUpdate: Codable {
    let totalStrikes: Int
    let totalForce: Double
    let maxForce: Double
    let averageForce: Double
    let timestamp: TimeInterval
}

// MARK: - WatchConnectivityManager

class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchConnectivityManager()
    var bluetoothManager: BluetoothManager?

    var pendingMessage: [String: Any]? = nil

    private var startRetryCount = 0
    private var startRetryTimer: Timer?

    private var stopRetryCount = 0
    private var stopRetryTimer: Timer?

    private let maxRetries = 5
    private let retryInterval: TimeInterval = 2.0

    private override init() {
        print("⚙️ WatchConnectivityManager initialized")
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Public Commands

    func sendStartCommand() {
        pendingMessage = ["command": "start"]
        startRetryCount = 0
        attemptStartCommand()
    }

    func sendStopCommand() {
        pendingMessage = ["command": "stop"]
        stopRetryCount = 0
        attemptStopCommand()
    }

    // MARK: - Internal Retry Logic

    private func attemptStartCommand() {
        guard let message = pendingMessage else { return }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("❌ Start send error: \(error.localizedDescription)")
            }
            print("📤 Sent start command to Watch.")
            startRetryTimer?.invalidate()
        } else {
            if startRetryCount < maxRetries {
                print("🔁 Retrying start command (\(startRetryCount + 1)/\(maxRetries))...")
                startRetryCount += 1
                startRetryTimer?.invalidate()
                startRetryTimer = Timer.scheduledTimer(withTimeInterval: retryInterval, repeats: false) { _ in
                    self.attemptStartCommand()
                }
            } else {
                print("⛔️ Max retries reached for start command.")
            }
        }
    }

    private func attemptStopCommand() {
        guard let message = pendingMessage else { return }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("❌ Stop send error: \(error.localizedDescription)")
            }
            print("📤 Sent stop command to Watch.")
            stopRetryTimer?.invalidate()
        } else {
            if stopRetryCount < maxRetries {
                print("🔁 Retrying stop command (\(stopRetryCount + 1)/\(maxRetries))...")
                stopRetryCount += 1
                stopRetryTimer?.invalidate()
                stopRetryTimer = Timer.scheduledTimer(withTimeInterval: retryInterval, repeats: false) { _ in
                    self.attemptStopCommand()
                }
            } else {
                print("⛔️ Max retries reached for stop command.")
            }
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("📡 iPhone WCSession activation complete. State: \(activationState.rawValue)")
        if let error = error {
                print("❌ Activation error: \(error.localizedDescription)")
            }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("🔄 Watch reachability changed: \(session.isReachable)")
        if session.isReachable, let message = pendingMessage {
            print("📤 Retrying queued message: \(message)")
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("❌ Retry failed: \(error.localizedDescription)")
            }
            pendingMessage = nil
        }
    }

    /*func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("📩 Phone received raw message: \(message)")
        DispatchQueue.main.async {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
                let decoded = try JSONDecoder().decode(MetricUpdate.self, from: jsonData)

                print("📈 Received metrics: \(decoded)")

                if self.bluetoothManager?.sensorSource == "Watch" {
                    self.bluetoothManager?.updateMetricsFromWatch(decoded)
                }
            } catch {
                print("❌ Failed to decode MetricUpdate: \(error.localizedDescription)")
            }
        }
    }*/
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("📩 Phone received raw message: \(message)")

        // Only attempt decoding if message has all required keys
        let expectedKeys = ["totalStrikes", "totalForce", "maxForce", "averageForce", "timestamp"]
        let hasAllKeys = expectedKeys.allSatisfy { message.keys.contains($0) }

        guard hasAllKeys else {
            print("⚠️ Skipping message - doesn't contain all MetricUpdate keys.")
            return
        }

        DispatchQueue.main.async {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
                let decoded = try JSONDecoder().decode(MetricUpdate.self, from: jsonData)
                print("📈 Decoded MetricUpdate: \(decoded)")

                if self.bluetoothManager?.sensorSource == "Watch" {
                    self.bluetoothManager?.updateMetricsFromWatch(decoded)
                }
            } catch {
                print("❌ Failed to decode MetricUpdate: \(error.localizedDescription)")
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) { }
}
