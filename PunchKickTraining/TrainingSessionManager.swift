import Foundation
import Combine

class TrainingSessionManager: ObservableObject {
    @Published public var currentRoundIndex: Int = 0
    @Published public var activeElapsedTime: Int = 0
    @Published public var activeElapsedTimeForCurrentRound: Int = 0
    @Published public var currentRound: TrainingRound?
    @Published public var currentRoundName: String = ""
    @Published public var isResting: Bool = false
    @Published public var restTimeRemaining: Int = 0

    public var trainingType: TrainingType = .forceDriven
    public var rounds: [TrainingRound] = []
    public var announcer: Announcer? = nil
    public var stopTrainingCallback: (() -> Void)? = nil

    public var isSessionActive: Bool = false
    public var hasHandledCurrentRound: Bool = false
    public var isChallengeEnded: (() -> Bool)? = nil
    
    private var timer: Timer?
    private var restTimer: Timer?
    private var startTime: Date?
    private var roundStartTime: Date?
    private var totalActiveSeconds: Int = 0

    weak var bluetoothManager: BluetoothManager?

    public func startNewSession(with rounds: [TrainingRound], type: TrainingType) {
        if isSessionActive {
            print("⚠️ Warning: Starting new session while previous is still active!")
            stopSession()  // ⛔️ Safely stop the previous session if still running
        }

        stopSessionTimer()  // just in case
        self.rounds = rounds
        self.trainingType = type
        self.currentRoundIndex = 0
        self.activeElapsedTime = 0
        self.activeElapsedTimeForCurrentRound = 0
        self.totalActiveSeconds = 0
        self.startTime = Date()

        isSessionActive = true
        bluetoothManager?.resetMotionState()

        print("\n🚀 Starting new training session with \(rounds.count) rounds")
        advanceToNextRound()
        startSessionTimer()
    }

    public func resetSession() {
        stopSessionTimer()
        self.rounds = []
        self.trainingType = .forceDriven
        self.currentRoundIndex = 0
        self.activeElapsedTime = 0
        self.activeElapsedTimeForCurrentRound = 0
        self.totalActiveSeconds = 0
        self.currentRound = nil
        self.currentRoundName = ""
        self.isResting = false
        self.restTimeRemaining = 0
        self.isSessionActive = false
    }

    public func stopSessionTimer() {
        timer?.invalidate()
        timer = nil
        restTimer?.invalidate()
        restTimer = nil
    }

    public func stopSession() {
        stopSessionTimer()
        isSessionActive = false
        bluetoothManager?.isTrainingActive = false
    }

    public func startSessionTimer() {
        guard isSessionActive else {
            print("⛔️ Not starting session timer — session is not active.")
            return
        }

        // Prevent duplicate timers
        if timer != nil {
            print("⛔️ Session timer already running — skipping re-scheduling.")
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.isSessionActive else {
                print("⛔️ Timer fired but session is not active.")
                return
            }
            self.tick()
        }

        print("⏱️ Session timer started")
    }

    func tick() {
        guard isSessionActive else {
            print("⛔️ Tick ignored — session inactive.")
            return
        }

        if isChallengeEnded?() == true {
            //print("⛔️ Tick ignored — challenge already ended.")
            return
        }
        guard currentRoundIndex < rounds.count else { return }

        if isResting {
            restTimeRemaining -= 1
            print("⏸ Resting... \(restTimeRemaining)s left")
            if restTimeRemaining <= 0 {
                isResting = false
                currentRoundIndex += 1
                if currentRoundIndex >= rounds.count {
                    if let callback = stopTrainingCallback {
                                stopTrainingCallback = nil // Prevent any further calls
                                callback()
                            }
                } else {
                    advanceToNextRound()
                }
            }
            return
        }

        activeElapsedTime += 1
        activeElapsedTimeForCurrentRound += 1
        totalActiveSeconds += 1

        if trainingType == .timeDriven {
            if let roundTime = currentRound?.roundTime,
               activeElapsedTimeForCurrentRound >= roundTime {
                handleRoundCompletion()
            }
        }
    }

    public func advanceToNextRound() {
        guard isSessionActive else { return }

        if isChallengeEnded?() == true {
            print("⛔️ advanceToNextRound ignored — challenge already ended.")
            return
        }
        
        guard currentRoundIndex < rounds.count else {
            if let callback = stopTrainingCallback {
                    stopTrainingCallback = nil // Prevent any further calls
                    callback()
                }
            return
        }

        let round = rounds[currentRoundIndex]
        self.currentRound = round
        self.currentRoundName = round.name
        self.activeElapsedTimeForCurrentRound = 0

        print("➡️ Advancing to round \(currentRoundIndex + 1): \(currentRound?.name ?? "Unknown")")
        print("\u{27A1}\u{FE0F} Starting round \(currentRoundIndex + 1): \(round.name)")
        announcer?.announceStartOfRound(round: round, index: currentRoundIndex + 1, type: trainingType)
    }

    public func handleRoundCompletion() {
        guard isSessionActive else { return }

        if isChallengeEnded?() == true {
            print("⛔️ handleRoundCompletion ignored — challenge already ended.")
            return
        }

        print("🏁 Completed round \(currentRoundIndex + 1): \(currentRound?.name ?? "Unknown")")
        announcer?.announceRoundEnded()

        let restTime = currentRound?.restTime ?? 0
        if restTime > 0 {
            restTimeRemaining = restTime
            isResting = true
            announcer?.announceRest(for: restTime)
            bluetoothManager?.resetMotionState()
        } else {
            isResting = false
            currentRoundIndex += 1
            if currentRoundIndex >= rounds.count {
                if let callback = stopTrainingCallback {
                    stopTrainingCallback = nil // Prevent future accidental invocations
                    callback()
                }
                return // ⬅️ This prevents fallthrough to anything after this block
            } else {
                advanceToNextRound()
            }
        }
    }

    private func prepareNextRound() {
        // Exit early if challenge has ended
        if isChallengeEnded?() == true {
            print("⛔️ prepareNextRound ignored — challenge already ended.")
            return
        }

        currentRoundIndex += 1
        if currentRoundIndex >= rounds.count {
            print("🎉 All rounds completed — stopping training")
            isResting = false
            if let callback = stopTrainingCallback {
                stopTrainingCallback = nil // Prevent multiple invocations
                callback()
            }
        } else {
            print("➡️ Advancing to round \(currentRoundIndex + 1): \(rounds[currentRoundIndex].name)")
            advanceToNextRound()
        }
    }

    public var currentRoundGoal: Double? {
        guard currentRoundIndex < rounds.count else { return nil }
        switch trainingType {
        case .forceDriven:
            return rounds[currentRoundIndex].goalForce
        case .strikesDriven:
            return Double(rounds[currentRoundIndex].goalStrikes ?? 0)
        case .timeDriven:
            return Double(rounds[currentRoundIndex].roundTime ?? 0)
        }
    }

    public var isCurrentRoundGoalMet: Bool {
        guard isSessionActive else { return false }
        guard trainingType == .forceDriven || trainingType == .strikesDriven,
              let goal = currentRoundGoal, goal > 0,
              let bluetooth = bluetoothManager else { return false }

        let progressSoFar: Double
        switch trainingType {
        case .forceDriven:
            progressSoFar = bluetooth.sumForceInRound
        case .strikesDriven:
            progressSoFar = Double(bluetooth.strikeCountInRound)
        default:
            return false
        }

        return progressSoFar >= goal
    }

    public var trainingGoalCompletionPercentage: Double {
        let totalTime = rounds.map { $0.roundTime ?? 0 }.reduce(0, +)
        return totalTime == 0 ? 0 : (Double(totalActiveSeconds) / Double(totalTime)) * 100.0
    }

    public var totalGoalForce: Double {
        rounds.map { $0.goalForce ?? 0 }.reduce(0, +)
    }

    public var totalGoalStrikes: Int {
        rounds.map { $0.goalStrikes ?? 0 }.reduce(0, +)
    }

    func cancelRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        print("🧹 Rest timer cancelled")
    }
}
