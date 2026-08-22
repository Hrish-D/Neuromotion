//
//  TaskExecutionViewModel.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation
import SwiftUI
import CoreGraphics
import Combine

final class TaskExecutionViewModel: ObservableObject {
    @Published var currentRepetitionIndex: Int = 1
    @Published var liveQCFlags: [QCFlag] = []
    @Published var liveIsValid: Bool = false
    @Published var countdownText: String = "Ready"
    @Published var debugValues: [String: Double] = [:]
    @Published var normalizedValues: [String: Double] = [:]
    @Published var captureFrames: [FrameCapture] = []
    @Published private(set) var latestCalibrationEvent: NeutralCalibrationEvent?

    private let frameProcessor = FrameProcessor()
    private let analyzer = RepetitionAnalyzer()
    private let peakFrameFinder = PeakFrameFinder()
    private var frameIndex: Int = 0

    var nextFrameIndex: Int { frameIndex }

    func resetForNextRep() {
        liveQCFlags = []
        liveIsValid = false
        countdownText = "Ready"
        debugValues = [:]
        normalizedValues = [:]
        captureFrames = []
        latestCalibrationEvent = nil
        frameIndex = 0
    }

    func receiveCalibrationEvent(_ collectedObservation: CollectedFaceObservation) {
        latestCalibrationEvent = NeutralCalibrationEvent(collectedObservation: collectedObservation)
    }

    func calibrationLiveStatus(phase: NeutralCalibrationPhase) -> NeutralCalibrationLiveStatus {
        NeutralCalibrationLiveStatus.resolve(
            phase: phase,
            latestEvent: latestCalibrationEvent,
            latestFrameIsValid: liveIsValid
        )
    }

    func appendLiveFrame(task: TaskType,
                         repetitionIndex: Int,
                         rawBlendshapes: [String: Double],
                         baseline: [String: Double],
                         pose: HeadPose,
                         trackingState: String,
                         faceCount: Int,
                         faceCenter: CGPoint,
                         faceScale: Double,
                         timestamp: TimeInterval,
                         isNeutralPhase: Bool,
                         imageReference: String? = nil,
                         meshVertices: [[Float]]? = nil) {
        let raw = RawFrameCapture(
            id: UUID(), recordingID: nil, frameIndex: frameIndex, sourceTimestamp: timestamp,
            taskType: task, repetitionIndex: repetitionIndex, rawBlendshapes: rawBlendshapes,
            faceTransform: nil, headPose: pose, faceIsPresent: nil, visibleFaceCount: faceCount,
            faceTrackingState: nil, faceCenter: faceCenter, faceScale: faceScale,
            cameraTrackingStateAtCapture: trackingState, isNeutralPhase: isNeutralPhase,
            validationImageReference: imageReference
        )
        append(raw: raw, baseline: baseline, meshVertices: meshVertices)
    }

    @discardableResult
    func appendLiveFrame(
        collectedObservation: CollectedFaceObservation,
        baseline: [String: Double],
        isNeutralPhase: Bool,
        validationImageAssociation: ValidationImageAssociation? = nil,
        rawCaptureHandler: ((RawFrameCapture, FaceMeshSnapshot?) -> Void)? = nil
    ) -> FrameCapture {
        let raw = RawFrameCapture(
            collectedObservation: collectedObservation,
            frameIndex: frameIndex,
            isNeutralPhase: isNeutralPhase,
            validationImageAssociation: validationImageAssociation
        )
        // Raw mesh materialization precedes all derived processing and QC.
        rawCaptureHandler?(raw, collectedObservation.faceMeshSnapshot)
        return append(raw: raw, baseline: baseline)
    }

    @discardableResult
    private func append(
        raw: RawFrameCapture,
        baseline: [String: Double],
        meshVertices: [[Float]]? = nil
    ) -> FrameCapture {
        let processed = frameProcessor.process(raw: raw, baseline: baseline, previous: captureFrames.last)
        let frame = FrameCapture(raw: processed.raw, analysis: processed.analysis, meshVertices: meshVertices)

        frameIndex += 1
        captureFrames.append(frame)
        liveQCFlags = frame.qcFlags
        liveIsValid = frame.isValidFrame
        debugValues = frame.rawBlendshapes
        normalizedValues = frame.normalizedBlendshapes
        return frame
    }

    func peakFrameCandidate(for task: TaskType) -> PeakFrameCandidate? {
        peakFrameFinder.findPeak(task: task, frames: captureFrames)
    }

    func finalize(task: TaskType,
                  config: TaskConfiguration,
                  peakFrameReference: String? = nil,
                  peakFrameIndex: Int? = nil,
                  peakFrameTimestamp: TimeInterval? = nil,
                  peakSignalValue: Double? = nil) -> RepetitionResult {
        analyzer.analyze(task: task,
                         repetitionIndex: currentRepetitionIndex,
                         frames: captureFrames,
                         config: config,
                         peakFrameReference: peakFrameReference,
                         peakFrameIndex: peakFrameIndex,
                         peakFrameTimestamp: peakFrameTimestamp,
                         peakSignalValue: peakSignalValue)
    }
}
