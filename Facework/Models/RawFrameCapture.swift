//
//  RawFrameCapture.swift
//  Facework
//

import CoreGraphics
import Foundation
import simd

struct FaceTransformSnapshot: Codable, Equatable, Sendable {
    struct Column: Codable, Equatable, Sendable {
        let x: Float
        let y: Float
        let z: Float
        let w: Float

        nonisolated init(_ value: SIMD4<Float>) {
            x = value.x
            y = value.y
            z = value.z
            w = value.w
        }

        nonisolated var simdValue: SIMD4<Float> { SIMD4(x, y, z, w) }
    }

    let column0: Column
    let column1: Column
    let column2: Column
    let column3: Column

    nonisolated init(_ transform: simd_float4x4) {
        column0 = Column(transform.columns.0)
        column1 = Column(transform.columns.1)
        column2 = Column(transform.columns.2)
        column3 = Column(transform.columns.3)
    }

    nonisolated var matrix: simd_float4x4 {
        simd_float4x4(columns: (
            column0.simdValue,
            column1.simdValue,
            column2.simdValue,
            column3.simdValue
        ))
    }
}

/// Immutable accepted acquisition values and capture context. It contains no
/// baseline-corrected, smoothed, or quality-control conclusions.
struct RawFrameCapture: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let recordingID: UUID?
    let frameIndex: Int
    let sourceTimestamp: TimeInterval
    let taskType: TaskType
    let repetitionIndex: Int
    let rawBlendshapes: [String: Double]
    let faceTransform: FaceTransformSnapshot?
    let headPose: HeadPose?
    let faceIsPresent: Bool?
    let visibleFaceCount: Int?
    let faceTrackingState: FaceTrackingObservationState?
    let faceCenter: CGPoint?
    let faceScale: Double?

    /// Camera/session status is sampled separately from the atomic face-anchor observation.
    let cameraTrackingStateAtCapture: String
    let isNeutralPhase: Bool?

    /// Associated artifact only; it does not guarantee exact image/observation synchronization.
    let validationImageReference: String?

    init(
        id: UUID,
        recordingID: UUID?,
        frameIndex: Int,
        sourceTimestamp: TimeInterval,
        taskType: TaskType,
        repetitionIndex: Int,
        rawBlendshapes: [String: Double],
        faceTransform: FaceTransformSnapshot?,
        headPose: HeadPose?,
        faceIsPresent: Bool?,
        visibleFaceCount: Int?,
        faceTrackingState: FaceTrackingObservationState?,
        faceCenter: CGPoint?,
        faceScale: Double?,
        cameraTrackingStateAtCapture: String,
        isNeutralPhase: Bool?,
        validationImageReference: String?
    ) {
        self.id = id
        self.recordingID = recordingID
        self.frameIndex = frameIndex
        self.sourceTimestamp = sourceTimestamp
        self.taskType = taskType
        self.repetitionIndex = repetitionIndex
        self.rawBlendshapes = rawBlendshapes
        self.faceTransform = faceTransform
        self.headPose = headPose
        self.faceIsPresent = faceIsPresent
        self.visibleFaceCount = visibleFaceCount
        self.faceTrackingState = faceTrackingState
        self.faceCenter = faceCenter
        self.faceScale = faceScale
        self.cameraTrackingStateAtCapture = cameraTrackingStateAtCapture
        self.isNeutralPhase = isNeutralPhase
        self.validationImageReference = validationImageReference
    }

    init(
        collectedObservation: CollectedFaceObservation,
        frameIndex: Int,
        isNeutralPhase: Bool,
        validationImageReference: String?
    ) {
        let observation = collectedObservation.observation
        let taskType: TaskType
        let repetitionIndex: Int

        switch collectedObservation.mode {
        case .neutral:
            taskType = .neutralRest
            repetitionIndex = 1
        case .task(let task, let repetition):
            taskType = task
            repetitionIndex = repetition
        }

        self.init(
            id: UUID(),
            recordingID: collectedObservation.recordingID,
            frameIndex: frameIndex,
            sourceTimestamp: observation.sourceTimestamp,
            taskType: taskType,
            repetitionIndex: repetitionIndex,
            rawBlendshapes: observation.rawBlendshapes,
            faceTransform: observation.faceTransform.map(FaceTransformSnapshot.init),
            headPose: observation.headPose,
            faceIsPresent: observation.faceIsPresent,
            visibleFaceCount: observation.visibleFaceCount,
            faceTrackingState: observation.trackingState,
            faceCenter: observation.faceCenter,
            faceScale: observation.faceScale,
            cameraTrackingStateAtCapture: collectedObservation.cameraTrackingState,
            isNeutralPhase: isNeutralPhase,
            validationImageReference: validationImageReference
        )
    }
}
