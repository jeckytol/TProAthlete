import Foundation

struct TrainingRound: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var goalForce: Double
    var cutoffTime: Int?

    // ✅ Manual memberwise initializer
   /* init(name: String, goalForce: Double, cutoffTime: Int?) {
        self.id = UUID()
        self.name = name
        self.goalForce = goalForce
        self.cutoffTime = cutoffTime
    }

    // ✅ Decodable
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        goalForce = try container.decode(Double.self, forKey: .goalForce)
        cutoffTime = try container.decodeIfPresent(Int.self, forKey: .cutoffTime)
    }

    // ✅ Encodable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(goalForce, forKey: .goalForce)
        try container.encodeIfPresent(cutoffTime, forKey: .cutoffTime)
    }

    enum CodingKeys: String, CodingKey {
        case name, goalForce, cutoffTime
    }
    */
}
