// ChallengeProgressManager.swift (Refactored with Logging)
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
            print("[Progress] ❌ Skipped update — missing challengeId or runId")
            return
        }

        // Document ID format ensures uniqueness per run per user
        let documentId = "\(progress.challengeId)_\(progress.runId)_\(progress.userId)"

        // 🔍 Logging the full progress payload before saving
        print("""
        [Progress] 🔄 Saving ChallengeProgress:
        User: \(progress.nickname)
        Challenge: \(progress.challengeId)
        Run: \(progress.runId)
        Total Points: \(progress.totalPoints)
        Total Strikes: \(progress.totalStrikes)
        Round: \(progress.roundName)
        Round Progress: \(String(format: "%.1f", progress.roundProgress))%
        Disqualified: \(progress.isDisqualified)
        """)

        do {
            try db.collection(collection)
                .document(documentId)
                .setData(from: progress, merge: true)
        } catch {
            print("❌ Firestore update error: \(error.localizedDescription)")
        }
    }

    /// Observe leaderboard progress for a specific run of a challenge
    func observeProgress(for challengeId: String, runId: String) {
        stopObserving()

        listener = db.collection(collection)
            .whereField("challengeId", isEqualTo: challengeId)
            .whereField("runId", isEqualTo: runId)
            .order(by: "totalForce", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Firestore snapshot error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("[Progress] ⚠️ No leaderboard documents found")
                    return
                }

                let progresses: [ChallengeProgress] = documents.compactMap {
                    try? $0.data(as: ChallengeProgress.self)
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
    
    func resetUserProgress(for challengeId: String, runId: String, userId: String) {
        let docRef = db.collection("challenge_progress")
            .whereField("challengeId", isEqualTo: challengeId)
            .whereField("runId", isEqualTo: runId)
            .whereField("userId", isEqualTo: userId)

        docRef.getDocuments { snapshot, error in
            if let error = error {
                print("⚠️ Failed to fetch previous progress: \(error)")
                return
            }

            snapshot?.documents.forEach { doc in
                doc.reference.delete { deleteError in
                    if let deleteError = deleteError {
                        print("⚠️ Failed to delete old progress doc: \(deleteError)")
                    } else {
                        print("🗑️ Deleted previous progress for user \(userId)")
                    }
                }
            }
        }
    }
}
