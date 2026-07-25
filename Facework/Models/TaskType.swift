//
//  TaskType.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

enum TaskType: String, Codable, CaseIterable, Identifiable, Hashable {
    case neutralRest
    case browRaise
    case eyeClosure
    case smileTeeth
    case smileClosed
    case lipPucker
    case cheekPuff

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neutralRest: return "Neutral Rest"
        case .browRaise: return "Brow Raise"
        case .eyeClosure: return "Eye Closure"
        case .smileTeeth: return "Smile Showing Teeth"
        case .smileClosed: return "Smile Lips Closed"
        case .lipPucker: return "Lip Pucker"
        case .cheekPuff: return "Cheek Puff"
        }
    }

    var instruction: String {
        instructionText
    }

    var instructionText: String {
        switch self {
        case .neutralRest: return "Relax your face and look straight ahead."
        case .browRaise: return "Raise both eyebrows and hold."
        case .eyeClosure: return "Close both eyes gently and hold."
        case .smileTeeth: return "Smile widely while showing your teeth."
        case .smileClosed: return "Smile with your lips closed."
        case .lipPucker: return "Pucker your lips forward and hold."
        case .cheekPuff: return "Puff both cheeks and hold."
        }
    }
}
