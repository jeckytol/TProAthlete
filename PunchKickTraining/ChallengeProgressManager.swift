// ChallengeProgressManager.swift (Refactored)
// Observable Firestore-driven manager for challenge progress

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

class ChallengeProgressManager: ObservableObject {
    private let db = Firestore.firestore()
    private let collection = "challenge_progress"

    @Published var allProgress: [ChallengeProgress] = []
    private var listener: ListenerRegistration?

    func updateProgress(_ progress: ChallengeProgress) {
        guard !progress.challengeId.isEmpty else {
            print("[Progress] Skipped update — missing challengeId")
            return
        }

        let documentId = "\(progress.challengeId)_\(progress.userId)"

        do {
            try db.collection(collection)
                .document(documentId)
                .setData(from: progress, merge: true)
        } catch {
            print("❌ Error updating progress: \(error)")
        }
    }

    func observeProgress(for challengeId: String) {
        listener?.remove()  // remove previous listener if any

        listener = db.collection(collection)
            .whereField("challengeId", isEqualTo: challengeId)
            .order(by: "totalForce", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("[Progress] No leaderboard data")
                    return
                }

                let progresses: [ChallengeProgress] = documents.compactMap { doc in
                    try? doc.data(as: ChallengeProgress.self)
                }

                DispatchQueue.main.async {
                    self.allProgress = progresses
                }
            }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
    }
}

