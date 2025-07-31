// ContentView.swift

import SwiftUI
import CoreHaptics
import AVFoundation
import WatchConnectivity

struct ContentView: View {
    let training: SavedTraining
    @Binding var selectedTraining: SavedTraining?

    @EnvironmentObject var bluetoothManager: BluetoothManager
    @StateObject private var announcer = Announcer()
    @StateObject private var sessionManager = TrainingSessionManager()
    @EnvironmentObject var profileManager: UserProfileManager

    @State private var isTraining = false
    @State private var timer: Timer? = nil
    @State private var engine: CHHapticEngine?
    @State private var isShowingSettings = false
    @State private var disqualified: Bool = false
    @State private var trainingSummaryForCertificate: TrainingSummary? = nil

    var trainingProgressPercentage: Double {
        return bluetoothManager.trainingProgressPercentage
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                if !isTraining {
                    HStack {
                        Button(action: { selectedTraining = nil }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }.foregroundColor(.white)
                        }
                        Spacer()
                    }.padding(.horizontal)
                }

                HStack {
                    Circle()
                        .fill(bluetoothManager.isSensorConnected ? Color.green : Color.red)
                        .frame(width: 14, height: 14)
                    Text(bluetoothManager.connectionStatusText)
                        .foregroundColor(.white)
                        .font(.footnote)
                    Spacer()
                    Button(action: { isShowingSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }.padding(.horizontal)
                
                HStack(spacing: 10) {
                    // Start Training Button
                    Button("Start Training", action: startTraining)
                        .disabled(isTraining)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .foregroundColor(isTraining ? .gray : .green)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isTraining ? Color.gray : Color.green, lineWidth: 3)
                        )
                        .cornerRadius(8)

                    // Stop Training Button
                    Button("Stop Training", action: stopTraining)
                        .disabled(!isTraining)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .foregroundColor(isTraining ? .red : .gray)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isTraining ? Color.red : Color.gray, lineWidth: 3)
                        )
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                Text(formatTime(sessionManager.activeElapsedTime)) // total active time (most likely intended)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                VStack(spacing: 32) {
                    MetricCircle(
                        title: "Training Goal %",
                        value: String(format: "%.0f%%", trainingProgressPercentage),
                        gaugeValue: trainingProgressPercentage / 100,
                        gaugeColor: Color.green
                    )
                    MetricCircle(
                        title: "Total Force",
                        value: String(format: "%.0f", bluetoothManager.totalForce),
                        gaugeValue: nil,
                        gaugeColor: Color.blue
                    )
                    MetricCircle(
                        title: "Strikes",
                        value: String(bluetoothManager.totalStrikes),
                        gaugeValue: nil,
                        gaugeColor: Color.red
                    )
                }

                Spacer()

                VStack(spacing: 8) {
                    HStack {
                        Text("Round Progress").foregroundColor(.white).font(.headline)
                        Spacer()
                        Text(sessionManager.currentRoundName).foregroundColor(.white).font(.subheadline)
                    }

                    if training.trainingType == .timeDriven {
                        let currentTime = Double(sessionManager.currentRound?.roundTime ?? 1)
                        ProgressView(value: Double(sessionManager.activeElapsedTimeForCurrentRound), total: currentTime)
                            .progressViewStyle(LinearProgressViewStyle(tint: .yellow))
                            .frame(height: 12)
                    } else {
                        ProgressView(value: bluetoothManager.currentRoundProgressPercentage / 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: .yellow))
                            .frame(height: 12)
                    }
                }
                .padding()
                .background(Color(UIColor.darkGray))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .onAppear {
                prepareHaptics()

                    // Dependency injection
                    bluetoothManager.sessionManager = sessionManager
                
                    sessionManager.bluetoothManager = bluetoothManager
                
                    bluetoothManager.announcer = announcer
                    sessionManager.announcer = announcer

                    // Ensure training is inactive
                    bluetoothManager.isTrainingActive = false

                    // Reset training session and metrics
                    sessionManager.resetSession()
                    bluetoothManager.resetMetrics()

                    // Stop training callback setup
                    sessionManager.stopTrainingCallback = { [weak sessionManager] in
                        guard let manager = sessionManager else { return }
                        if manager.stopTrainingCallback != nil {
                            manager.stopTrainingCallback = nil
                            stopTraining()
                        }
                    }
                
                    //sessionManager.stopTrainingCallback = {
                        //stopTraining()
                    //}
                

                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetooth, .mixWithOthers])
                try? AVAudioSession.sharedInstance().setActive(true)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(bluetoothManager: bluetoothManager)
            }
            .sheet(item: $trainingSummaryForCertificate) { summary in
                TrainingCertificatePreviewView(summary: summary)
            }

            if let countdownText = announcer.visualCountdown {
                Text(countdownText)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                    .transition(.scale)
            }

            if disqualified {
                Text("Disqualified")
                    .font(.system(size: 60, weight: .heavy))
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(16)
                    .scaleEffect(1.1)
                    .shadow(color: .red, radius: 10)
                    .transition(.scale)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: disqualified)
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
                .zIndex(1)
            }
        }
    }

    
    
    func startTraining() {
        UIApplication.shared.isIdleTimerDisabled = true
        bluetoothManager.isTrainingActive = false
        announcer.stop()

        sessionManager.resetSession()
        sessionManager.announcer = announcer
        isTraining = true
        disqualified = false
        bluetoothManager.configureSensorSource()

        announcer.startCountdownThenBeginTraining {
            bluetoothManager.isTrainingActive = true
            announcer.trainingStarted = true

            sessionManager.startNewSession(with: training.rounds, type: training.trainingType)
            bluetoothManager.resetMetrics()

            triggerHaptic()

            bluetoothManager.stopTrainingCallback = {
                stopTraining()
            }
            

            // ✅ Start a timer for round progress and disqualification check
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                // ✅ Check disqualification condition for force/strikes trainings
                if (training.trainingType == .forceDriven || training.trainingType == .strikesDriven),
                   let cutoff = sessionManager.currentRound?.cutoffTime,
                   cutoff > 0,
                   sessionManager.activeElapsedTimeForCurrentRound >= cutoff,
                   !sessionManager.isCurrentRoundGoalMet,
                   !disqualified {

                    disqualified = true
                    announcer.announceDisqualified()
                    stopTraining()
                }
            }
        }
    }
    
    func stopTraining() {
        guard isTraining else { return }
        isTraining = false
        UIApplication.shared.isIdleTimerDisabled = false
        timer?.invalidate()
        announcer.announceTrainingEnded()
        announcer.stop()
        sessionManager.stopSessionTimer()
        bluetoothManager.isTrainingActive = false
        triggerHaptic()

        //print("🧾 Saving summary with goalCompletion: \(sessionManager.trainingGoalCompletionPercentage)")
        print("🧾 Saving summary with goalCompletion: \(bluetoothManager.trainingProgressPercentage)")
        
        let summary = TrainingSummary(
            trainingName: training.name,
            date: Date(),
            elapsedTime: sessionManager.activeElapsedTime,
            disqualified: disqualified,
            disqualifiedRound: disqualified ? sessionManager.currentRoundName : nil,
            totalForce: bluetoothManager.totalForce,
            maxForce: bluetoothManager.maxForce,
            averageForce: bluetoothManager.averageForce,
            strikeCount: bluetoothManager.totalStrikes,
            trainingGoalForce: training.rounds.map { $0.goalForce ?? 0 }.reduce(0, +),
            trainingGoalCompletionPercentage: bluetoothManager.trainingProgressPercentage,
            totalPoints: bluetoothManager.totalPoints,
            nickname: profileManager.profile?.nickname ?? "Unknown"
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            trainingSummaryForCertificate = summary
        }

        TrainingSummaryManager().saveSummary(summary) { _ in }
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
}
