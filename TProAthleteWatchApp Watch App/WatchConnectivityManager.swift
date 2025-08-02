import Foundation
import WatchConnectivity
import CoreMotion

class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchConnectivityManager()
    private let session = WCSession.default

    override private init() {
        super.init()
        activateSession()
    }

    private func activateSession() {
        guard WCSession.isSupported() else {
            print("❌ WCSession not supported on this device.")
            return
        }

        WCSession.default.delegate = self
        WCSession.default.activate()
        print("📲 WCSession activation requested on Watch.")
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ Watch session activation failed: \(error.localizedDescription)")
            return
        }

        print("🟢 Watch session activated. State: \(activationState.rawValue)")

        // 🧪 Optional: Send test message to iPhone after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard session.activationState == .activated else {
                print("⚠️ WCSession not activated yet. Skipping test message.")
                return
            }

            if session.isReachable {
                let testMessage: [String: Any] = ["hello": "watchTest"]
                session.sendMessage(testMessage, replyHandler: nil) { sendError in
                    print("❌ Failed to send test message: \(sendError.localizedDescription)")
                }
                print("📤 Sent test message from Watch to Phone.")
            } else {
                print("📵 Phone not reachable from Watch (test message not sent).")
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("🔄 Watch reachability changed: \(session.isReachable)")
    }
    
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("📩 Message handler on Watch was called with: \(message)")
        
        guard session.activationState == .activated else {
            print("⚠️ Received message but session not activated. Ignoring.")
            return
        }

        // Handle command messages
        if let command = message["command"] as? String {
            print("📩 Received command from iPhone: \(command)")
            switch command {
            case "start":
                MotionProcessor.shared.startProcessing()
            case "stop":
                MotionProcessor.shared.stopProcessing()
            default:
                print("⚠️ Unknown command received: \(command)")
            }
        }

        // Handle training settings updates
        if let settings = message["settings"] as? [String: Any] {
            if let minDuration = settings["minMotionDuration"] as? Double {
                MotionProcessor.shared.minMotionDuration = minDuration
                print("⚙️ Updated minMotionDuration to \(minDuration)")
            }
            if let cooldown = settings["postRepCooldown"] as? Double {
                MotionProcessor.shared.postRepCooldown = cooldown
                print("⚙️ Updated postRepCooldown to \(cooldown)")
            }
            if let threshold = settings["accelerationThreshold"] as? Double {
                MotionProcessor.shared.accelerationThreshold = threshold
                print("⚙️ Updated accelerationThreshold to \(threshold)")
            }
        }
    }
    
    
    /*func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("📩 Message handler on Watch was called with: \(message)")

        guard session.activationState == .activated else {
            print("⚠️ Received message but session not activated. Ignoring.")
            return
        }

        if let command = message["command"] as? String {
            print("📩 Received command from iPhone: \(command)")

            switch command {
            case "start":
                MotionProcessor.shared.startProcessing()
            case "stop":
                MotionProcessor.shared.stopProcessing()
            default:
                print("⚠️ Unknown command received: \(command)")
            }
        } else {
            print("⚠️ Invalid message structure: \(message)")
        }
    }*/
}
