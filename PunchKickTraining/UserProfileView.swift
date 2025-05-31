import SwiftUI

struct UserProfileView: View {
    @ObservedObject var profileManager: UserProfileManager

    @State private var nickname: String = ""
    @State private var age: String = ""
    @State private var athleteType: String = "Pro"
    @State private var profileSaved = false

    let athleteTypes = ["Pro", "Amateur", "Beginner"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Info")) {
                    TextField("Nickname", text: $nickname)
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)

                    Picker("Athlete Type", selection: $athleteType) {
                        ForEach(athleteTypes, id: \.self) { type in
                            Text(type)
                        }
                    }
                }

                Section {
                    Button("Save Profile") {
                        saveProfile()
                    }
                    .disabled(nickname.isEmpty || age.isEmpty)
                }

                if profileSaved {
                    Text("Profile saved successfully!")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            .navigationTitle("User Profile")
            .onAppear {
                loadProfileIfAvailable()
            }
            .onChange(of: profileManager.profile) { _ in
                loadProfileIfAvailable()
            }
        }
    }

    private func saveProfile() {
        let profile = UserProfile(
            id: profileManager.profile?.id ?? profileManager.getCurrentUserId(),
            userId: profileManager.getCurrentUserId(),
            nickname: nickname,
            age: Int(age) ?? 0,
            athleteType: athleteType,
            createdAt: Date()
        )

        profileManager.saveProfile(profile) { result in
            switch result {
            case .success():
                profileSaved = true
                print("✅ Profile saved: \(profile)")
            case .failure(let error):
                print("❌ Failed to save profile: \(error.localizedDescription)")
            }
        }
    }

    private func loadProfileIfAvailable() {
        guard let existing = profileManager.profile else { return }
        nickname = existing.nickname
        age = "\(existing.age)"
        athleteType = existing.athleteType
    }
}
