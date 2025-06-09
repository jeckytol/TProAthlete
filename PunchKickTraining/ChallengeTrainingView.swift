// ChallengeTrainingView.swift (Corrected)

import SwiftUI

struct ChallengeTrainingView: View {
    let challenge: Challenge
    
    let training: SavedTraining

    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var userProfileManager: UserProfileManager
    @Environment(\.dismiss) var dismiss

    @StateObject private var progressManager = ChallengeProgressManager()

    @State private var isUserPanelExpanded = true
    @State private var isLeaderboardExpanded = true
    @State private var timer: Timer? = nil

    var userId: String { userProfileManager.getCurrentUserId() }
    var nickname: String { userProfileManager.profile?.nickname ?? "Unknown" }
    var avatarName: String { userProfileManager.profile?.avatarName ?? "defaultAvatar" }
    var currentRoundNameText: String { bluetoothManager.sessionManager?.currentRoundName ?? "–" }
    var roundProgressValue: Double { bluetoothManager.currentForcePercentage }
    var trainingProgressValue: Double { bluetoothManager.trainingProgressPercentage }

    var isUserDisqualified: Bool {
        progressManager.allProgress.first(where: { $0.userId == userId })?.isDisqualified ?? false
    }

    var sortedProgress: [ChallengeProgress] {
        progressManager.allProgress.sorted { $0.totalForce > $1.totalForce }
    }

    var body: some View {
        VStack(spacing: 0) {
            // User Progress
            VStack(spacing: 10) {
                HStack {
                    Text("Your Progress").font(.headline).foregroundColor(.white)
                    Spacer()
                    Image(systemName: isUserPanelExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white)
                        .onTapGesture { withAnimation { isUserPanelExpanded.toggle() } }
                }

                if isUserPanelExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Current Round: \(currentRoundNameText)").foregroundColor(.white)
                        ProgressView("Round Progress", value: roundProgressValue, total: 100).accentColor(.green)
                        ProgressView("Training Progress", value: trainingProgressValue, total: 100).accentColor(.blue)
                    }
                    .padding().background(Color.gray.opacity(0.2)).cornerRadius(10)
                }
            }
            .padding([.horizontal, .top])

            // Leaderboard
            VStack(spacing: 10) {
                HStack {
                    Text("Leaderboard").font(.headline).foregroundColor(.white)
                    Spacer()
                    Image(systemName: isLeaderboardExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white)
                        .onTapGesture { withAnimation { isLeaderboardExpanded.toggle() } }
                }

                if isLeaderboardExpanded {
                    VStack(spacing: 8) {
                        let top5 = Array(sortedProgress.prefix(5))

                        ForEach(Array(top5.enumerated()), id: \.offset) { index, entry in
                            leaderboardRow(index: index + 1, entry: entry, highlight: entry.userId == userId)
                        }

                        if let userIndex = sortedProgress.firstIndex(where: { $0.userId == userId }), userIndex >= 5 {
                            Divider().background(Color.white.opacity(0.5))
                            leaderboardRow(index: userIndex + 1, entry: sortedProgress[userIndex], highlight: true)
                        }
                    }
                }
            }
            .padding().background(Color.gray.opacity(0.2)).cornerRadius(10).padding(.horizontal)

            if isUserDisqualified {
                Text("You’ve been disqualified")
                    .foregroundColor(.red)
                    .font(.headline)
                    .padding(.top, 10)
            }

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        //.onAppear(perform: startChallenge)
        //-----
        .onAppear {
            print("🔵 ChallengeTrainingView appeared")
            print("🔵 User ID: \(userId)")
            print("🔵 Nickname: \(nickname)")
            print("🔵 Round name: \(currentRoundNameText)")
            print("🔵 Total Force: \(bluetoothManager.totalForce)")
            print("🔵 isTrainingActive: \(bluetoothManager.isTrainingActive)")

            startChallenge()
        }
        //-----
        .onDisappear { timer?.invalidate(); progressManager.stopObserving() }
    }

    @ViewBuilder
    private func leaderboardRow(index: Int, entry: ChallengeProgress, highlight: Bool) -> some View {
        HStack {
            Text("#\(index)").foregroundColor(.gray)
            Image(entry.avatarName ?? "defaultAvatar")
                .resizable().frame(width: 24, height: 24).clipShape(Circle())
            Text(entry.nickname).foregroundColor(highlight ? .yellow : .white).bold()
            Spacer()
            Text("\(Int(entry.totalForce)) N").foregroundColor(.white)
            if index == 1 { Image(systemName: "medal.fill").foregroundColor(.yellow) }
            else if index == 2 { Image(systemName: "medal.fill").foregroundColor(.gray) }
            else if index == 3 { Image(systemName: "medal.fill").foregroundColor(.orange) }
        }
    }

    private func startChallenge() {
        // ✅ Use the `training` parameter directly
        bluetoothManager.sessionManager?.startNewSession(with: training.rounds)
        bluetoothManager.isTrainingActive = true

        progressManager.observeProgress(for: challenge.id)

        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            let progress = ChallengeProgress(
                userId: userId,
                challengeId: challenge.id,
                nickname: nickname,
                avatarName: avatarName,
                totalForce: bluetoothManager.totalForce,
                totalStrikes: bluetoothManager.totalStrikes,
                isDisqualified: false,
                roundName: bluetoothManager.sessionManager?.currentRoundName ?? "",
                roundNumber: bluetoothManager.sessionManager?.roundNumber ?? 1,
                roundProgress: bluetoothManager.currentForcePercentage / 100,
                createdAt: Date()
            )

            progressManager.updateProgress(progress)
        }
    }
}

