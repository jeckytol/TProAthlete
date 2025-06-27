//
//  EditableRound.swift
//  PunchKickTraining
//
//  Created by Jecky Toledo on 05/05/2025.
//

import Foundation

struct EditableRound {
    var exerciseName: String = predefinedExercises.first ?? "Unnamed"
    var goalForce: Double = 1000
    var cutoffTime: Int? = nil
    var pointsFactor: Double = 1.0
    //var cutoffTime: Int = 0

    //--
    func toTrainingRound() -> TrainingRound {
        TrainingRound(
            name: exerciseName,
            goalForce: goalForce,
            cutoffTime: cutoffTime ?? 0
        )
    }
    //--
}
