//
//  TrainingSummary.swift
//  TProAthlete
//
//  Created by Jecky Toledo on 12/05/2025.
//

import Foundation
import FirebaseFirestoreSwift

struct TrainingSummary: Codable, Identifiable {
    @DocumentID var id: String? // Let Firestore manage this
    //@DocumentID var id: String? = UUID().uuidString
    
    var trainingName: String
    var date: Date
    var elapsedTime: Int
    var disqualified: Bool
    var disqualifiedRound: String?
    var totalForce: Double
    var maxForce: Double
    var averageForce: Double
    var strikeCount: Int
    var trainingGoalForce: Double
    var trainingGoalCompletionPercentage: Double
    var totalPoints: Double?
    var nickname: String
}
