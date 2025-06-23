import Foundation

struct TrainingRound: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var goalForce: Double
    var cutoffTime: Int?
}
