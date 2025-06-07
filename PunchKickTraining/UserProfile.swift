//
//  UserProfile.swift
//  TProAthlete
//
//  Created by Jecky Toledo on 10/05/2025.
//


import Foundation
import FirebaseFirestoreSwift

struct UserProfile: Codable, Identifiable, Equatable {
    var id: String
    var userId: String
    var nickname: String
    var age: Int
    var athleteType: String
    var createdAt: Date
    var avatarName: String?
}
