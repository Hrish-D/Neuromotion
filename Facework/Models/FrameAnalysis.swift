//
//  FrameAnalysis.swift
//  Facework
//

import Foundation

/// Values produced by the current baseline, preprocessing, and QC path.
struct FrameAnalysis: Codable, Equatable, Sendable {
    let normalizedBlendshapes: [String: Double]
    let smoothedBlendshapes: [String: Double]
    let qcFlags: [QCFlag]
    let isValidFrame: Bool
}
