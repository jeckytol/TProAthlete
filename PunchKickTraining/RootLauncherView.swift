import SwiftUI

struct RootLauncherView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var profileManager: UserProfileManager
    @Binding var selectedTraining: SavedTraining?

    @State private var hasMinimumDelayPassed = false

    var body: some View {
        Group {
            if profileManager.isLoading || !hasMinimumDelayPassed {
                LoadingView()
            } else if profileManager.profile == nil {
                UserProfileView(profileManager: profileManager)
            } else if let training = selectedTraining {
                ContentView(training: training, selectedTraining: $selectedTraining)
            } else {
                HomeScreen(selectedTraining: $selectedTraining)
                    .environmentObject(bluetoothManager)
            }
        }
        .onAppear {
            profileManager.loadProfile()

            // Delay flag for minimum display duration of LoadingView
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                hasMinimumDelayPassed = true
            }
        }
    }
}
