//
//  MetricUpdate.swift
//  TProAthlete
//
//  Created by Jecky Toledo on 24/05/2025.
//

import Foundation

struct MetricUpdate: Codable {
    let totalStrikes: Int
    let totalForce: Double
    let maxForce: Double
    let averageForce: Double
    let timestamp: TimeInterval
}
