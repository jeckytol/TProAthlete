import SwiftUI

struct RootLauncherView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var profileManager: UserProfileManager
    @Binding var selectedTraining: SavedTraining?

    @State private var hasMinimumDelayPassed = false

    var body: some View {
        ZStack {
            if !profileManager.isLoading && hasMinimumDelayPassed {
                if profileManager.profile == nil {
                    // User hasn't set up their profile yet
                    UserProfileView(profileManager: profileManager)
                        .transition(.opacity)
                } else if let training = selectedTraining {
                    // A training was launched from somewhere
                    ContentView(training: training, selectedTraining: $selectedTraining)
                        .environmentObject(bluetoothManager)
                        .environmentObject(profileManager)
                        .transition(.opacity)
                } else {
                    // Default path — go to 2x2 function selector
                    //FunctionOptionsView()
                    FunctionOptionsView(selectedTraining: $selectedTraining)
                        .environmentObject(bluetoothManager)
                        .environmentObject(profileManager)
                        .transition(.opacity)
                }
            }

            if profileManager.isLoading || !hasMinimumDelayPassed {
                LoadingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1), value: hasMinimumDelayPassed)
        .onAppear {
            profileManager.loadProfile()

            // Ensure minimum splash time
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                hasMinimumDelayPassed = true
            }
        }
    }
}
