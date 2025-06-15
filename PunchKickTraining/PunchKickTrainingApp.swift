import SwiftUI
import Firebase
import FirebaseAuth

@main
struct PunchKickTrainingApp: App {
    @StateObject private var profileManager = UserProfileManager()
    @StateObject private var bluetoothManager = BluetoothManager()
    @State private var selectedTraining: SavedTraining? = nil

    init() {
        FirebaseApp.configure()
        let _ = WatchConnectivityManager.shared

        // Sign in anonymously
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { result, error in
                if let error = error {
                    print("❌ Firebase Auth error: \(error.localizedDescription)")
                } else if let user = result?.user {
                    print("✅ Signed in anonymously with UID: \(user.uid)")
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootLauncherView(selectedTraining: $selectedTraining)
                .environmentObject(profileManager)
                .environmentObject(bluetoothManager)
        }
    }
}
