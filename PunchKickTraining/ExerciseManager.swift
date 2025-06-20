import Foundation
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

class ExerciseManager: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()
    private let collectionName = "exercises"

    // MARK: - Fetch All Exercises
    func fetchExercises() {
        isLoading = true
        errorMessage = nil

        db.collection(collectionName)
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false

                    if let error = error {
                        self?.errorMessage = "Error fetching exercises: \(error.localizedDescription)"
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        self?.errorMessage = "No exercises found."
                        return
                    }

                    self?.exercises = documents.compactMap { doc in
                        try? doc.data(as: Exercise.self)
                    }
                }
            }
    }

    // MARK: - Save (Create or Update) Exercise
    func saveExercise(_ exercise: Exercise, completion: ((Result<Void, Error>) -> Void)? = nil) {
        if let id = exercise.id, !id.isEmpty {
            updateExercise(exercise, completion: completion)
        } else {
            addExercise(exercise, completion: completion)
        }
    }

    // MARK: - Add New Exercise
    func addExercise(_ exercise: Exercise, completion: ((Result<Void, Error>) -> Void)? = nil) {
        do {
            var newExercise = exercise
            newExercise.createdAt = Date()
            _ = try db.collection(collectionName).addDocument(from: newExercise) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion?(.failure(error))
                    } else {
                        self.fetchExercises()
                        completion?(.success(()))
                    }
                }
            }
        } catch {
            completion?(.failure(error))
        }
    }

    // MARK: - Update Existing Exercise
    func updateExercise(_ exercise: Exercise, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let id = exercise.id else {
            completion?(.failure(NSError(domain: "Missing ID", code: -1)))
            return
        }

        do {
            try db.collection(collectionName).document(id).setData(from: exercise, merge: true) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion?(.failure(error))
                    } else {
                        self.fetchExercises()
                        completion?(.success(()))
                    }
                }
            }
        } catch {
            completion?(.failure(error))
        }
    }

    // MARK: - Delete Exercise
    func deleteExercise(_ exercise: Exercise, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let id = exercise.id else {
            completion?(.failure(NSError(domain: "Missing ID", code: -1)))
            return
        }

        db.collection(collectionName).document(id).delete { error in
            DispatchQueue.main.async {
                if let error = error {
                    completion?(.failure(error))
                } else {
                    self.exercises.removeAll { $0.id == id }
                    completion?(.success(()))
                }
            }
        }
    }
}
