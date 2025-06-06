import SwiftUI

struct ChallengeTrainingView: View {
    let challenge: Challenge

    struct LeaderboardEntry: Identifiable {
        let id = UUID()
        let nickname: String
        let trainingProgress: Double
    }

    @State private var isUserPanelExpanded = true
    @State private var isLeaderboardExpanded = true
    @State private var userRound = "Round 1"
    @State private var userRoundProgress: Double = 0.3
    @State private var userTrainingProgress: Double = 0.5
    @State private var userPlace: Int = 4
    @State private var top5: [LeaderboardEntry] = [
        LeaderboardEntry(nickname: "Alice", trainingProgress: 1.0),
        LeaderboardEntry(nickname: "Bob", trainingProgress: 0.9),
        LeaderboardEntry(nickname: "Charlie", trainingProgress: 0.8),
        LeaderboardEntry(nickname: "You", trainingProgress: 0.5),
        LeaderboardEntry(nickname: "Dana", trainingProgress: 0.4)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // User Panel
            VStack(spacing: 10) {
                HStack {
                    Text("Your Progress")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: isUserPanelExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white)
                        .onTapGesture {
                            withAnimation {
                                isUserPanelExpanded.toggle()
                            }
                        }
                }

                if isUserPanelExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Current Round: \(userRound)")
                            .foregroundColor(.white)

                        ProgressView("Round Progress", value: userRoundProgress)
                            .foregroundColor(.gray)
                            .accentColor(.green)
                            .progressViewStyle(LinearProgressViewStyle())

                        ProgressView("Training Progress", value: userTrainingProgress)
                            .foregroundColor(.gray)
                            .accentColor(.blue)
                            .progressViewStyle(LinearProgressViewStyle())

                        Text("Your Place: #\(userPlace)")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            .padding([.horizontal, .top])

            Spacer().frame(height: 8)

            // Leaderboard Panel
            VStack(spacing: 10) {
                HStack {
                    Text("Leaderboard")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: isLeaderboardExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white)
                        .onTapGesture {
                            withAnimation {
                                isLeaderboardExpanded.toggle()
                            }
                        }
                }

                if isLeaderboardExpanded {
                    VStack(spacing: 8) {
                        ForEach(0..<min(5, top5.count), id: \ .self) { index in
                            let entry = top5[index]
                            HStack {
                                Text("#\(index + 1)")
                                    .foregroundColor(.gray)
                                Text(entry.nickname)
                                    .foregroundColor(.white)
                                    .bold()
                                Spacer()

                                if index == 0 {
                                    Image(systemName: "medal.fill").foregroundColor(.yellow)
                                } else if index == 1 {
                                    Image(systemName: "medal.fill").foregroundColor(.gray)
                                } else if index == 2 {
                                    Image(systemName: "medal.fill").foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            .padding(.horizontal)

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear(perform: startChallenge)
    }

    private func startChallenge() {
        // TODO: Replace with actual Firestore sync logic
        print("🏁 Challenge started for: \(challenge.challengeName)")
    }
}
