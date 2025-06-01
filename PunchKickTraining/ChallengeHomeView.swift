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

                if isLoading {
                    ProgressView("Loading Challenges...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                } else if challenges.isEmpty {
                    Text("No challenges yet.")
                        .foregroundColor(.gray)
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
                                            .foregroundColor(.yellow)
                                    }

                                    if !challenge.comment.isEmpty {
                                        Text(challenge.comment)
                                            .foregroundColor(.white)
                                            .font(.body)
                                            .italic()
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
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.inline)
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
            .onAppear {
                fetchChallenges()
            }
            .sheet(isPresented: $isPresentingNewChallenge, onDismiss: fetchChallenges) {
                NewChallengeView()
            }
        }
    }

    private func fetchChallenges() {
        isLoading = true
        let db = Firestore.firestore()

        db.collection("challenges")
            .order(by: "startTime", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching challenges: \(error)")
                    self.isLoading = false
                    return
                }

                self.challenges = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    guard
                        let trainingName = data["trainingName"] as? String,
                        let startTimestamp = data["startTime"] as? Timestamp,
                        let difficulty = data["difficulty"] as? Int,
                        let comment = data["comment"] as? String,
                        let creator = data["creatorNickname"] as? String
                    else {
                        return nil
                    }

                    return Challenge(
                        id: doc.documentID,
                        trainingName: trainingName,
                        startTime: startTimestamp.dateValue(),
                        difficulty: difficulty,
                        comment: comment,
                        creatorNickname: creator
                    )
                } ?? []

                self.isLoading = false
            }
    }

    private func difficultyStars(for level: Int) -> String {
        return String(repeating: "★", count: level)
    }
}

// MARK: - Challenge Model

struct Challenge: Identifiable {
    let id: String
    let trainingName: String
    let startTime: Date
    let difficulty: Int
    let comment: String
    let creatorNickname: String
}
