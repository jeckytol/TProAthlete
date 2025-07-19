import Foundation
import AVFoundation
import SwiftUI

class Announcer: ObservableObject {
    private var timer: Timer?
    private var synthesizer = AVSpeechSynthesizer()
    private var notificationObserver: NSObjectProtocol?
    private var lastAnnouncedTime: Int = 0
    private var countdownWorkItem: DispatchWorkItem?
    
    private var lastAnnouncedForceSegment: Int = 0
    private var lastAnnouncedProgressSegment: Int = 0

    @AppStorage("announceTime") var announceTime: Bool = true
    @AppStorage("timeAnnounceFrequency") var timeAnnounceFrequency: Int = 30

    @AppStorage("announceStrikes") var announceStrikes: Bool = true
    @AppStorage("strikeAnnounceFrequency") var strikeAnnounceFrequency: Int = 10
    
    @AppStorage("announceForce") private var announceForce: Bool = false
    @AppStorage("forceAnnounceFrequency") private var forceAnnounceFrequency: Int = 100

    @AppStorage("announceProgress") private var announceProgress: Bool = false
    @AppStorage("progressAnnounceFrequency") private var progressAnnounceFrequency: Int = 20

    private var currentStrikeCount: Int = 0
    private var lastAnnouncedStrikeCount: Int = 0

    @Published var visualCountdown: String? = nil
    @Published var isCountingDown: Bool = false
    @Published var trainingStarted: Bool = false
    @Published var startTime: Date? = nil

    init() {
        setupLifecycleObserver()
    }

    func start() {
        stop() // cancel any prior timer or countdown

        startTime = Date()
        trainingStarted = true
        lastAnnouncedTime = 0

        if announceTime {
            announceElapsedTime()
        }

        timer = Timer.scheduledTimer(timeInterval: 1.0,
                                     target: self,
                                     selector: #selector(checkAndAnnounceElapsedTime),
                                     userInfo: nil,
                                     repeats: true)
    }

    func stop() {
        timer?.invalidate()
        timer = nil

        countdownWorkItem?.cancel()
        countdownWorkItem = nil

        startTime = nil
        isCountingDown = false
        visualCountdown = nil
        trainingStarted = false

        lastAnnouncedTime = 0
        lastAnnouncedStrikeCount = 0
        currentStrikeCount = 0
    }

    func updateStrikeCount(to newCount: Int) {
        guard announceStrikes, trainingStarted else { return }

        currentStrikeCount = newCount
        if currentStrikeCount - lastAnnouncedStrikeCount >= strikeAnnounceFrequency {
            lastAnnouncedStrikeCount = currentStrikeCount
            speak("\(currentStrikeCount) strikes")
        }
    }

    func startCountdownThenBeginTraining(completion: @escaping () -> Void) {
        let countdownValues = ["4", "3", "2", "1", "Go"]
        isCountingDown = true

        func speakNext(index: Int) {
            guard index < countdownValues.count else {
                visualCountdown = nil
                isCountingDown = false
                trainingStarted = true
                completion()
                return
            }

            visualCountdown = countdownValues[index]

            let utterance = AVSpeechUtterance(string: countdownValues[index])
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.5
            synthesizer.speak(utterance)

            countdownWorkItem = DispatchWorkItem {
                speakNext(index: index + 1)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: countdownWorkItem!)
        }

        speakNext(index: 0)
    }

    @objc private func checkAndAnnounceElapsedTime() {
        guard announceTime, trainingStarted, let start = startTime else { return }

        let elapsed = Int(Date().timeIntervalSince(start))

        let shouldAnnounce = (elapsed >= timeAnnounceFrequency) &&
                             ((elapsed % timeAnnounceFrequency) == 0) &&
                             (elapsed != lastAnnouncedTime)

        if shouldAnnounce {
            lastAnnouncedTime = elapsed
            announceElapsedTime()
        }
    }

    private func announceElapsedTime() {
        guard let start = startTime else { return }

        let elapsed = Int(Date().timeIntervalSince(start))
        let minutes = elapsed / 60
        let seconds = elapsed % 60

        let announcement = minutes > 0
            ? "\(minutes) minute\(minutes == 1 ? "" : "s") and \(seconds) second\(seconds == 1 ? "" : "s")"
            : "\(seconds) second\(seconds == 1 ? "" : "s")"

        speak(announcement)
    }

    func speak(_ text: String) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            print("⚠️ AVAudioSession setup failed: \(error)")
        }

        let warmup = AVSpeechUtterance(string: " ")
        warmup.voice = AVSpeechSynthesisVoice(language: "en-US")
        warmup.volume = 0.0
        warmup.rate = 0.5
        synthesizer.speak(warmup)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }

    private func setupLifecycleObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetSynthesizer()
        }
    }

    private func resetSynthesizer() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        synthesizer = AVSpeechSynthesizer()
    }

    func announceStartOfRound(round: TrainingRound, index: Int, type: TrainingType) {
        let intro = "Start round \(index) \(round.name)"
        speak(intro)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            var goalAnnouncement = ""

            switch type {
            case .forceDriven:
                if let force = round.goalForce, force > 0 {
                    goalAnnouncement = "Target: \(Int(force)) newtons"
                }
            case .strikesDriven:
                if let strikes = round.goalStrikes, strikes > 0 {
                    goalAnnouncement = "Target: \(strikes) strikes"
                }
            case .timeDriven:
                if let time = round.roundTime, time > 0 {
                    goalAnnouncement = "Target: \(time) seconds"
                }
            }

            if !goalAnnouncement.isEmpty {
                self.speak(goalAnnouncement)
            }
        }
    }

    func announceRoundEnded() {
        speak("Round ended")
    }

    func announceRest(for restTime: Int) {
        speak("Rest for \(restTime) seconds")
    }
    
    func announceDisqualified() {
        speak("Disqualified")
    }
    
    func announceTrainingEnded() {
        speak("Training ended")
    }
    
    func maybeAnnounceForce(_ totalForce: Double) {
        guard announceForce, forceAnnounceFrequency > 0 else { return }

        let roundedForce = Int(totalForce)
        if roundedForce / forceAnnounceFrequency != lastAnnouncedForceSegment {
            lastAnnouncedForceSegment = roundedForce / forceAnnounceFrequency
            speak("\(roundedForce) Newtons")
        }
    }

    func maybeAnnounceProgress(_ percent: Double) {
        guard announceProgress, progressAnnounceFrequency > 0 else { return }

        let roundedPercent = Int(percent)
        if roundedPercent / progressAnnounceFrequency != lastAnnouncedProgressSegment {
            lastAnnouncedProgressSegment = roundedPercent / progressAnnounceFrequency
            speak("\(roundedPercent)% completed")
        }
    }
}
