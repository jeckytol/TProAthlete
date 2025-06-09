//
//  TrainingSessionManager.swift
//  PunchKickTraining
//
//  Created by Jecky Toledo on 04/05/2025.
//

import Foundation
import Combine
import AVFoundation
import UIKit

class TrainingSessionManager: ObservableObject {
    
    
    @Published var observedRoundName: String = "–"
    @Published var observedRoundGoal: Double = 0
    @Published var observedRoundNumber: Int = 0
    
    // MARK: - Audio
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    
    // MARK: - Rounds
    @Published var rounds: [TrainingRound] = []
    @Published var currentRoundIndex: Int = 0
    
    // MARK: - Timer
    @Published var sessionElapsedTime: Int = 0
    private var sessionStartTime: Date?
    private var timer: Timer?

    // MARK: - Round Accessors
    var currentRound: TrainingRound? {
        guard rounds.indices.contains(currentRoundIndex) else { return nil }
        return rounds[currentRoundIndex]
    }

    var currentRoundName: String {
        currentRound?.name ?? "–"
    }

    var currentRoundGoal: Double {
        currentRound?.goalForce ?? 0
    }

    var hasNextRound: Bool {
        currentRoundIndex + 1 < rounds.count
    }

    var totalRounds: Int {
        rounds.count
    }

    var roundNumber: Int {
        currentRoundIndex + 1
    }

    // MARK: - Public Methods

  
    
    func startNewSession(with rounds: [TrainingRound]) {
        self.rounds = rounds
        self.currentRoundIndex = 0
        self.sessionElapsedTime = 0
        self.sessionStartTime = nil

        updateObservedRoundInfo()
    }

    
    func advanceToNextRound() {
        guard hasNextRound else {
            print("No more rounds.")
            return
        }

        currentRoundIndex += 1
        let newRound = rounds[currentRoundIndex]
        updateObservedRoundInfo()
        playBipSound()
        announceRoundName(newRound.name)
    }
    
    private func updateObservedRoundInfo() {
        observedRoundName = currentRound?.name ?? "–"
        observedRoundGoal = currentRound?.goalForce ?? 0
        observedRoundNumber = currentRoundIndex + 1
    }

    func reset() {
        currentRoundIndex = 0
        sessionElapsedTime = 0
        stopSessionTimer()
    }

    // MARK: - Timer Management

    func startSessionTimer() {
        sessionStartTime = Date()
        sessionElapsedTime = 0

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.sessionStartTime else { return }
            DispatchQueue.main.async {
                self.sessionElapsedTime = Int(Date().timeIntervalSince(start))
            }
        }
    }

    func stopSessionTimer() {
        timer?.invalidate()
        timer = nil
        sessionStartTime = nil
    }

    // MARK: - Sound & Speech

    private func playBipSound() {
        guard let soundURL = Bundle.main.url(forResource: "bip", withExtension: "wav") else {
            print("Bip sound file not found.")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Error playing bip sound: \(error)")
        }
    }

    private func announceRoundName(_ name: String) {
        let utterance = AVSpeechUtterance(string: "Next round: \(name)")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
}
