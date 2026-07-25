//
//  FrameCapture.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct FrameCapture: Codable, Equatable, Identifiable {
    let id: UUID
    let frameIndex: Int
    let timestamp: TimeInterval
    let taskType: TaskType
    let repetitionIndex: Int
    
    let rawBlendshapes: [String: Double]
    let normalizedBlendshapes: [String: Double]
    let smoothedBlendshapes: [String: Double]
    
    let headPose: HeadPose
    let trackingState: String
    let qcFlags: [QCFlag]
    let isValidFrame: Bool

    // Path to the saved camera image for this exact sampled frame.
    // This is used only for research/validation exports.
    let imageReference: String?

    let meshVertices:[[Float]]?
}
