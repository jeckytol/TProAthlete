import SwiftUI
import AVFoundation

struct ChallengeTrainingView: View {
    let challenge: Challenge
    let training: SavedTraining
    let runId: String  // ✅ This line ensures the shared runId is used

    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var userProfileManager: UserProfileManager
    @Environment(\.dismiss) var dismiss

    @StateObject private var progressManager = ChallengeProgressManager()
    @StateObject private var announcer = Announcer()
    @StateObject private var sessionManager = TrainingSessionManager()

    @State private var isUserPanelExpanded = true
    @State private var isLeaderboardExpanded = true
    @State private var trainingStartTime: Date? = nil
    @State private var elapsedTime: Int = 0
    @State private var reportingTimer: Timer? = nil
    @State private var elapsedTimer: Timer? = nil
    @State private var disqualified: Bool = false
    @State private var hasChallengeEnded = false

    var userId: String { userProfileManager.getCurrentUserId() }
    var nickname: String { userProfileManager.profile?.nickname ?? "Unknown" }
    var avatarName: String { userProfileManager.profile?.avatarName ?? "defaultAvatar" }


    var sortedProgress: [ChallengeProgress] {
        progressManager.allProgress
            .filter { $0.runId == runId }
            .sorted { $0.totalForce > $1.totalForce }
    }

    var isUserDisqualified: Bool {
        progressManager.allProgress.first(where: { $0.userId == userId && $0.runId == runId })?.isDisqualified ?? false
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerSection
                leaderboardSection

                if isUserDisqualified {
                    Text("You’ve been disqualified")
                        .foregroundColor(.red)
                        .font(.headline)
                        .padding(.top, 10)
                }

                Spacer()
            }
            .background(Color.black.ignoresSafeArea())

            if let countdownText = announcer.visualCountdown {
                Text(countdownText)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(20)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .shadow(radius: 10)
                    .transition(.scale)
            }
        }
        .onAppear {
            bluetoothManager.announcer = announcer
            bluetoothManager.sessionManager = sessionManager
            startChallenge()
        }
        .onDisappear {
            reportingTimer?.invalidate()
            elapsedTimer?.invalidate()
            progressManager.stopObserving()
            if !hasChallengeEnded {
                DispatchQueue.main.async {
                    hasChallengeEnded = true
                }
                stopChallenge()
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            if hasChallengeEnded {
                Text(isUserDisqualified ? "Disqualified" : "Challenge Complete")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                    .padding()
                    .background(isUserDisqualified ? Color.red : Color.green)
                    .cornerRadius(10)
                    .padding(.top)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: hasChallengeEnded)
            }

            HStack {
                Text("Your Progress").font(.headline).foregroundColor(.white)
                Spacer()
                Image(systemName: isUserPanelExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.white)
                    .onTapGesture { withAnimation { isUserPanelExpanded.toggle() } }
            }

            if isUserPanelExpanded {
                userProgressPanel
            }
        }
        .padding([.horizontal, .top])
    }

    private var userProgressPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current Round: \(bluetoothManager.sessionManager?.observedRoundName ?? "–")")
                .foregroundColor(.white)
                .bold()

            ProgressView(value: bluetoothManager.currentForcePercentage, total: 100) {
                Text("Round Progress").font(.caption).foregroundColor(.gray)
            }.accentColor(.green)

            ProgressView(value: bluetoothManager.trainingProgressPercentage, total: 100) {
                Text("Training Progress").font(.caption).foregroundColor(.gray)
            }.accentColor(.blue)

            Text("Elapsed Time: \(elapsedTime) sec")
                .foregroundColor(.white)
                .bold()

            Button(action: {
                if !hasChallengeEnded {
                    hasChallengeEnded = true
                    stopChallenge()
                }
            }) {
                Text("Stop Challenge")
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(hasChallengeEnded ? Color.gray : Color.red)
                    .cornerRadius(8)
                    .opacity(hasChallengeEnded ? 0.5 : 1.0)
            }.disabled(hasChallengeEnded)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }

    private var leaderboardSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Leaderboard").font(.headline).foregroundColor(.white)
                Spacer()
                Image(systemName: isLeaderboardExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.white)
                    .onTapGesture { withAnimation { isLeaderboardExpanded.toggle() } }
            }

            if isLeaderboardExpanded {
                VStack(spacing: 14) {
                    let top5 = Array(sortedProgress.prefix(5))
                    ForEach(Array(top5.enumerated()), id: \ .offset) { index, entry in
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
    }

    private func startChallenge() {
        UIApplication.shared.isIdleTimerDisabled = true
        disqualified = false

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

            print("📡 Observing progress for challengeId: \(challenge.id), runId: \(runId)")
            progressManager.observeProgress(for: challenge.id, runId: runId)

            elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if let start = trainingStartTime {
                    elapsedTime = Int(Date().timeIntervalSince(start))
                }

                let cutoff = sessionManager.currentRound?.cutoffTime ?? 0
                if cutoff > 0 && sessionManager.sessionElapsedTime >= cutoff {
                    disqualified = true
                    if !hasChallengeEnded {
                        hasChallengeEnded = true
                        stopChallenge()
                    }
                }

                if !hasChallengeEnded && bluetoothManager.trainingProgressPercentage >= 100 {
                    hasChallengeEnded = true
                    stopChallenge()
                }

                announcer.updateStrikeCount(to: bluetoothManager.totalStrikes)
            }

            announcer.start()

            reportingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                let progress = ChallengeProgress(
                    userId: userId,
                    challengeId: challenge.id,
                    runId: runId,
                    nickname: nickname,
                    avatarName: avatarName,
                    totalForce: bluetoothManager.totalForce,
                    totalStrikes: bluetoothManager.totalStrikes,
                    totalPoints: bluetoothManager.totalPoints,
                    isDisqualified: false,
                    roundName: sessionManager.currentRoundName,
                    roundNumber: sessionManager.roundNumber,
                    roundProgress: bluetoothManager.currentForcePercentage / 100,
                    createdAt: Date()
                )
                print("⬆️ Uploading progress: \(progress.nickname), runId: \(progress.runId), force: \(progress.totalForce)")
                progressManager.updateProgress(progress)
            }
        }
    }

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
            totalPoints: bluetoothManager.totalPoints,
            nickname: nickname
        )

        TrainingSummaryManager().saveSummary(summary) { result in
            if case .failure(let error) = result {
                print("⚠️ Failed to save training summary: \(error.localizedDescription)")
            } else {
                print("✅ Training summary saved")
            }
        }
    }

    @ViewBuilder
    private func leaderboardRow(index: Int, entry: ChallengeProgress, highlight: Bool) -> some View {
        HStack(spacing: 16) {
            Text("#\(index)")
                .foregroundColor(.gray)
                .font(.subheadline)
            Image(entry.avatarName ?? "defaultAvatar")
                .resizable()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            Text(entry.nickname)
                .foregroundColor(highlight ? .yellow : .white)
                .font(.headline)
                .bold()
            Spacer()
            Text("\(Int(entry.totalForce)) N")
                .foregroundColor(.white)
                .font(.subheadline)
            if index == 1 {
                Image(systemName: "medal.fill").foregroundColor(.yellow)
            } else if index == 2 {
                Image(systemName: "medal.fill").foregroundColor(.gray)
            } else if index == 3 {
                Image(systemName: "medal.fill").foregroundColor(.orange)
            }
        }
        .padding(6)
        .background(highlight ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}
