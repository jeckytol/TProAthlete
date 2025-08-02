import Foundation

enum TrainingClassification: String, Codable, CaseIterable {
    case easy, medium, hard, superHard
}

enum TrainingType: String, Codable, CaseIterable {
    case forceDriven
    case repsDriven
    case timeDriven

    var description: String {
        switch self {
        case .forceDriven:
            return "Goal: Achieve target force per round as fast as possible."
        case .repsDriven:
            return "Goal: Achieve target number of reps per round as fast as possible."
        case .timeDriven:
            return "Goal: Maximize Force/Reps output within the given time."
        }
    }

    var label: String {
        switch self {
        case .forceDriven: return "Force Driven"
        case .repsDriven: return "Reps Driven"
        case .timeDriven: return "Time Driven"
        }
    }
}

struct SavedTraining: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var rounds: [TrainingRound]
    var creatorNickname: String
    var creationDate: Date
    var isPublic: Bool
    var classification: TrainingClassification
    var isDownloadedFromPublic: Bool
    var trainingType: TrainingType

    // MARK: - Backward Compatible Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        rounds = try container.decode([TrainingRound].self, forKey: .rounds)
        creatorNickname = try container.decodeIfPresent(String.self, forKey: .creatorNickname) ?? "Unknown"
        creationDate = try container.decodeIfPresent(Date.self, forKey: .creationDate) ?? Date()
        isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? false
        classification = try container.decodeIfPresent(TrainingClassification.self, forKey: .classification) ?? .medium
        isDownloadedFromPublic = try container.decodeIfPresent(Bool.self, forKey: .isDownloadedFromPublic) ?? false

        // Support backward compatibility with old trainingType values
        if let rawType = try container.decodeIfPresent(String.self, forKey: .trainingType) {
            if rawType == "strengthDriven" {
                // Default to forceDriven for backward compatibility
                trainingType = .forceDriven
            } else if let parsed = TrainingType(rawValue: rawType) {
                trainingType = parsed
            } else {
                trainingType = .forceDriven
            }
        } else {
            trainingType = .forceDriven
        }
    }

    // MARK: - Manual Initializer (for backward compatibility in Firestore decoding)
    init(
        id: UUID = UUID(),
        name: String,
        rounds: [TrainingRound],
        creatorNickname: String,
        creationDate: Date,
        isPublic: Bool = false,
        classification: TrainingClassification = .medium,
        isDownloadedFromPublic: Bool = false,
        trainingType: TrainingType = .forceDriven
    ) {
        self.id = id
        self.name = name
        self.rounds = rounds
        self.creatorNickname = creatorNickname
        self.creationDate = creationDate
        self.isPublic = isPublic
        self.classification = classification
        self.isDownloadedFromPublic = isDownloadedFromPublic
        self.trainingType = trainingType
    }

    // MARK: - Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(rounds, forKey: .rounds)
        try container.encode(creatorNickname, forKey: .creatorNickname)
        try container.encode(creationDate, forKey: .creationDate)
        try container.encode(isPublic, forKey: .isPublic)
        try container.encode(classification, forKey: .classification)
        try container.encode(isDownloadedFromPublic, forKey: .isDownloadedFromPublic)
        try container.encode(trainingType, forKey: .trainingType)
    }

    static func loadAll() -> [SavedTraining] {
        guard let data = UserDefaults.standard.data(forKey: "savedTrainings") else {
            print("❌ No saved data found in UserDefaults.")
            return []
        }

        do {
            let decoded = try JSONDecoder().decode([SavedTraining].self, from: data)
            print("✅ Successfully decoded \(decoded.count) trainings.")
            return decoded
        } catch {
            print("❌ Failed to decode trainings: \(error)")
            return []
        }
    }

    static func saveAll(_ trainings: [SavedTraining]) {
        if let encoded = try? JSONEncoder().encode(trainings) {
            UserDefaults.standard.set(encoded, forKey: "savedTrainings")
        }
    }

    static func == (lhs: SavedTraining, rhs: SavedTraining) -> Bool {
        lhs.id == rhs.id
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, rounds, creatorNickname, creationDate,
             isPublic, classification, isDownloadedFromPublic, trainingType
    }
}
