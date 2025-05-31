//
//  TrainingSummaryManager.swift
//  TProAthlete
//
//  Created by Jecky Toledo on 12/05/2025.
//

import FirebaseFirestore
import FirebaseFirestoreSwift

class TrainingSummaryManager {
    private let db = Firestore.firestore()
    private let collection = "training_summaries"

    func saveSummary(_ summary: TrainingSummary, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try db.collection(collection).addDocument(from: summary, completion: { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            })
        } catch {
            completion(.failure(error))
        }
    }
}
