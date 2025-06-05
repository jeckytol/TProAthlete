import SwiftUI
import Firebase

struct ChallengeHomeView: View {
    @State private var challenges: [Challenge] = []
    @State private var isLoading = true
    @State private var isPresentingNewChallenge = false
    @State private var showConfirmation = false
    @State private var confirmationMessage = ""
    @AppStorage("nickname") private var nickname: String = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    // Header Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Challenges")
                            .font(.title.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        Divider().background(Color.gray)
                    }
                    .padding(.top)

                    if isLoading {
                        Spacer()
                        ProgressView("Loading Challenges...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .foregroundColor(.white)
                        Spacer()
                    } else if challenges.isEmpty {
                        Spacer()
                        Text("No upcoming challenges.")
                            .foregroundColor(.gray)
                            .padding()
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(challenges) { challenge in
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Challenge Name (colored by registration)
                                        Text(challenge.challengeName)
                                            .font(.headline.bold())
                                            .foregroundColor(isRegistered(for: challenge) ? .green : .gray)

                                        // Creator and Difficulty
                                        HStack {
                                            Text("By: \(challenge.creatorNickname)")
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text(difficultyStars(for: challenge.difficulty))
                                                .foregroundColor(.white)
                                        }

                                        // Training Name
                                        Text("Training: \(challenge.trainingName)")
                                            .font(.subheadline)
                                            .foregroundColor(.white)

                                        // Truncated Comment
                                        if !challenge.comment.isEmpty {
                                            Text(truncatedComment(challenge.comment))
                                                .foregroundColor(.white)
                                                .font(.body)
                                                .italic()
                                        }

                                        // Date & Action Buttons
                                        HStack {
                                            Button(action: {
                                                toggleRegistration(for: challenge)
                                            }) {
                                                Text(isRegistered(for: challenge) ? "Unregister" : "Register")
                                                    .font(.caption)
                                                    .padding(6)
                                                    .foregroundColor(.white)
                                                    .background(Color.gray.opacity(0.3))
                                                    .cornerRadius(6)
                                            }

                                            Spacer()

                                            if challenge.creatorNickname == nickname {
                                                Button(action: {
                                                    deleteChallenge(challenge)
                                                }) {
                                                    Image(systemName: "trash")
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                        }

                                        // Time Display
                                        Text(challenge.startTime.formatted(date: .abbreviated, time: .shortened))
                                            .font(.footnote)
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                                }
                            }
                            .padding()
                        }
                    }
                }

                // Confirmation Message Overlay
                if showConfirmation {
                    VStack {
                        Spacer()
                        Text(confirmationMessage)
                            .foregroundColor(.green)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            .transition(.opacity)
                        Spacer().frame(height: 40)
                    }
                    .animation(.easeInOut, value: showConfirmation)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isPresentingNewChallenge = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewChallenge, onDismiss: fetchChallenges) {
                NewChallengeView()
            }
            .onAppear {
                fetchChallenges()
            }
        }
    }

    private func fetchChallenges() {
        isLoading = true
        let db = Firestore.firestore()
        let now = Date()
        let cutoff = Calendar.current.date(byAdding: .day, value: 3, to: now)!

        print("🔍 Filtering challenges from \(now) to \(cutoff)")

        db.collection("challenges")
            .order(by: "startTime")
            .getDocuments { snapshot, error in
                isLoading = false

                guard let documents = snapshot?.documents else {
                    print("❌ No snapshot found or error: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                self.challenges = documents.compactMap { doc -> Challenge? in
                    let data = doc.data()
                    guard
                        let challengeName = data["challengeName"] as? String,
                        let trainingName = data["trainingName"] as? String,
                        let timestamp = data["startTime"] as? Timestamp,
                        let difficulty = data["difficulty"] as? Int,
                        let comment = data["comment"] as? String,
                        let creator = data["creatorNickname"] as? String,
                        let registered = data["registeredNicknames"] as? [String]
                    else {
                        print("⚠️ Skipped document with missing fields: \(doc.documentID)")
                        return nil
                    }

                    let startTime = timestamp.dateValue()
                    if startTime < now || startTime > cutoff { return nil }

                    return Challenge(
                        id: doc.documentID,
                        challengeName: challengeName,
                        trainingName: trainingName,
                        startTime: startTime,
                        difficulty: difficulty,
                        comment: comment,
                        creatorNickname: creator,
                        registeredNicknames: registered
                    )
                }
            }
    }

    private func difficultyStars(for level: Int) -> String {
        String(repeating: "★", count: level)
    }

    private func truncatedComment(_ text: String) -> String {
        let words = text.split(separator: " ")
        return words.count <= 6 ? text : words.prefix(6).joined(separator: " ") + "..."
    }

    private func isRegistered(for challenge: Challenge) -> Bool {
        challenge.registeredNicknames.contains(nickname)
    }

    private func toggleRegistration(for challenge: Challenge) {
        let db = Firestore.firestore()
        let docRef = db.collection("challenges").document(challenge.id)

        var updated = challenge
        if isRegistered(for: challenge) {
            updated.registeredNicknames.removeAll { $0 == nickname }
            confirmationMessage = "Unregistered successfully"
        } else {
            updated.registeredNicknames.append(nickname)
            confirmationMessage = "Registered successfully"
        }

        docRef.updateData(["registeredNicknames": updated.registeredNicknames]) { error in
            if error == nil {
                if let index = challenges.firstIndex(where: { $0.id == challenge.id }) {
                    challenges[index] = updated
                    showConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showConfirmation = false
                    }
                }
            }
        }
    }

    private func deleteChallenge(_ challenge: Challenge) {
        let db = Firestore.firestore()
        db.collection("challenges").document(challenge.id).delete { error in
            if error == nil {
                challenges.removeAll { $0.id == challenge.id }
            }
        }
    }
}
