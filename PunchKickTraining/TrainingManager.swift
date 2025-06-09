//
//  TrainingManager.swift
//  TProAthlete
//
//  Created by Jecky Toledo on 09/06/2025.
//

import Foundation

class TrainingManager: ObservableObject {
    @Published var allTrainings: [SavedTraining] = []

    init() {
        loadTrainings()
    }

    func loadTrainings() {
        allTrainings = SavedTraining.loadAll()
    }

    func findTraining(named name: String) -> SavedTraining? {
        allTrainings.first { $0.name == name }
    }
}
