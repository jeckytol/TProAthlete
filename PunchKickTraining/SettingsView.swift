import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var bluetoothManager: BluetoothManager
    @StateObject private var profileManager = UserProfileManager()

    var body: some View {
        NavigationView {
            SettingsFormView(
                bluetoothManager: bluetoothManager,
                profileManager: profileManager
            )
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}
