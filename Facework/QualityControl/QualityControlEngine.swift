//
//  QualityControlEngine.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation
import CoreGraphics

struct QualityControlContext {
    let faceCount: Int
    let trackingState: String
    let faceCenter: CGPoint
    let faceScale: Double
    let pose: HeadPose
    let rawBlendshapes: [String: Double]
    let timestamp: TimeInterval
    let isNeutralPhase: Bool
}

struct QualityControlEngine {
    private let poseValidator = PoseValidator()
    private let framingValidator = FramingValidator()
    private let trackingValidator = TrackingValidator()
    private let plausibilityValidator = SignalPlausibilityValidator()

    func evaluate(current: QualityControlContext, previous: FrameCapture?) -> (flags: [QCFlag], valid: Bool) {
        var flags: [QCFlag] = []
        flags.append(contentsOf: trackingValidator.validate(faceCount: current.faceCount, trackingDescription: current.trackingState))
        flags.append(contentsOf: framingValidator.validate(center: current.faceCenter, scale: current.faceScale))
        flags.append(contentsOf: poseValidator.validate(current.pose))
        flags.append(contentsOf: plausibilityValidator.validate(previous: previous, currentRaw: current.rawBlendshapes, timestamp: current.timestamp))

        if current.isNeutralPhase {
            let activation = current.rawBlendshapes.values.max() ?? 0
            if activation > AppConfiguration.shared.neutralMaxBlendshapeActivation {
                flags.append(.facialActivationTooHighAtNeutral)
            }
        }

        let likelyOccluded = current.faceScale < AppConfiguration.shared.faceScaleMin * 0.8
        if likelyOccluded {
            flags.append(.likelyOcclusion)
        }

        return (Array(Set(flags)), flags.isEmpty)
    }
}
