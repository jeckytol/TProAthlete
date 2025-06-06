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
                VStack(spacing: 20) {
                    Text("Waiting Room")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)

                    Text("Challenge: \(challenge.challengeName)")
                        .foregroundColor(.gray)
                        .font(.headline)

                    Text("Starts in: \(formattedTime(from: timeRemaining))")
                        .font(.title2)
                        .foregroundColor(.white)
                        .monospacedDigit()

                    Divider().background(Color.gray)

                    VStack(alignment: .leading) {
                        Text("Participants:")
                            .foregroundColor(.white)
                            .font(.headline)

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(participants, id: \.self) { name in
                                    Text(name)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                        .padding(.horizontal)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .padding()
                }
                .padding()
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
