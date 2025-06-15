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

    /// Save or update challenge progress for a specific run
    func updateProgress(_ progress: ChallengeProgress) {
        guard !progress.challengeId.isEmpty, !progress.runId.isEmpty else {
            print("[Progress] Skipped update — missing challengeId or runId")
            return
        }

        // Document ID now includes runId to avoid overwriting past runs
        let documentId = "\(progress.challengeId)_\(progress.runId)_\(progress.userId)"

        do {
            try db.collection(collection)
                .document(documentId)
                .setData(from: progress, merge: true)
        } catch {
            print("❌ Error updating progress: \(error)")
        }
    }

    /// Observe leaderboard progress for a specific run of a challenge
    func observeProgress(for challengeId: String, runId: String) {
        stopObserving() // remove previous listener if any

        listener = db.collection(collection)
            .whereField("challengeId", isEqualTo: challengeId)
            .whereField("runId", isEqualTo: runId)
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
