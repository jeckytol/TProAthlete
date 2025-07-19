import SwiftUI
import AVFoundation

struct ChallengeTrainingView: View {
    let challenge: Challenge
    let training: SavedTraining
    let runId: String

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
    @State private var isStoppingChallenge = false
    @State private var isStopChallengeInProgress = false
    
    @State private var isCountdownActive: Bool = false

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
    
    private var roundProgress: Double {
        guard bluetoothManager.isTrainingActive else { return 0.0 }

        if training.trainingType == .timeDriven {
            let roundDuration = Double(sessionManager.currentRound?.roundTime ?? 1)
            let elapsed = Double(sessionManager.activeElapsedTimeForCurrentRound)
            return min(elapsed / roundDuration, 1.0)
        } else {
            return bluetoothManager.currentRoundProgressPercentage / 100.0
        }
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
            
            if sessionManager.isResting {
                ZStack {
                    // Dark full-screen background
                    Color.black.opacity(0.75)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        Text("Rest Time")
                            .font(.title)
                            .foregroundColor(.blue)

                        Text("\(sessionManager.restTimeRemaining)")
                            .font(.system(size: 100, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                            .shadow(radius: 10)
                    }
                    .padding(40)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.blue, lineWidth: 4)
                    )
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .onAppear {
            bluetoothManager.announcer = announcer
            bluetoothManager.sessionManager = sessionManager
            // ✅ Provide access to hasChallengeEnded inside sessionManager
            sessionManager.isChallengeEnded = { hasChallengeEnded }
            startChallenge()
        }
        .onDisappear {
            print("📤 ChallengeTrainingView disappeared")

            // Just call stopChallenge() once if it hasn’t already run
            if !hasChallengeEnded {
                hasChallengeEnded = true
                print("⏹ Setting hasChallengeEnded = true inside onDisappear")
                stopChallenge()
            } else {
                print("⛔️ onDisappear ignored — challenge already ended.")
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
            Text("Current Round: \(bluetoothManager.sessionManager?.currentRoundName ?? "–")")
                .foregroundColor(.white)
                .bold()
            
            //--
            ProgressView(value: isCountdownActive ? 0 : roundProgress) {
                Text("Round Progress").font(.caption).foregroundColor(.gray)
            }

            
            ProgressView(value: (!isCountdownActive && bluetoothManager.isTrainingActive) ? bluetoothManager.trainingProgressPercentage : 0, total: 100) {
                Text("Training Progress").font(.caption).foregroundColor(.gray)
            }
            .accentColor(.blue)
            
            //---

            Text("Elapsed Time: \(elapsedTime) sec")
                .foregroundColor(.white)
                .bold()

            Button(action: {
                print("🖲️ STOP BUTTON TAPPED by user")
                if !hasChallengeEnded {
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
    }

    
    
    private func startChallenge() {
        print("🟢 Checking if challenge can start. hasChallengeEnded = \(hasChallengeEnded)")
        guard !hasChallengeEnded else {
            print("⚠️ startChallenge() called but challenge already ended.")
            return
        }
        print("📍 runId: \(runId)")
        
        UIApplication.shared.isIdleTimerDisabled = true
        disqualified = false
        isCountdownActive = true

        cleanupTimers() // 🧹 Ensure no timers leak from previous session

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetooth, .mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ Failed to activate AVAudioSession: \(error.localizedDescription)")
        }

        bluetoothManager.announcer = announcer
        bluetoothManager.sessionManager = sessionManager
        
        // ✅ Pass challenge-ended state into the sessionManager
        sessionManager.isChallengeEnded = { hasChallengeEnded }

        
        bluetoothManager.stopTrainingCallback = { [weak bluetoothManager] in
            print("📴 stopTrainingCallback triggered from BluetoothManager")
            if let manager = bluetoothManager {
                if manager.stopTrainingCallback != nil {
                    if !hasChallengeEnded {
                        hasChallengeEnded = true
                        print("📴 stopTrainingCallback triggered — stopping challenge")
                        manager.stopTrainingCallback = nil
                        stopChallenge()
                    } else {
                        print("⚠️ stopTrainingCallback triggered, but challenge already ended — skipping")
                    }
                }
            }
        }

        bluetoothManager.resetMetrics()
        sessionManager.resetSession()
        bluetoothManager.configureSensorSource()

        announcer.startCountdownThenBeginTraining {
            guard !hasChallengeEnded else {
                print("⛔️ Countdown finished, but challenge already ended — aborting training start.")
                return
            }
            announcer.start()
            bluetoothManager.isTrainingActive = true
            announcer.trainingStarted = true
            isCountdownActive = false

            sessionManager.announcer = announcer
            print("🆕 Starting new session with \(training.rounds.count) rounds, type: \(training.trainingType)")
            sessionManager.startNewSession(with: training.rounds, type: training.trainingType)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                sessionManager.startSessionTimer()
            }

            trainingStartTime = Date()

            print("📡 Observing progress for challengeId: \(challenge.id), runId: \(runId)")
            progressManager.resetUserProgress(for: challenge.id, runId: runId, userId: userId)
            progressManager.observeProgress(for: challenge.id, runId: runId)

            elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                guard bluetoothManager.isTrainingActive, !hasChallengeEnded else { return }

                elapsedTime = sessionManager.activeElapsedTime

                let cutoff = sessionManager.currentRound?.cutoffTime ?? 0
                if cutoff > 0 && sessionManager.activeElapsedTimeForCurrentRound >= cutoff {
                    disqualified = true
                    print("🛑 Disqualified — triggering stopChallenge() due to cutoff")
                    stopChallenge()
                    return
                }

                if bluetoothManager.trainingProgressPercentage >= 100 {
                    print("🎯 Training progress hit 100%")
                    stopChallenge()
                    return
                }
                
                announcer.updateStrikeCount(to: bluetoothManager.totalStrikes)
            }

            reportingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                guard bluetoothManager.isTrainingActive, !hasChallengeEnded else {
                    print("🛑 Skipping progress save — training inactive or ended.")
                    return
                }

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
                    roundNumber: sessionManager.currentRoundIndex + 1,
                    roundProgress: bluetoothManager.currentRoundProgressPercentage / 100,
                    createdAt: Date()
                )
                progressManager.updateProgress(progress)
            }
        }
    }
    
    
    private func stopChallenge() {
        guard !hasChallengeEnded else {
            print("⚠️ stopChallenge() called but challenge already ended — ignoring.")
            return
        }

        guard !isStopChallengeInProgress else {
            print("⚠️ stopChallenge() already in progress — skipping.")
            return
        }

        isStopChallengeInProgress = true
        print("🖲️ stopChallenge initiated")
        print("📍 runId: \(runId)")

        // Stop session and announcer
        UIApplication.shared.isIdleTimerDisabled = false
        sessionManager.stopSession()
        announcer.announceTrainingEnded()
        cleanupTimers()
        announcer.stop()
        announcer.trainingStarted = false
        sessionManager.announcer = nil

        // Stop training and motion
        bluetoothManager.isTrainingActive = false
        bluetoothManager.resetMotionState()
        bluetoothManager.stopTrainingCallback = nil

        // Save summary LAST, before finalizing state
        let summary = TrainingSummary(
            trainingName: training.name,
            date: Date(),
            elapsedTime: elapsedTime,
            disqualified: isUserDisqualified,
            disqualifiedRound: isUserDisqualified ? bluetoothManager.sessionManager?.currentRoundName ?? "Unknown" : nil,
            totalForce: bluetoothManager.totalForce,
            maxForce: bluetoothManager.maxForce,
            averageForce: bluetoothManager.averageForce,
            strikeCount: bluetoothManager.totalStrikes,
            trainingGoalForce: training.rounds.map { $0.goalForce ?? 0.0 }.reduce(0.0, +),
            trainingGoalCompletionPercentage: bluetoothManager.trainingProgressPercentage,
            totalPoints: bluetoothManager.totalPoints,
            nickname: nickname
        )

        TrainingSummaryManager().saveSummary(summary) { result in
            switch result {
            case .success:
                print("✅ Training summary saved")
            case .failure(let error):
                print("⚠️ Failed to save training summary: \(error.localizedDescription)")
            }

            // Final cleanup AFTER save completes
            hasChallengeEnded = true
            isStopChallengeInProgress = false
            print("⛔️ hasChallengeEnded is now TRUE")
            print("✅ Challenge successfully stopped")

            bluetoothManager.resetMetrics()
            bluetoothManager.announcer = nil
            bluetoothManager.sessionManager = nil
            progressManager.stopObserving()
        }
    }
    
    
    private func cleanupTimers() {
        print("🧹 Cleanup called: invalidating timers and stopping announcer.")

        reportingTimer?.invalidate()
        reportingTimer = nil

        elapsedTimer?.invalidate()
        elapsedTimer = nil

        announcer.stop()
        isCountdownActive = false

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
