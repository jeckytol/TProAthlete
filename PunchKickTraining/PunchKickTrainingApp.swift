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
        PunchKickTrainingApp.authenticateAndPreload()
    }

    static func authenticateAndPreload() {
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { result, error in
                if let error = error {
                    print("❌ Firebase Auth error: \(error.localizedDescription)")
                } else if let user = result?.user {
                    print("✅ Signed in anonymously with UID: \(user.uid)")
                    preloadSharedData()
                }
            }
        } else {
            print("ℹ️ Already signed in, UID: \(Auth.auth().currentUser?.uid ?? "unknown")")
            preloadSharedData()
        }
    }

    private static func preloadSharedData() {
        print("📦 Preloading shared data...")
        ExerciseManager.shared.fetchExercises()
    }

    var body: some Scene {
        WindowGroup {
            RootLauncherView(selectedTraining: $selectedTraining)
                .environmentObject(profileManager)
                .environmentObject(bluetoothManager)
        }
        
        
        /*WindowGroup {
            //AdminUtilityView()
            VideoTestView()
        }*/
        
    }
        
}
