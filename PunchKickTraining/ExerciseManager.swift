import Foundation
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

class ExerciseManager: ObservableObject {
    // MARK: - Singleton for Global Access
    static let shared = ExerciseManager(isShared: true)

    // MARK: - Internal Initializer
    private init(isShared: Bool) {
        if isShared {
            print("📦 [ExerciseManager] Shared instance initialized")
            fetchExercises()
        }
    }

    // MARK: - Public Convenience Init for SwiftUI Views
    convenience init() {
        self.init(isShared: false)
        print("🧩 [ExerciseManager] SwiftUI instance initialized (no auto-fetch)")
    }

    // MARK: - Properties
    @Published var exercises: [Exercise] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()
    private let collectionName = "exercises"

    // MARK: - Fetch All Exercises
    func fetchExercises() {
        isLoading = true
        errorMessage = nil

        print("📥 [ExerciseManager] Fetching all exercises...")

        db.collection(collectionName)
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false

                    if let error = error {
                        self?.errorMessage = "Error fetching exercises: \(error.localizedDescription)"
                        print("❌ [ExerciseManager] \(self?.errorMessage ?? "")")
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        self?.errorMessage = "No exercises found."
                        print("⚠️ [ExerciseManager] No documents returned.")
                        return
                    }

                    self?.exercises = documents.compactMap { doc in
                        try? doc.data(as: Exercise.self)
                    }

                    print("✅ [ExerciseManager] Loaded \(self?.exercises.count ?? 0) exercises.")
                }
            }
    }

    // MARK: - Save (Create or Update)
    func saveExercise(_ exercise: Exercise, completion: ((Result<Void, Error>) -> Void)? = nil) {
        if let id = exercise.id, !id.isEmpty {
            updateExercise(exercise, completion: completion)
        } else {
            addExercise(exercise, completion: completion)
        }
    }

    // MARK: - Add New
    func addExercise(_ exercise: Exercise, completion: ((Result<Void, Error>) -> Void)? = nil) {
        do {
            var newExercise = exercise
            newExercise.createdAt = Date()

            _ = try db.collection(collectionName).addDocument(from: newExercise) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ [ExerciseManager] Failed to add: \(error.localizedDescription)")
                        completion?(.failure(error))
                    } else {
                        print("✅ [ExerciseManager] Exercise added.")
                        self.fetchExercises()
                        completion?(.success(()))
                    }
                }
            }
        } catch {
            print("❌ [ExerciseManager] Serialization error: \(error.localizedDescription)")
            completion?(.failure(error))
        }
    }

    // MARK: - Update
    func updateExercise(_ exercise: Exercise, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let id = exercise.id else {
            completion?(.failure(NSError(domain: "Missing ID", code: -1)))
            return
        }

        do {
            try db.collection(collectionName).document(id).setData(from: exercise, merge: true) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ [ExerciseManager] Failed to update: \(error.localizedDescription)")
                        completion?(.failure(error))
                    } else {
                        print("✅ [ExerciseManager] Exercise updated.")
                        self.fetchExercises()
                        completion?(.success(()))
                    }
                }
            }
        } catch {
            completion?(.failure(error))
        }
    }

    // MARK: - Delete
    func deleteExercise(_ exercise: Exercise, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let id = exercise.id else {
            completion?(.failure(NSError(domain: "Missing ID", code: -1)))
            return
        }

        db.collection(collectionName).document(id).delete { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [ExerciseManager] Failed to delete: \(error.localizedDescription)")
                    completion?(.failure(error))
                } else {
                    self.exercises.removeAll { $0.id == id }
                    print("🗑️ [ExerciseManager] Exercise deleted.")
                    completion?(.success(()))
                }
            }
        }
    }

    // MARK: - Lookup by Name (Safe, trimmed, case-insensitive)
    func getExercise(named name: String) -> Exercise? {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let found = exercises.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target
        })

        if found == nil {
            print("❌ Failed to get exercise for round: \(name)")
        }

        return found
    }
}
