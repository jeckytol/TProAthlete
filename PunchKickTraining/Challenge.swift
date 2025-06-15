//
//  Challenge.swift
//  TProAthlete
//
//  Created by Jecky Toledo on 04/06/2025.
//

import Foundation

struct Challenge: Identifiable, Codable, Equatable {
    let id: String
    let challengeName: String
    let trainingName: String
    let startTime: Date
    let difficulty: Int
    let comment: String
    let creatorNickname: String
    var registeredNicknames: [String]
    
    var runId: String?
}
extension Challenge: Hashable {
    static func == (lhs: Challenge, rhs: Challenge) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
