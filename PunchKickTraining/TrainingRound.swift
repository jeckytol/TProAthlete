import Foundation

struct TrainingRound: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String

    // Strength Driven
    var goalForce: Double? = nil
    var goalStrikes: Int? = nil
    var cutoffTime: Int? = nil  // Applies only to Strength Driven

    // Time Driven
    var roundTime: Int? = nil   // ⏱️ Duration in seconds for Time Driven mode

    // Shared
    var restTime: Int = 0

    init(
        id: UUID = UUID(),
        name: String,
        goalForce: Double? = nil,
        goalStrikes: Int? = nil,
        cutoffTime: Int? = nil,
        roundTime: Int? = nil,
        restTime: Int = 0
    ) {
        self.id = id
        self.name = name
        self.goalForce = goalForce
        self.goalStrikes = goalStrikes
        self.cutoffTime = cutoffTime
        self.roundTime = roundTime
        self.restTime = restTime
    }
}
