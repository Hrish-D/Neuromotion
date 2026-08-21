//
//  QCFlag.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

enum QCFlag: String, Codable, CaseIterable, Identifiable, Sendable {
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
    case calibrationUnavailable
    case incompleteProtocol
    case missingRequiredTask
    case insufficientValidRepetitions
    case unknown

    var id: String { rawValue }

    /// Diagnostic flags remain observable but do not, by themselves, make an
    /// acquired frame unusable. All other flags retain their existing hard-QC role.
    var invalidatesFrame: Bool {
        self != .facialActivationTooHighAtNeutral
    }
}
