import Foundation
import Firebase
import SwiftUI

class ChallengeListViewModel: ObservableObject {
    @Published var activeChallenges: [Challenge] = []
    @Published var pastChallenges: [Challenge] = []
    @Published var isLoading: Bool = true

    @AppStorage("nickname") private var nickname: String = ""

    // MARK: - Fetch & Classify Challenges
    func fetchChallenges() {
        isLoading = true
        let db = Firestore.firestore()

        let now = Date()
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: now)!
        let threeDaysAhead = Calendar.current.date(byAdding: .day, value: 3, to: now)!
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: now)!

        db.collection("challenges")
            .order(by: "startTime")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false

                    self.activeChallenges = []
                    self.pastChallenges = []

                    guard let documents = snapshot?.documents else {
                        print("❌ Failed to fetch: \(error?.localizedDescription ?? "No snapshot")")
                        return
                    }

                    for doc in documents {
                        let data = doc.data()
                        guard
                            let name = data["challengeName"] as? String,
                            let trainingName = data["trainingName"] as? String,
                            let timestamp = data["startTime"] as? Timestamp,
                            let difficulty = data["difficulty"] as? Int,
                            let comment = data["comment"] as? String,
                            let creator = data["creatorNickname"] as? String,
                            let registered = data["registeredNicknames"] as? [String]
                        else {
                            continue
                        }

                        let startTime = timestamp.dateValue()
                        let runId = data["runId"] as? String

                        let challenge = Challenge(
                            id: doc.documentID,
                            challengeName: name,
                            trainingName: trainingName,
                            startTime: startTime,
                            difficulty: difficulty,
                            comment: comment,
                            creatorNickname: creator,
                            registeredNicknames: registered,
                            runId: runId
                        )

                        if startTime > oneHourAgo && startTime <= threeDaysAhead {
                            self.activeChallenges.append(challenge)
                        } else if startTime >= threeDaysAgo && startTime < oneHourAgo && registered.contains(self.nickname) {
                            self.pastChallenges.append(challenge)
                        }
                    }
                }
            }
    }

    // MARK: - Helpers
    func truncatedComment(_ text: String) -> String {
        let words = text.split(separator: " ")
        return words.count <= 6 ? text : words.prefix(6).joined(separator: " ") + "..."
    }

    func isRegistered(_ challenge: Challenge) -> Bool {
        return challenge.registeredNicknames.contains(nickname)
    }

    func canEnterWaitingRoom(for challenge: Challenge) -> Bool {
        let now = Date()
        let threshold = challenge.startTime.addingTimeInterval(-15 * 60)
        return now >= threshold && now <= challenge.startTime && isRegistered(challenge)
    }

    func toggleRegistration(for challenge: Challenge) {
        let db = Firestore.firestore()
        guard let challengeIndex = activeChallenges.firstIndex(where: { $0.id == challenge.id }) else { return }
        var updated = activeChallenges[challengeIndex]

        if updated.registeredNicknames.contains(nickname) {
            updated.registeredNicknames.removeAll { $0 == nickname }
        } else {
            updated.registeredNicknames.append(nickname)
        }

        db.collection("challenges").document(challenge.id).updateData([
            "registeredNicknames": updated.registeredNicknames
        ]) { error in
            if let error = error {
                print("❌ Error updating registration: \(error.localizedDescription)")
                return
            }

            DispatchQueue.main.async {
                self.activeChallenges[challengeIndex] = updated
            }
        }
    }

    func deleteChallenge(_ challenge: Challenge) {
        let db = Firestore.firestore()
        db.collection("challenges").document(challenge.id).delete { error in
            if error == nil {
                DispatchQueue.main.async {
                    self.activeChallenges.removeAll { $0.id == challenge.id }
                    self.pastChallenges.removeAll { $0.id == challenge.id }
                }
            } else {
                print("❌ Error deleting challenge: \(error?.localizedDescription ?? "Unknown")")
            }
        }
    }
}
