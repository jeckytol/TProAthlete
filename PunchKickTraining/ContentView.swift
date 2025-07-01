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
                    Button("Start Training", action: startTraining)
                        .disabled(isTraining)
                        .padding()
                        .background(isTraining ? Color.gray : Color.green)
                        .foregroundColor(.black)
                        .cornerRadius(8)

                    Button("Stop Training", action: stopTraining)
                        .disabled(!isTraining)
                        .padding()
                        .background(isTraining ? Color.red : Color.gray)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }.padding(.horizontal)

                Text(formatTime(sessionManager.sessionElapsedTime))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                VStack(spacing: 32) {
                    MetricCircle(title: "Training Goal %", value: String(format: "%.0f%%", bluetoothManager.trainingProgressPercentage), gaugeValue: bluetoothManager.trainingProgressPercentage / 100, gaugeColor: .green)
                    MetricCircle(title: "Total Force", value: String(format: "%.0f", bluetoothManager.totalForce), gaugeValue: nil, gaugeColor: .blue)
                    MetricCircle(title: "Strikes", value: String(bluetoothManager.totalStrikes), gaugeValue: nil, gaugeColor: .red)
                }

                Spacer()

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
                prepareHaptics()
                bluetoothManager.sessionManager = sessionManager
                bluetoothManager.announcer = announcer
                bluetoothManager.isTrainingActive = false
                sessionManager.startNewSession(with: training.rounds)
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetooth, .mixWithOthers])
                try? AVAudioSession.sharedInstance().setActive(true)
                bluetoothManager.stopTrainingCallback = { stopTraining() }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(bluetoothManager: bluetoothManager)
            }
            //-----
            //.sheet(item: $trainingSummaryForCertificate) { summary in
             //   TrainingCertificateView(summary: summary)
            //}
            //---
            .sheet(item: $trainingSummaryForCertificate) { summary in
                TrainingCertificatePreviewView(summary: summary)
            }
            
            //----

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
        }
    }

    func startTraining() {
        UIApplication.shared.isIdleTimerDisabled = true
        bluetoothManager.isTrainingActive = false
        bluetoothManager.resetMetrics()
        announcer.stop()
        sessionManager.reset()
        isTraining = true
        disqualified = false

        bluetoothManager.configureSensorSource()

        announcer.startCountdownThenBeginTraining {
            bluetoothManager.isTrainingActive = true
            announcer.trainingStarted = true
            sessionManager.startSessionTimer()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if announcer.trainingStarted {
                    announcer.updateStrikeCount(to: bluetoothManager.totalStrikes)
                    if let cutoff = sessionManager.currentRound?.cutoffTime, cutoff > 0 && sessionManager.sessionElapsedTime >= cutoff {
                        disqualified = true
                        stopTraining()
                    }
                }
            }
            announcer.start()
            triggerHaptic()
        }
    }

    func stopTraining() {
        guard isTraining else { return }
        isTraining = false
        UIApplication.shared.isIdleTimerDisabled = false
        timer?.invalidate()
        announcer.stop()
        sessionManager.stopSessionTimer()
        bluetoothManager.isTrainingActive = false
        triggerHaptic()

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
            trainingGoalForce: training.rounds.map(\ .goalForce).reduce(0, +),
            trainingGoalCompletionPercentage: bluetoothManager.trainingProgressPercentage,
            totalPoints: bluetoothManager.totalPoints,
            nickname: profileManager.profile?.nickname ?? "Unknown"
        )

        trainingSummaryForCertificate = summary
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
