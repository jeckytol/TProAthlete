import SwiftUI

struct SettingsFormView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var profileManager: UserProfileManager

    @AppStorage("accelerationThreshold") var accelerationThreshold: Double = 1.5
    @AppStorage("strikeCooldown") var strikeCooldown: TimeInterval = 0.8
    @AppStorage("postStrikeCooldown") var postStrikeCooldown: TimeInterval = 0.3
    @AppStorage("minMotionDuration") var minMotionDuration: TimeInterval = 0.3
    @AppStorage("announceTime") var announceTime: Bool = true
    @AppStorage("timeAnnounceFrequency") var timeAnnounceFrequency: Int = 30
    @AppStorage("announceStrikes") var announceStrikes: Bool = true
    @AppStorage("strikeAnnounceFrequency") var strikeAnnounceFrequency: Int = 10
    @AppStorage("sensorSource") var sensorSource: String = "Phone"
    @AppStorage("nickname") private var nickname: String = ""

    @State private var age: String = ""
    @State private var athleteType: String = "Beginner"
    @State private var showProfileSection = false
    @State private var showingSaveMessage = false

    private let athleteTypes = ["Beginner", "Amateur", "Pro"]

    var body: some View {
        Form {
            // User Profile Section
            DisclosureGroup(isExpanded: $showProfileSection) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Nickname", text: $nickname)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Picker("Athlete Type", selection: $athleteType) {
                        ForEach(athleteTypes, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle()) // Avoids collision when used inline

                    Spacer().frame(height: 30)
                    Divider()

                    Button("Save Profile") {
                        let profile = UserProfile(
                            id: profileManager.profile?.id ?? UUID().uuidString,
                            userId: profileManager.getCurrentUserId(),
                            nickname: nickname,
                            age: Int(age) ?? 0,
                            athleteType: athleteType,
                            createdAt: Date()
                        )
                        profileManager.saveProfile(profile) { result in
                            if case .success = result {
                                showingSaveMessage = true
                            }
                        }
                    }
                    .foregroundColor(.blue)
                    .alert("Profile saved successfully!", isPresented: $showingSaveMessage) {
                        Button("OK", role: .cancel) {}
                    }
                    .padding(.top, 10)
                }
                .padding(.vertical, 5)
            } label: {
                Text("User Profile").font(.headline)
            }

            // Motion Settings Section
            Section(header: Text("Motion Detection Settings")) {
                Picker("Sensor Source", selection: $sensorSource) {
                    Text("Phone").tag("Phone")
                    Text("Watch").tag("Watch")
                    Text("Arduino").tag("Arduino")
                }
                .pickerStyle(SegmentedPickerStyle())

                LabeledSlider(label: "Sensitivity", value: $accelerationThreshold, range: 1.0...2.5)
                LabeledSlider(label: "Post-Strike Cooldown (sec)", value: $postStrikeCooldown, range: 0.1...1.0)
                LabeledSlider(label: "Min Motion Duration (sec)", value: $minMotionDuration, range: 0.0...1.0)
            }

            // Voice Feedback Section
            Section(header: Text("Voice Feedback")) {
                Toggle("Announce Time", isOn: $announceTime)

                if announceTime {
                    Picker("Time Frequency (sec)", selection: $timeAnnounceFrequency) {
                        ForEach([10, 15, 30, 60], id: \.self) {
                            Text("\($0) sec")
                        }
                    }
                }

                Toggle("Announce Strike Count", isOn: $announceStrikes)

                if announceStrikes {
                    Picker("Strike Frequency", selection: $strikeAnnounceFrequency) {
                        ForEach([5, 10, 20, 25, 50], id: \.self) {
                            Text("Every \($0)")
                        }
                    }
                }
            }

            // Reset Section
            Section {
                Button("Reset All Settings to Defaults") {
                    resetAllSettings()
                }
                .foregroundColor(.red)
            }
        }
        .onAppear {
            profileManager.loadProfile()
            if let p = profileManager.profile {
                nickname = p.nickname
                age = String(p.age)
                athleteType = p.athleteType
            }
        }
        .onChange(of: profileManager.profile) { newProfile in
            if let p = newProfile {
                nickname = p.nickname
                age = String(p.age)
                athleteType = p.athleteType
            }
        }
    }

    // MARK: - Reset All Settings
    private func resetAllSettings() {
        accelerationThreshold = 1.3
        postStrikeCooldown = 0.3
        minMotionDuration = 0.2
        announceTime = true
        timeAnnounceFrequency = 30
        announceStrikes = true
        strikeAnnounceFrequency = 10
        sensorSource = "Phone"
    }

    // MARK: - Slider Helper
    private func LabeledSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .foregroundColor(.gray)
            }
            Slider(value: value, in: range, step: 0.05)
        }
    }
}
