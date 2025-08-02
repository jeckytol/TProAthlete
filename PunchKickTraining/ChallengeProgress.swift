//
//  ChallengeProgress.swift
//  TProAthlete
//
//  Created by Jecky Toledo on 08/06/2025.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct ChallengeProgress: Codable, Identifiable {
    @DocumentID var id: String?  // Firestore document ID

    var userId: String           // Device or user identifier
    var challengeId: String
    var runId: String            // 🔹 Unique ID for this specific training run of the challenge

    var nickname: String
    var avatarName: String?

    var totalForce: Double       // Accumulated force
    var totalReps: Int        // Count of reps
    var totalPoints: Double 
    var isDisqualified: Bool

    var roundName: String        // Name of the current round
    var roundNumber: Int         // Index of current round (1-based)
    var roundProgress: Double    // Completion ratio [0.0 - 1.0]

    var createdAt: Date          // For sorting or freshness

    @ServerTimestamp var updatedAt: Timestamp?  // Auto-set by Firestore on update
}
