//
//  HeadPose.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct HeadPose: Codable, Equatable, Sendable {
    let yawDegrees: Double
    let pitchDegrees: Double
    let rollDegrees: Double
}
