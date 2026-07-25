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

    private let qcEngine = QualityControlEngine()
    private let calibrator = BaselineCalibrator()
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
        frameIndex = 0
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
        let normalized = calibrator.normalize(raw: rawBlendshapes, baseline: baseline)

        let context = QualityControlContext(faceCount: faceCount,
                                            trackingState: trackingState,
                                            faceCenter: faceCenter,
                                            faceScale: faceScale,
                                            pose: pose,
                                            rawBlendshapes: rawBlendshapes,
                                            timestamp: timestamp,
                                            isNeutralPhase: isNeutralPhase)

        let evaluation = qcEngine.evaluate(current: context, previous: captureFrames.last)

        let frame = FrameCapture(id: UUID(),
                                 frameIndex: frameIndex,
                                 timestamp: timestamp,
                                 taskType: task,
                                 repetitionIndex: repetitionIndex,
                                 rawBlendshapes: rawBlendshapes,
                                 normalizedBlendshapes: normalized,
                                 smoothedBlendshapes: normalized,
                                 headPose: pose,
                                 trackingState: trackingState,
                                 qcFlags: evaluation.flags,
                                 isValidFrame: evaluation.valid,
                                 imageReference: imageReference,
                                 meshVertices: meshVertices)

        frameIndex += 1
        captureFrames.append(frame)

        liveQCFlags = evaluation.flags
        liveIsValid = evaluation.valid
        debugValues = rawBlendshapes
        normalizedValues = normalized
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
