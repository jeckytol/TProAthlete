import SwiftUI

struct SettingsFormView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var profileManager: UserProfileManager

    @AppStorage("accelerationThreshold") var accelerationThreshold: Double = 1.5
    @AppStorage("repCooldown") var repCooldown: TimeInterval = 0.8
    @AppStorage("postRepCooldown") var postRepCooldown: TimeInterval = 0.3
    @AppStorage("minMotionDuration") var minMotionDuration: TimeInterval = 0.3
    @AppStorage("announceTime") var announceTime: Bool = true
    @AppStorage("timeAnnounceFrequency") var timeAnnounceFrequency: Int = 30
    @AppStorage("announceReps") var announceReps: Bool = true
    @AppStorage("repAnnounceFrequency") var repAnnounceFrequency: Int = 10
    @AppStorage("sensorSource") var sensorSource: String = "Phone"
    @AppStorage("nickname") private var nickname: String = ""
    @AppStorage("selectedAvatar") private var selectedAvatar: String = "avatar_bear"
    
    
    @AppStorage("announceForce") private var announceForce: Bool = false
    @AppStorage("forceAnnounceFrequency") private var forceAnnounceFrequency: Int = 100

    @AppStorage("announceProgress") private var announceProgress: Bool = false
    @AppStorage("progressAnnounceFrequency") private var progressAnnounceFrequency: Int = 20

    @State private var age: String = ""
    @State private var athleteType: String = "Beginner"
    @State private var showProfileSection = false
    @State private var showingSaveMessage = false

    private let athleteTypes = ["Beginner", "Amateur", "Pro"]
    private let avatarOptions = [
        "avatar_bear", "avatar_shark", "avatar_lion",
        "avatar_snake", "avatar_elephant", "avatar_monkey","avatar_rhino","avatar_bull","avatar_kangaroo","avatar_hanoch"
    ]

    var body: some View {
        Form {
            // User Profile Section
            DisclosureGroup(isExpanded: $showProfileSection) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Nickname", text: $nickname)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    // Avatar Picker
                    Text("Choose Avatar:")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(avatarOptions, id: \.self) { avatar in
                                Image(avatar)
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(selectedAvatar == avatar ? Color.green : Color.clear, lineWidth: 2))
                                    .onTapGesture {
                                        selectedAvatar = avatar
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Picker("Athlete Type", selection: $athleteType) {
                        ForEach(athleteTypes, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    Button("Save Profile") {
                        let profile = UserProfile(
                            id: profileManager.profile?.id ?? UUID().uuidString,
                            userId: profileManager.getCurrentUserId(),
                            nickname: nickname,
                            age: Int(age) ?? 0,
                            athleteType: athleteType,
                            createdAt: Date(),
                            avatarName: selectedAvatar
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
                LabeledSlider(label: "Post-Rep Cooldown (sec)", value: $postRepCooldown, range: 0.1...1.0)
                LabeledSlider(label: "Min Motion Duration (sec)", value: $minMotionDuration, range: 0.0...1.0)
            }

            //--------------------------
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

                Toggle("Announce Rep Count", isOn: $announceReps)

                if announceReps {
                    Picker("Rep Frequency", selection: $repAnnounceFrequency) {
                        ForEach([5, 10, 20, 25, 50], id: \.self) {
                            Text("Every \($0)")
                        }
                    }
                }
                
                Toggle("Announce Force", isOn: $announceForce)

                if announceForce {
                    Picker("Force Frequency (N)", selection: $forceAnnounceFrequency) {
                        ForEach([50, 100, 150, 200, 250], id: \.self) {
                            Text("\($0) N")
                        }
                    }
                }

                Toggle("Announce Progress", isOn: $announceProgress)

                if announceProgress {
                    Picker("Progress Frequency (%)", selection: $progressAnnounceFrequency) {
                        ForEach([10, 20, 25], id: \.self) {
                            Text("\($0)%")
                        }
                    }
                }
            }
            
            //--------------------------

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
                selectedAvatar = p.avatarName ?? ""
            }
        }
        .onChange(of: profileManager.profile) { newProfile in
            if let p = newProfile {
                nickname = p.nickname
                age = String(p.age)
                athleteType = p.athleteType
                selectedAvatar = p.avatarName ?? ""
            }
        }
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

    // MARK: - Reset Settings
    private func resetAllSettings() {
        accelerationThreshold = 1.3
        postRepCooldown = 0.3
        minMotionDuration = 0.2
        announceTime = true
        timeAnnounceFrequency = 30
        announceReps = true
        repAnnounceFrequency = 10
        sensorSource = "Phone"
    }
}
