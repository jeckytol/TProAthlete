import SwiftUI
import Firebase

struct ChallengeHomeView: View {
    @State private var challenges: [Challenge] = []
    @State private var isLoading = true
    @State private var isPresentingNewChallenge = false
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
                                        HStack {
                                            Text(challenge.trainingName)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Spacer()
                                            Text(challenge.startTime, style: .date)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }

                                        HStack {
                                            Text("By: \(challenge.creatorNickname)")
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text(difficultyStars(for: challenge.difficulty))
                                                .foregroundColor(.white)
                                        }

                                        if !challenge.comment.isEmpty {
                                            Text(challenge.comment)
                                                .foregroundColor(.white)
                                                .font(.body)
                                                .italic()
                                        }

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
                    print("🕒 Challenge '\(trainingName)' scheduled for \(startTime)")

                    if startTime < now {
                        print("⏳ Skipping '\(trainingName)' — already started.")
                        return nil
                    } else if startTime > cutoff {
                        print("📅 Skipping '\(trainingName)' — beyond 3-day window.")
                        return nil
                    }

                    print("✅ Including '\(trainingName)'")
                    return Challenge(
                        id: doc.documentID,
                        trainingName: trainingName,
                        startTime: startTime,
                        difficulty: difficulty,
                        comment: comment,
                        creatorNickname: creator,
                        registeredNicknames: registered
                    )
                }

                print("📦 Total challenges included: \(self.challenges.count)")
            }
    }

    private func difficultyStars(for level: Int) -> String {
        String(repeating: "★", count: level)
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
        } else {
            updated.registeredNicknames.append(nickname)
        }

        docRef.updateData(["registeredNicknames": updated.registeredNicknames]) { error in
            if error == nil {
                if let index = challenges.firstIndex(where: { $0.id == challenge.id }) {
                    challenges[index] = updated
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
