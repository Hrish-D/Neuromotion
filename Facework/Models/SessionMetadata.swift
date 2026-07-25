//
//  SessionMetadata.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct SessionMetadata: Codable, Equatable {
    let sessionID: String
    let studyID: String
    let participantID: String
    let raterID: String?
    let appVersion: String
    let deviceModel: String
    let osVersion: String
    let sessionDate: Date
    let notes: String?
    let affectedSide: AffectedSide
    let sessionLabel: String?
}

enum AffectedSide: String, Codable, CaseIterable, Identifiable {
    case left
    case right
    case bilateral
    case none

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}
