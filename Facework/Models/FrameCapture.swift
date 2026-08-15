//
//  FrameCapture.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct FrameCapture: Codable, Equatable, Identifiable {
    let raw: RawFrameCapture
    let analysis: FrameAnalysis
    let meshVertices:[[Float]]?

    var id: UUID { raw.id }
    var frameIndex: Int { raw.frameIndex }
    var timestamp: TimeInterval { raw.sourceTimestamp }
    var taskType: TaskType { raw.taskType }
    var repetitionIndex: Int { raw.repetitionIndex }
    var rawBlendshapes: [String: Double] { raw.rawBlendshapes }
    var normalizedBlendshapes: [String: Double] { analysis.normalizedBlendshapes }
    var smoothedBlendshapes: [String: Double] { analysis.smoothedBlendshapes }
    var headPose: HeadPose { raw.headPose ?? HeadPose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0) }
    var trackingState: String { raw.cameraTrackingStateAtCapture }
    var qcFlags: [QCFlag] { analysis.qcFlags }
    var isValidFrame: Bool { analysis.isValidFrame }
    var imageReference: String? { raw.validationImageReference }

    init(raw: RawFrameCapture, analysis: FrameAnalysis, meshVertices: [[Float]]? = nil) {
        self.raw = raw
        self.analysis = analysis
        self.meshVertices = meshVertices
    }

    init(id: UUID, frameIndex: Int, timestamp: TimeInterval, taskType: TaskType,
         repetitionIndex: Int, rawBlendshapes: [String: Double],
         normalizedBlendshapes: [String: Double], smoothedBlendshapes: [String: Double],
         headPose: HeadPose, trackingState: String, qcFlags: [QCFlag],
         isValidFrame: Bool, imageReference: String?, meshVertices: [[Float]]?) {
        raw = RawFrameCapture(
            id: id, recordingID: nil, frameIndex: frameIndex, sourceTimestamp: timestamp,
            taskType: taskType, repetitionIndex: repetitionIndex, rawBlendshapes: rawBlendshapes,
            faceTransform: nil, headPose: headPose, faceIsPresent: nil, visibleFaceCount: nil,
            faceTrackingState: nil, faceCenter: nil, faceScale: nil,
            cameraTrackingStateAtCapture: trackingState, isNeutralPhase: nil,
            validationImageReference: imageReference
        )
        analysis = FrameAnalysis(
            normalizedBlendshapes: normalizedBlendshapes,
            smoothedBlendshapes: smoothedBlendshapes,
            qcFlags: qcFlags,
            isValidFrame: isValidFrame
        )
        self.meshVertices = meshVertices
    }

    private enum CodingKeys: String, CodingKey {
        case id, frameIndex, timestamp, taskType, repetitionIndex
        case rawBlendshapes, normalizedBlendshapes, smoothedBlendshapes
        case headPose, trackingState, qcFlags, isValidFrame, imageReference, meshVertices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            frameIndex: try container.decode(Int.self, forKey: .frameIndex),
            timestamp: try container.decode(TimeInterval.self, forKey: .timestamp),
            taskType: try container.decode(TaskType.self, forKey: .taskType),
            repetitionIndex: try container.decode(Int.self, forKey: .repetitionIndex),
            rawBlendshapes: try container.decode([String: Double].self, forKey: .rawBlendshapes),
            normalizedBlendshapes: try container.decode([String: Double].self, forKey: .normalizedBlendshapes),
            smoothedBlendshapes: try container.decode([String: Double].self, forKey: .smoothedBlendshapes),
            headPose: try container.decode(HeadPose.self, forKey: .headPose),
            trackingState: try container.decode(String.self, forKey: .trackingState),
            qcFlags: try container.decode([QCFlag].self, forKey: .qcFlags),
            isValidFrame: try container.decode(Bool.self, forKey: .isValidFrame),
            imageReference: try container.decodeIfPresent(String.self, forKey: .imageReference),
            meshVertices: try container.decodeIfPresent([[Float]].self, forKey: .meshVertices)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(frameIndex, forKey: .frameIndex)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(taskType, forKey: .taskType)
        try container.encode(repetitionIndex, forKey: .repetitionIndex)
        try container.encode(rawBlendshapes, forKey: .rawBlendshapes)
        try container.encode(normalizedBlendshapes, forKey: .normalizedBlendshapes)
        try container.encode(smoothedBlendshapes, forKey: .smoothedBlendshapes)
        try container.encode(headPose, forKey: .headPose)
        try container.encode(trackingState, forKey: .trackingState)
        try container.encode(qcFlags, forKey: .qcFlags)
        try container.encode(isValidFrame, forKey: .isValidFrame)
        try container.encodeIfPresent(imageReference, forKey: .imageReference)
        try container.encodeIfPresent(meshVertices, forKey: .meshVertices)
    }
}
