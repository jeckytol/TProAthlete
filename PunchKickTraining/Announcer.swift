//
//  Announcer.swift
//  PunchKickTraining
//
//  Created by Jecky Toledo (renamed and expanded)
//

import Foundation
import AVFoundation
import SwiftUI

class Announcer: ObservableObject {
    private var timer: Timer?
    private var synthesizer = AVSpeechSynthesizer()
    private var notificationObserver: NSObjectProtocol?
    private var lastAnnouncedTime: Int = 0
    
    private var countdownWorkItem: DispatchWorkItem?

    @AppStorage("announceTime") var announceTime: Bool = true
    @AppStorage("timeAnnounceFrequency") var timeAnnounceFrequency: Int = 30

    @AppStorage("announceStrikes") var announceStrikes: Bool = true
    @AppStorage("strikeAnnounceFrequency") var strikeAnnounceFrequency: Int = 10

    private var currentStrikeCount: Int = 0
    private var lastAnnouncedStrikeCount: Int = 0

    @Published var visualCountdown: String? = nil
    @Published var isCountingDown: Bool = false
    @Published var trainingStarted: Bool = false
    @Published var startTime: Date? = nil
    

    // MARK: - Public API
    
    //----------
    init() {
        setupLifecycleObserver()
    }
    
    //----------
    func start() {
        self.startTime = Date()
        timer = Timer.scheduledTimer(timeInterval: 1.0,
                                     target: self,
                                     selector: #selector(checkAndAnnounceElapsedTime),
                                     userInfo: nil,
                                     repeats: true)

        if announceTime {
            announceElapsedTime() // Optional: speak immediately
        }
        //-----
        lastAnnouncedTime = 0
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        //-----
        countdownWorkItem?.cancel()
        countdownWorkItem = nil
        //------
        self.startTime = nil
        lastAnnouncedStrikeCount = 0
        currentStrikeCount = 0
        isCountingDown = false
        visualCountdown = nil
        //-------
        lastAnnouncedTime = 0
    }
    
    func updateStrikeCount(to newCount: Int) {
        guard announceStrikes else { return }
        currentStrikeCount = newCount

        if currentStrikeCount - lastAnnouncedStrikeCount >= strikeAnnounceFrequency {
            lastAnnouncedStrikeCount = currentStrikeCount
            let text = "\(currentStrikeCount) strikes"
            speak(text)
        }
    }
    
    //-----
    
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

            let value = countdownValues[index]
            visualCountdown = value

            let utterance = AVSpeechUtterance(string: value)
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
    
    //-----

    // MARK: - Private

    @objc private func checkAndAnnounceElapsedTime() {
        guard announceTime, let start = startTime else { return }

        let elapsed = Int(Date().timeIntervalSince(start))

        let shouldAnnounce = (elapsed >= timeAnnounceFrequency) &&
                             ((elapsed % timeAnnounceFrequency) == 0)

        if shouldAnnounce && elapsed != lastAnnouncedTime {
            lastAnnouncedTime = elapsed
            announceElapsedTime()
        }
        
    }

    private func announceElapsedTime() {
        guard let start = startTime else { return }
        let elapsed = Int(Date().timeIntervalSince(start))

        let minutes = elapsed / 60
        let seconds = elapsed % 60

        var announcement = ""
        if minutes > 0 {
            announcement = "\(minutes) minute\(minutes == 1 ? "" : "s") and \(seconds) second\(seconds == 1 ? "" : "s")"
        } else {
            announcement = "\(seconds) second\(seconds == 1 ? "" : "s")"
        }

        speak(announcement)
    }

    
    private func speak(_ text: String) {
        // Injecting a short silent utterance to force activation
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
    
    func setupLifecycleObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetSynthesizer()
        }
    }
    
    //----
    func announceDisqualified() {
        speak("Disqualified.")
    }
    //----
    
    private func resetSynthesizer() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        print("Resetting speech synthesizer")
        // Reinitialize
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        self.synthesizer = AVSpeechSynthesizer()
    }
}

