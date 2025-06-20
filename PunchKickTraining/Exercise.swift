import Foundation
import FirebaseFirestoreSwift

// MARK: - Enum Definitions

enum Stance: String, Codable, CaseIterable, Identifiable {
    case front, back, lateral
    var id: String { rawValue }
}

enum Complexity: String, Codable, CaseIterable, Identifiable {
    case easy, medium, hard
    var id: String { rawValue }
}

// MARK: - Exercise Model

struct Exercise: Identifiable, Codable, Equatable {
    @DocumentID var id: String?            // Firestore will manage this unless manually specified
    var name: String
    var imageUrl: String
    var description: String
    var videoUrl: String
    var stance: Stance
    var pointsFactor: Double = 1.0
    var complexity: Complexity
    var sensitivity: Double = 1.30
    var cooldown: Double = 0.30
    var minMotionDuration: Double = 0.20
    var createdAt: Date = Date()           // Timestamp for sorting/filtering

    // Custom initializer (optional, for manual creation)
    init(
        id: String? = nil,
        name: String,
        imageUrl: String,
        description: String,
        videoUrl: String,
        stance: Stance,
        pointsFactor: Double = 1.0,
        complexity: Complexity,
        sensitivity: Double = 1.30,
        cooldown: Double = 0.30,
        minMotionDuration: Double = 0.20,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.imageUrl = imageUrl
        self.description = description
        self.videoUrl = videoUrl
        self.stance = stance
        self.pointsFactor = pointsFactor
        self.complexity = complexity
        self.sensitivity = sensitivity
        self.cooldown = cooldown
        self.minMotionDuration = minMotionDuration
        self.createdAt = createdAt
    }
}
