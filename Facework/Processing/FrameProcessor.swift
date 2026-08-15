//
//  FrameProcessor.swift
//  Facework
//

import CoreGraphics
import Foundation

/// Applies the current frame-level calculations without mutating the raw record.
struct FrameProcessor {
    private let calibrator = BaselineCalibrator()
    private let qcEngine = QualityControlEngine()

    func process(
        raw: RawFrameCapture,
        baseline: [String: Double],
        previous: FrameCapture?
    ) -> FrameCapture {
        let normalized = calibrator.normalize(raw: raw.rawBlendshapes, baseline: baseline)
        let pose = raw.headPose ?? HeadPose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0)
        let context = QualityControlContext(
            faceCount: raw.visibleFaceCount ?? 0,
            trackingState: raw.cameraTrackingStateAtCapture,
            faceCenter: raw.faceCenter ?? .zero,
            faceScale: raw.faceScale ?? 0,
            pose: pose,
            rawBlendshapes: raw.rawBlendshapes,
            timestamp: raw.sourceTimestamp,
            isNeutralPhase: raw.isNeutralPhase ?? false
        )
        let evaluation = qcEngine.evaluate(current: context, previous: previous)

        return FrameCapture(
            raw: raw,
            analysis: FrameAnalysis(
                normalizedBlendshapes: normalized,
                // Preserves the existing capture-time compatibility semantics.
                smoothedBlendshapes: normalized,
                qcFlags: evaluation.flags,
                isValidFrame: evaluation.valid
            )
        )
    }
}
