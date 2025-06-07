import SwiftUI
import Firebase

struct ChallengeWaitingRoomView: View {
    let challenge: Challenge
    @AppStorage("nickname") private var nickname: String = ""

    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isChallengeStarted = false
    @State private var participants: [String] = []

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isChallengeStarted {
                ChallengeTrainingView(challenge: challenge)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text("Waiting Room")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal)

                    Divider()
                        .background(Color.gray)
                        .padding(.horizontal)

                    // Challenge name
                    Text("Challenge: \(challenge.challengeName)")
                        .foregroundColor(.gray)
                        .font(.headline)
                        .padding(.horizontal)

                    // Countdown
                    Text("Starts in: \(formattedTime(from: timeRemaining))")
                        .font(.title2)
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .padding(.horizontal)

                    // Participants Section
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

                    Spacer()
                }
                .padding(.top)
            }
        }
        .onAppear {
            fetchParticipants()
            startCountdown()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func fetchParticipants() {
        let db = Firestore.firestore()
        let docRef = db.collection("challenges").document(challenge.id)

        docRef.getDocument { snapshot, error in
            if let data = snapshot?.data(),
               let registered = data["registeredNicknames"] as? [String] {
                participants = registered.sorted()
            }
        }
    }

    private func startCountdown() {
        let startTime = challenge.startTime
        let now = Date()
        timeRemaining = max(startTime.timeIntervalSince(now), 0)

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
