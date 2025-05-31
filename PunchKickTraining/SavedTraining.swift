import Foundation

enum TrainingClassification: String, Codable, CaseIterable {
    case easy, medium, hard, superHard
}

struct SavedTraining: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var rounds: [TrainingRound]

    // 🔄 New Fields for sharing & classification
    var creatorNickname: String
    var creationDate: Date
    var isPublic: Bool = false
    var classification: TrainingClassification = .medium
    
    // ✅ NEW: Used to track whether a public training was explicitly downloaded
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
}
