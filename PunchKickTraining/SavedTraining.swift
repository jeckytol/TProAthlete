import Foundation

enum TrainingClassification: String, Codable, CaseIterable {
    case easy, medium, hard, superHard
}

struct SavedTraining: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var rounds: [TrainingRound]

    var creatorNickname: String
    var creationDate: Date
    var isPublic: Bool = false
    var classification: TrainingClassification = .medium
    var isDownloadedFromPublic: Bool = false

    static func loadAll() -> [SavedTraining] {
        if let data = UserDefaults.standard.data(forKey: "savedTrainings"),
           let decoded = try? JSONDecoder().decode([SavedTraining].self, from: data) {
            return decoded
        }
        return []
    }

    static func saveAll(_ trainings: [SavedTraining]) {
        if let encoded = try? JSONEncoder().encode(trainings) {
            UserDefaults.standard.set(encoded, forKey: "savedTrainings")
        }
    }

    // MARK: - Equatable Conformance
    static func == (lhs: SavedTraining, rhs: SavedTraining) -> Bool {
        return lhs.id == rhs.id
    }
}
