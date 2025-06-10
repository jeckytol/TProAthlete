import SwiftUI
import AVFoundation

struct ChallengeTrainingView: View {
    let challenge: Challenge
    let training: SavedTraining

    //@ObservedObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    @EnvironmentObject var userProfileManager: UserProfileManager
    @Environment(\.dismiss) var dismiss

    @StateObject private var progressManager = ChallengeProgressManager()
    

    @State private var isUserPanelExpanded = true
    @State private var isLeaderboardExpanded = true
    @State private var trainingStartTime: Date? = nil
    @State private var elapsedTime: Int = 0
    @State private var reportingTimer: Timer? = nil
    @State private var elapsedTimer: Timer? = nil
    @State private var disqualified: Bool = false
    
    //---
    @StateObject private var announcer = Announcer()
    @StateObject private var sessionManager = TrainingSessionManager()
    //---

    var userId: String { userProfileManager.getCurrentUserId() }
    var nickname: String { userProfileManager.profile?.nickname ?? "Unknown" }
    var avatarName: String { userProfileManager.profile?.avatarName ?? "defaultAvatar" }

    var sortedProgress: [ChallengeProgress] {
        progressManager.allProgress.sorted { $0.totalForce > $1.totalForce }
    }

    var isUserDisqualified: Bool {
        progressManager.allProgress.first(where: { $0.userId == userId })?.isDisqualified ?? false
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
                        //Text("Current Round: \(bluetoothManager.sessionManager?.currentRoundName ?? "-")")
                        Text("Current Round: \(bluetoothManager.sessionManager?.observedRoundName ?? "-")")
                            .foregroundColor(.white)

                        ProgressView("Round Progress",
                                     value: bluetoothManager.currentForcePercentage,
                                     total: 100)
                            .accentColor(.green)

                        ProgressView("Training Progress",
                                     value: bluetoothManager.trainingProgressPercentage,
                                     total: 100)
                            .accentColor(.blue)

                        Text("Elapsed Time: \(elapsedTime) sec")
                            .foregroundColor(.gray)

                        Button(action: stopChallenge) {
                            Text("Stop Challenge")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
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
                    VStack(spacing: 12) {
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
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 10)

            if isUserDisqualified {
                Text("You’ve been disqualified")
                    .foregroundColor(.red)
                    .font(.headline)
                    .padding(.top, 10)
            }

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            bluetoothManager.announcer = announcer
            bluetoothManager.sessionManager = sessionManager
            startChallenge()
        }
        .onDisappear {
            reportingTimer?.invalidate()
            elapsedTimer?.invalidate()
            progressManager.stopObserving()
        }
    }
    
    //-----
    
    private func startChallenge() {
        UIApplication.shared.isIdleTimerDisabled = true
        disqualified = false

        // ⬅️ AVAudioSession activation
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetooth, .mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ Failed to activate AVAudioSession: \(error.localizedDescription)")
        }

        bluetoothManager.announcer = announcer
        bluetoothManager.sessionManager = sessionManager

        bluetoothManager.resetMetrics()
        sessionManager.reset()
        bluetoothManager.configureSensorSource()

        announcer.startCountdownThenBeginTraining {
            bluetoothManager.isTrainingActive = true
            sessionManager.startNewSession(with: training.rounds)
            sessionManager.startSessionTimer()
            trainingStartTime = Date()

            progressManager.observeProgress(for: challenge.id)

            elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if let start = trainingStartTime {
                    elapsedTime = Int(Date().timeIntervalSince(start))
                }

                let cutoff = sessionManager.currentRound?.cutoffTime ?? 0
                if cutoff > 0 && sessionManager.sessionElapsedTime >= cutoff {
                    disqualified = true
                    stopChallenge()
                }

                announcer.updateStrikeCount(to: bluetoothManager.totalStrikes)
            }

            announcer.start()

            reportingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                let progress = ChallengeProgress(
                    userId: userId,
                    challengeId: challenge.id,
                    nickname: nickname,
                    avatarName: avatarName,
                    totalForce: bluetoothManager.totalForce,
                    totalStrikes: bluetoothManager.totalStrikes,
                    isDisqualified: false,
                    roundName: sessionManager.currentRoundName,
                    roundNumber: sessionManager.roundNumber,
                    roundProgress: bluetoothManager.currentForcePercentage / 100,
                    createdAt: Date()
                )
                progressManager.updateProgress(progress)
            }
        }
    }
    
    //-------
    
    private func stopChallenge() {
        reportingTimer?.invalidate()
        elapsedTimer?.invalidate()
        bluetoothManager.isTrainingActive = false
        announcer.stop()
        
        let summary = TrainingSummary(
            trainingName: training.name,
            date: Date(),
            elapsedTime: elapsedTime,
            disqualified: isUserDisqualified,
            disqualifiedRound: isUserDisqualified ? bluetoothManager.sessionManager?.currentRoundName : nil,
            totalForce: bluetoothManager.totalForce,
            maxForce: bluetoothManager.maxForce,
            averageForce: bluetoothManager.averageForce,
            strikeCount: bluetoothManager.totalStrikes,
            trainingGoalForce: training.rounds.map { $0.goalForce }.reduce(0.0, +),
            trainingGoalCompletionPercentage: bluetoothManager.trainingProgressPercentage,
            nickname: nickname
        )

        TrainingSummaryManager().saveSummary(summary) { result in
            if case .failure(let error) = result {
                print("⚠️ Failed to save training summary: \(error.localizedDescription)")
            } else {
                print("✅ Training summary saved")
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func leaderboardRow(index: Int, entry: ChallengeProgress, highlight: Bool) -> some View {
        HStack(spacing: 12) {
            Text("#\(index)").foregroundColor(.gray)
            Image(entry.avatarName ?? "defaultAvatar")
                .resizable().frame(width: 32, height: 32).clipShape(Circle())
            Text(entry.nickname)
                .foregroundColor(highlight ? .yellow : .white)
                .bold()
            Spacer()
            Text("\(Int(entry.totalForce)) N").foregroundColor(.white)
            if index == 1 {
                Image(systemName: "medal.fill").foregroundColor(.yellow)
            } else if index == 2 {
                Image(systemName: "medal.fill").foregroundColor(.gray)
            } else if index == 3 {
                Image(systemName: "medal.fill").foregroundColor(.orange)
            }
        }
    }
}
