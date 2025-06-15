import SwiftUI

struct RootLauncherView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var profileManager: UserProfileManager
    @Binding var selectedTraining: SavedTraining?

    @State private var hasMinimumDelayPassed = false

    var body: some View {
        ZStack {
            // Background view logic (post-loading)
            if !profileManager.isLoading && hasMinimumDelayPassed {
                if profileManager.profile == nil {
                    UserProfileView(profileManager: profileManager)
                        .transition(.opacity)
                } else if let training = selectedTraining {
                    ContentView(training: training, selectedTraining: $selectedTraining)
                        .transition(.opacity)
                } else {
                    HomeScreen(selectedTraining: $selectedTraining)
                        .environmentObject(bluetoothManager)
                        .transition(.opacity)
                }
            }

            // Loading overlay
            if profileManager.isLoading || !hasMinimumDelayPassed {
                LoadingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1), value: hasMinimumDelayPassed)
        .onAppear {
            profileManager.loadProfile()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                hasMinimumDelayPassed = true
            }
        }
    }
}
