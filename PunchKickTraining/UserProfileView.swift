import SwiftUI

struct UserProfileView: View {
    @ObservedObject var profileManager: UserProfileManager

    @State private var nickname: String = ""
    @State private var age: String = ""
    @State private var athleteType: String = "Pro"
    @State private var profileSaved = false
    @State private var selectedAvatar: String = "avatar_bear" // Default avatar

    let athleteTypes = ["Pro", "Amateur", "Beginner"]
    let avatarOptions = ["avatar_bear", "avatar_shark", "avatar_lion", "avatar_snake", "avatar_elephant", "avatar_monkey","avatar_rhino","avatar_bull","avatar_kangaroo","avatar_hanoch"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("User Profile")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.bottom, 10)

                    Divider().background(Color.gray)

                    // Nickname
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nickname")
                            .foregroundColor(.gray)
                            .font(.headline)
                        TextField("Enter nickname", text: $nickname)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    // Avatar Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose Avatar")
                            .foregroundColor(.gray)
                            .font(.headline)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(avatarOptions, id: \.self) { avatar in
                                    Image(avatar)
                                        .resizable()
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(avatar == selectedAvatar ? Color.green : Color.clear, lineWidth: 3)
                                        )
                                        .onTapGesture {
                                            selectedAvatar = avatar
                                        }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // Age
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Age")
                            .foregroundColor(.gray)
                            .font(.headline)
                        TextField("Enter age", text: $age)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    // Athlete Level
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Athlete Level")
                            .foregroundColor(.gray)
                            .font(.headline)

                        Menu {
                            ForEach(athleteTypes, id: \.self) { type in
                                Button(action: {
                                    athleteType = type
                                }) {
                                    Text(type)
                                }
                            }
                        } label: {
                            HStack {
                                Text(athleteType)
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }

                    // Save Button
                    Button(action: saveProfile) {
                        Text("Save Profile")
                            .bold()
                            .foregroundColor(.green)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(nickname.isEmpty || age.isEmpty ? Color.gray : Color.green, lineWidth: 1)
                            )
                            .cornerRadius(10)
                    }
                    .disabled(nickname.isEmpty || age.isEmpty)

                    // Save Confirmation
                    if profileSaved {
                        Text("Profile saved successfully!")
                            .foregroundColor(.green)
                            .font(.caption)
                            .padding(.top, 8)
                    }
                }
                .padding()
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
        .onAppear {
            loadProfileIfAvailable()
        }
        .onChange(of: profileManager.profile) { _ in
            loadProfileIfAvailable()
        }
    }

    private func saveProfile() {
        let profile = UserProfile(
            id: profileManager.profile?.id ?? profileManager.getCurrentUserId(),
            userId: profileManager.getCurrentUserId(),
            nickname: nickname,
            age: Int(age) ?? 0,
            athleteType: athleteType,
            createdAt: Date(),
            avatarName: selectedAvatar  // ✅ Save the avatar
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
        selectedAvatar = existing.avatarName ?? "avatar_bear"
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
