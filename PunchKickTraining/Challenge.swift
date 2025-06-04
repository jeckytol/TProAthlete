//
//  Challenge.swift
//  TProAthlete
//
//  Created by Jecky Toledo on 04/06/2025.
//

import Foundation

struct Challenge: Identifiable, Codable, Equatable {
    let id: String
    let trainingName: String
    let startTime: Date
    let difficulty: Int
    let comment: String
    let creatorNickname: String
    var registeredNicknames: [String]
}
