//
//  FaceTrackingObservation.swift
//  Facework
//

import CoreGraphics
import Foundation
import simd

enum FaceTrackingObservationState: String, Equatable, Sendable {
    case tracking
    case noFace
    case multipleFaces
}

struct FaceTrackingObservation: Sendable {
    let sourceTimestamp: TimeInterval
    let rawBlendshapes: [String: Double]
    let faceTransform: simd_float4x4?
    let headPose: HeadPose?
    let faceIsPresent: Bool
    let visibleFaceCount: Int
    let trackingState: FaceTrackingObservationState
    let faceCenter: CGPoint
    let faceScale: Double
}

struct FaceTrackingSnapshotInput: Sendable {
    let sourceTimestamp: TimeInterval
    let rawBlendshapes: [String: Double]
    let faceTransform: simd_float4x4?
    let faceIsPresent: Bool
    let visibleFaceCount: Int
    let trackingState: FaceTrackingObservationState
    let faceCenter: CGPoint
    let faceScale: Double
}

enum FaceTrackingObservationBuilder {
    nonisolated static func make(from input: FaceTrackingSnapshotInput) -> FaceTrackingObservation {
        FaceTrackingObservation(
            sourceTimestamp: input.sourceTimestamp,
            rawBlendshapes: input.rawBlendshapes,
            faceTransform: input.faceTransform,
            headPose: input.faceTransform.map(poseFromTransform),
            faceIsPresent: input.faceIsPresent,
            visibleFaceCount: input.visibleFaceCount,
            trackingState: input.trackingState,
            faceCenter: input.faceCenter,
            faceScale: input.faceScale
        )
    }

    nonisolated static func poseFromTransform(_ transform: simd_float4x4) -> HeadPose {
        let yawRadians = Double(atan2(transform.columns.0.z, transform.columns.0.x))
        let pitchRadians = Double(asin(-transform.columns.0.y))
        let rollRadians = Double(atan2(transform.columns.1.x, transform.columns.1.y))
        let radiansToDegrees = 180.0 / Double.pi

        return HeadPose(
            yawDegrees: yawRadians * radiansToDegrees,
            pitchDegrees: pitchRadians * radiansToDegrees,
            rollDegrees: rollRadians * radiansToDegrees
        )
    }
}

enum FaceTrackingCallbackEvent: Sendable {
    case faceUpdate(FaceTrackingSnapshotInput)
    case noFaceUpdate(sourceTimestamp: TimeInterval)
    case multipleFaceUpdate(sourceTimestamp: TimeInterval, updatedFaceAnchorCount: Int)
    case faceRemoved(sourceTimestamp: TimeInterval)
}

enum FaceTrackingEventProcessor {
    nonisolated static func observation(
        for event: FaceTrackingCallbackEvent
    ) -> FaceTrackingObservation {
        let input: FaceTrackingSnapshotInput

        switch event {
        case .faceUpdate(let update):
            input = update
        case .noFaceUpdate(let sourceTimestamp):
            input = unavailableInput(timestamp: sourceTimestamp, state: .noFace, faceCount: 0)
        case .multipleFaceUpdate(let sourceTimestamp, let updatedFaceAnchorCount):
            input = unavailableInput(
                timestamp: sourceTimestamp,
                state: .multipleFaces,
                faceCount: updatedFaceAnchorCount
            )
        case .faceRemoved(let sourceTimestamp):
            input = unavailableInput(timestamp: sourceTimestamp, state: .noFace, faceCount: 0)
        }

        return FaceTrackingObservationBuilder.make(from: input)
    }

    nonisolated private static func unavailableInput(
        timestamp: TimeInterval,
        state: FaceTrackingObservationState,
        faceCount: Int
    ) -> FaceTrackingSnapshotInput {
        FaceTrackingSnapshotInput(
            sourceTimestamp: timestamp,
            rawBlendshapes: [:],
            faceTransform: nil,
            faceIsPresent: false,
            visibleFaceCount: faceCount,
            trackingState: state,
            faceCenter: .zero,
            faceScale: 0
        )
    }
}
