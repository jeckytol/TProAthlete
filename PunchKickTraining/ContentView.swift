//  ContentView.swift
//  PunchKickTraining

import SwiftUI
import CoreHaptics
import AVFoundation
import WatchConnectivity

struct ContentView: View {
    let training: SavedTraining
    @Binding var selectedTraining: SavedTraining?

    //--
    @EnvironmentObject var bluetoothManager: BluetoothManager
    //--
    @StateObject private var announcer = Announcer()
    @StateObject private var sessionManager = TrainingSessionManager()

    @State private var isTraining = false
    @State private var timer: Timer? = nil
    @State private var engine: CHHapticEngine?
    @State private var isShowingSettings = false
    @State private var disqualified: Bool = false
    
    @EnvironmentObject var profileManager: UserProfileManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {

                // Optional visible back button
                if !isTraining {
                    HStack {
                        Button(action: {
                            selectedTraining = nil
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // Top Status and Settings
                HStack {
                    //---
                    Circle()
                        .fill(bluetoothManager.isSensorConnected ? Color.green : Color.red)
                        .frame(width: 14, height: 14)
                    Text(bluetoothManager.connectionStatusText)
                        .foregroundColor(.white)
                        .font(.footnote)
                    //---
                    Spacer()
                    Button(action: { isShowingSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)

                // Start/Stop buttons
                HStack(spacing: 10) {
                    Button(action: startTraining) {
                        Text("Start Training")
                            .font(.headline)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity)
                            .background(isTraining ? Color.gray : Color.green)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                    }
                    .disabled(isTraining)

                    Button(action: stopTraining) {
                        Text("Stop Training")
                            .font(.headline)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity)
                            .background(isTraining ? Color.red : Color.gray)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                    }
                    .disabled(!isTraining)
                }
                .padding(.horizontal)

                // Timer
                Text(formatTime(sessionManager.sessionElapsedTime))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                // Metric Circles
                VStack(spacing: 32) {
                    MetricCircle(title: "Training Goal %", value: String(format: "%.0f%%", bluetoothManager.trainingProgressPercentage), gaugeValue: bluetoothManager.trainingProgressPercentage / 100, gaugeColor: .green)
                    MetricCircle(title: "Total Force", value: String(format: "%.0f", bluetoothManager.totalForce), gaugeValue: nil, gaugeColor: .blue)
                    MetricCircle(title: "Strikes", value: String(bluetoothManager.totalStrikes), gaugeValue: nil, gaugeColor: .red)
                }

                Spacer()

                // Round progress
                VStack(spacing: 8) {
                    HStack {
                        Text("Round Progress").foregroundColor(.white).font(.headline)
                        Spacer()
                        Text(sessionManager.currentRoundName).foregroundColor(.white).font(.subheadline)
                    }
                    ProgressView(value: bluetoothManager.currentForcePercentage / 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: .yellow))
                        .frame(height: 12)
                }
                .padding()
                .background(Color(UIColor.darkGray))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .onAppear {
                let manager = WatchConnectivityManager.shared
                manager.bluetoothManager = bluetoothManager
                
                prepareHaptics()
                bluetoothManager.sessionManager = sessionManager
                bluetoothManager.announcer = announcer
                bluetoothManager.isTrainingActive = false
                sessionManager.startNewSession(with: training.rounds)
                
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetooth, .mixWithOthers])
                try? AVAudioSession.sharedInstance().setActive(true)
                bluetoothManager.stopTrainingCallback = {
                    stopTraining()
                }
            }
            .onChange(of: disqualified) { oldVal, newVal in
                if !oldVal && newVal {
                    announcer.announceDisqualified()
                }
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width > 100 && !isTraining {
                            selectedTraining = nil
                        }
                    }
            )

            if disqualified {
                Text("Disqualified")
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(16)
                    .scaleEffect(1.1)
                    .shadow(color: .red, radius: 10)
                    .transition(.scale)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: disqualified)
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(bluetoothManager: bluetoothManager)
        }

        if let countdownText = announcer.visualCountdown {
            Text(countdownText)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(radius: 10)
                .transition(.scale)
        }
    }
    
    
    //-----
    
    func startTraining() {
        UIApplication.shared.isIdleTimerDisabled = true
        bluetoothManager.isTrainingActive = false
        bluetoothManager.resetMetrics()
        announcer.stop()
        sessionManager.reset()
        isTraining = true
        disqualified = false

        // Reconfigure sensors
        bluetoothManager.configureSensorSource()

        // Notify Watch if selected
        if bluetoothManager.sensorSource == "Watch" {
            let session = WCSession.default

            let startCommand = ["command": "start"]
            if session.isReachable {
                // Send start command
                session.sendMessage(startCommand, replyHandler: nil) { error in
                    print("❌ Failed to send start command to Watch: \(error.localizedDescription)")
                }
                print("📤 Sent start command to Watch.")

                // Send training settings
                let settingsPayload: [String: Any] = [
                    "settings": [
                        "minMotionDuration": bluetoothManager.minMotionDuration,
                        "postStrikeCooldown": bluetoothManager.postStrikeCooldown,
                        "accelerationThreshold": bluetoothManager.accelerationThreshold
                    ]
                ]
                session.sendMessage(settingsPayload, replyHandler: nil) { error in
                    print("❌ Failed to send settings to Watch: \(error.localizedDescription)")
                }
                print("📤 Sent training settings to Watch.")
            } else {
                print("⚠️ Watch is not reachable, saving pending message.")
                WatchConnectivityManager.shared.pendingMessage = startCommand
                // Note: If you want to support deferred settings, you'll need a similar queue for settings too
            }
        }

        announcer.startCountdownThenBeginTraining {
            bluetoothManager.isTrainingActive = true
            sessionManager.startSessionTimer()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if announcer.trainingStarted {
                    announcer.updateStrikeCount(to: bluetoothManager.totalStrikes)
                    let cutoff = sessionManager.currentRound?.cutoffTime ?? 0
                    if cutoff > 0 && sessionManager.sessionElapsedTime >= cutoff {
                        disqualified = true
                        stopTraining()
                    }
                }
            }
            announcer.start()
            triggerHaptic()
        }
    }
   
    
    //-----
    
    func stopTraining() {
        guard isTraining else { return }

        isTraining = false
        UIApplication.shared.isIdleTimerDisabled = false
        timer?.invalidate()
        timer = nil
        announcer.stop()
        sessionManager.stopSessionTimer()
        bluetoothManager.isTrainingActive = false
        triggerHaptic()

        // Send stop command to Watch if it's the selected sensor source
        if bluetoothManager.sensorSource == "Watch" {
            let message: [String: Any] = ["command": "stop"]

            if WCSession.default.isReachable {
                WCSession.default.sendMessage(message, replyHandler: nil) { error in
                    print("❌ Failed to send stop command to Watch: \(error.localizedDescription)")
                }
                print("📤 Sent stop command to Watch.")
            } else {
                print("⚠️ Watch not reachable. Stop command will be sent later.")
                WatchConnectivityManager.shared.pendingMessage = message
            }
        }

        // Save training summary
        let nickname = profileManager.profile?.nickname ?? "Unknown"
        let summary = TrainingSummary(
            trainingName: training.name,
            date: Date(),
            elapsedTime: sessionManager.sessionElapsedTime,
            disqualified: disqualified,
            disqualifiedRound: disqualified ? sessionManager.currentRoundName : nil,
            totalForce: bluetoothManager.totalForce,
            maxForce: bluetoothManager.maxForce,
            averageForce: bluetoothManager.averageForce,
            strikeCount: bluetoothManager.totalStrikes,
            trainingGoalForce: training.rounds.map(\.goalForce).reduce(0, +),
            trainingGoalCompletionPercentage: bluetoothManager.trainingProgressPercentage,
            nickname: nickname
        )

        let manager = TrainingSummaryManager()
        manager.saveSummary(summary) { result in
            switch result {
            case .success:
                print("Training summary saved.")
            case .failure(let error):
                print("Error saving summary: \(error.localizedDescription)")
            }
        }
    }
    
    
    func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func prepareHaptics() {
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptics not available")
        }
    }

    func triggerHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

struct MetricCircle: View {
    var title: String
    var value: String
    var gaugeValue: Double?
    var gaugeColor: Color

    var body: some View {
        HStack(spacing: 22) {
            Text(title)
                .foregroundColor(.white)
                .font(.headline)
                .frame(width: 120, alignment: .leading)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 12)
                    .frame(width: 120, height: 120)

                if let gauge = gaugeValue {
                    Circle()
                        .trim(from: 0.0, to: min(gauge, 1.0))
                        .stroke(gaugeColor, lineWidth: 12)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                        .animation(.easeInOut, value: gauge)
                }

                Text(value)
                    .foregroundColor(.white)
                    .font(.title2)
                    .bold()
            }
        }
    }
}

