//
//  QCFlag.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

enum QCFlag: String, Codable, CaseIterable, Identifiable {
    case trackingLost
    case noFace
    case multipleFaces
    case poorFraming
    case poseOutOfRange
    case headMotionTooHigh
    case facialActivationTooHighAtNeutral
    case likelyOcclusion
    case signalSpike
    case missingBlendshapeValue
    case invalidTimestampGap
    case holdNotMaintained
    case lowValidFramePercentage
    case notEnoughFrames
    case unknown

    var id: String { rawValue }
}
