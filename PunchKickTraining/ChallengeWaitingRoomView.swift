import SwiftUI
import Firebase

struct ChallengeWaitingRoomView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    let challenge: Challenge
    @AppStorage("nickname") private var nickname: String = ""

    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isChallengeStarted = false
    @State private var participants: [String] = []
    @State private var matchedTraining: SavedTraining? = nil
    @State private var isDownloading = false
    @State private var runId: String = UUID().uuidString
    @State private var hasResolvedRunId = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isChallengeStarted, let training = matchedTraining {
                ChallengeTrainingView(challenge: challenge, training: training, runId: runId)
                    .environmentObject(bluetoothManager)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Waiting Room")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal)

                    Divider()
                        .background(Color.gray)
                        .padding(.horizontal)

                    Text("Challenge: \(challenge.challengeName)")
                        .foregroundColor(.gray)
                        .font(.headline)
                        .padding(.horizontal)

                    Text("Starts in: \(formattedTime(from: timeRemaining))")
                        .font(.title2)
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Participants:")
                            .foregroundColor(.white)
                            .font(.headline)

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(participants, id: \.self) { name in
                                    Text(name)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                        }
                        .frame(maxHeight: 200)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)

                    if isDownloading {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Downloading training...")
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal)
                    } else if matchedTraining == nil {
                        Text("⚠️ Training not found: \(challenge.trainingName)")
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.top)
            }
        }
        .onAppear {
            fetchParticipants()
            findOrDownloadTraining()
            resolveRunIdIfNeeded()
            startCountdown()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: isChallengeStarted) { started in
            if started {
                print("🔁 Challenge started. Using runId: \(runId)")
            }
        }
    }

    // MARK: - Logic

    private func fetchParticipants() {
        let db = Firestore.firestore()
        let docRef = db.collection("challenges").document(challenge.id)

        docRef.getDocument { snapshot, _ in
            if let data = snapshot?.data(),
               let registered = data["registeredNicknames"] as? [String] {
                participants = registered.sorted()
            }
        }
    }

    private func findOrDownloadTraining() {
        let allTrainings = SavedTraining.loadAll()

        if let match = allTrainings.first(where: { $0.name == challenge.trainingName }) {
            matchedTraining = match
            return
        }

        isDownloading = true
        let db = Firestore.firestore()
        db.collection("public_trainings")
            .whereField("name", isEqualTo: challenge.trainingName)
            .getDocuments { snapshot, error in
                isDownloading = false

                if let error = error {
                    print("❌ Failed to download training: \(error.localizedDescription)")
                    return
                }

                guard let doc = snapshot?.documents.first else {
                    print("❌ No training found with name: \(challenge.trainingName)")
                    return
                }

                do {
                    let training = try doc.data(as: SavedTraining.self)
                    matchedTraining = training

                    var updatedTrainings = allTrainings
                    updatedTrainings.append(training)
                    SavedTraining.saveAll(updatedTrainings)

                    print("✅ Downloaded and saved training: \(training.name)")
                } catch {
                    print("❌ Failed to decode training: \(error.localizedDescription)")
                }
            }
    }

    private func resolveRunIdIfNeeded() {
        guard !hasResolvedRunId else {
            print("🔁 runId already resolved: \(runId)")
            return
        }

        let db = Firestore.firestore()
        let docRef = db.collection("challenges").document(challenge.id)

        docRef.getDocument { snapshot, error in
            if let error = error {
                print("❌ Error fetching challenge document: \(error.localizedDescription)")
                return
            }

            if let existingRunId = snapshot?.data()?["runId"] as? String {
                print("📥 Overriding old runId: \(existingRunId)")
            }

            let newRunId = UUID().uuidString
            runId = newRunId
            print("🚀 New runId created before challenge starts: \(runId)")

            docRef.updateData(["runId": newRunId]) { err in
                if let err = err {
                    print("❌ Failed to save runId: \(err.localizedDescription)")
                } else {
                    print("✅ runId saved to Firestore")
                }
                hasResolvedRunId = true
            }
        }
    }

    private func startCountdown() {
        let now = Date()
        timeRemaining = max(challenge.startTime.timeIntervalSince(now), 0)

        if timeRemaining <= 0 {
            isChallengeStarted = true
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            timeRemaining -= 1
            if timeRemaining <= 0 {
                timer?.invalidate()
                isChallengeStarted = true
            }
        }
    }

    private func formattedTime(from interval: TimeInterval) -> String {
        let seconds = Int(interval)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
