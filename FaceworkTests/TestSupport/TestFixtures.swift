import Foundation
import XCTest
@testable import Facework

enum TestFixtures {
    static let safeText = "synthetic-note"
    static let commaText = "synthetic, note"
    static let quoteText = "synthetic \"quoted\" note"
    static let multilineText = "synthetic\nnote"

    static func frame(
        index: Int = 0,
        timestamp: TimeInterval = 0,
        task: TaskType = .neutralRest,
        repetition: Int = 1,
        raw: [String: Double] = [:],
        normalized: [String: Double]? = nil,
        smoothed: [String: Double]? = nil,
        pose: HeadPose = HeadPose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0),
        trackingState: String = "Tracking",
        flags: [QCFlag] = [],
        valid: Bool = true,
        imageReference: String? = nil
    ) -> FrameCapture {
        FrameCapture(
            id: deterministicUUID(index),
            frameIndex: index,
            timestamp: timestamp,
            taskType: task,
            repetitionIndex: repetition,
            rawBlendshapes: raw,
            normalizedBlendshapes: normalized ?? raw,
            smoothedBlendshapes: smoothed ?? normalized ?? raw,
            headPose: pose,
            trackingState: trackingState,
            qcFlags: flags,
            isValidFrame: valid,
            imageReference: imageReference,
            meshVertices: nil
        )
    }

    static func neutralFrames(values: [Double], valid: Bool = true) -> [FrameCapture] {
        values.enumerated().map {
            frame(index: $0.offset, timestamp: Double($0.offset) * 0.1,
                  raw: ["mouthSmileLeft": $0.element], valid: valid)
        }
    }

    static func movementFrames(
        task: TaskType = .smileClosed,
        left: [Double],
        right: [Double]? = nil,
        timestamps: [TimeInterval]? = nil,
        invalidIndices: Set<Int> = []
    ) -> [FrameCapture] {
        let times = timestamps ?? left.indices.map { Double($0) * 0.1 }
        return left.indices.map { index in
            var values = ["mouthSmileLeft": left[index]]
            if let right, right.indices.contains(index) {
                values["mouthSmileRight"] = right[index]
            }
            return frame(index: index, timestamp: times[index], task: task,
                         raw: values, normalized: values,
                         valid: !invalidIndices.contains(index))
        }
    }

    static func noisyMovementFrames() -> [FrameCapture] {
        movementFrames(left: [0, 0.3, 0.1, 0.8, 0.2, 0.9],
                       right: [0, 0.2, 0.15, 0.7, 0.25, 0.85])
    }

    static func asymmetricMovementFrames() -> [FrameCapture] {
        movementFrames(left: [0, 0.4, 0.8], right: [0, 0.2, 0.4])
    }

    static func timestampGapFrames() -> [FrameCapture] {
        movementFrames(left: [0, 0.4, 0.8], right: [0, 0.4, 0.8],
                       timestamps: [0, 0.1, 0.4])
    }

    static func invalidTrackingFrames() -> [FrameCapture] {
        (0..<4).map {
            frame(index: $0, timestamp: Double($0) * 0.1, task: .smileClosed,
                  raw: ["mouthSmileLeft": 0.5], trackingState: "limited",
                  flags: [.trackingLost], valid: false)
        }
    }

    static func invalidFramingFrames() -> [FrameCapture] {
        (0..<4).map {
            frame(index: $0, timestamp: Double($0) * 0.1, task: .smileClosed,
                  raw: ["mouthSmileLeft": 0.5], flags: [.poorFraming], valid: false)
        }
    }

    static func excessivePoseFrames() -> [FrameCapture] {
        (0..<4).map {
            frame(index: $0, timestamp: Double($0) * 0.1, task: .smileClosed,
                  raw: ["mouthSmileLeft": 0.5],
                  pose: HeadPose(yawDegrees: 13, pitchDegrees: 0, rollDegrees: 0),
                  flags: [.poseOutOfRange], valid: false)
        }
    }

    static func repetition(
        index: Int,
        task: TaskType = .smileClosed,
        valid: Bool = true,
        amplitudeLeft: Double? = 1,
        amplitudeRight: Double? = 1,
        peakVelocity: Double? = 1,
        timeToPeak: Double? = 1
    ) -> RepetitionResult {
        let qc = QCSummary(overallPassed: valid,
                           reasons: valid ? [] : [.lowValidFramePercentage],
                           percentFramesPassing: valid ? 1 : 0.5,
                           validForAnalysis: valid)
        let metrics = DerivedMetrics(
            peakAmplitudeLeft: amplitudeLeft,
            peakAmplitudeRight: amplitudeRight,
            peakVelocityLeft: peakVelocity,
            peakVelocityRight: peakVelocity,
            symmetry: 1,
            onsetTimeLeft: 0.1,
            onsetTimeRight: 0.1,
            timeToPeakLeft: timeToPeak,
            timeToPeakRight: timeToPeak,
            meanActiveVelocityLeft: peakVelocity,
            meanActiveVelocityRight: peakVelocity,
            holdStability: 0.1,
            fatigueSlope: nil,
            confidenceScore: valid ? 1 : 0.25
        )
        return RepetitionResult(
            id: deterministicUUID(100 + index),
            repetitionIndex: index,
            taskType: task,
            startTime: Double(index),
            endTime: Double(index) + 1,
            valid: valid,
            partial: !valid,
            failureReason: valid ? nil : "synthetic failure",
            qcSummary: qc,
            derivedMetrics: metrics,
            peakFrameReference: nil,
            peakFrameIndex: nil,
            peakFrameTimestamp: nil,
            peakSignalValue: nil
        )
    }

    static func metadata(notes: String? = safeText, participantID: String = "SYNTHETIC-001") -> SessionMetadata {
        SessionMetadata(
            sessionID: "00000000-0000-0000-0000-000000000001",
            studyID: "SYNTHETIC-STUDY",
            participantID: participantID,
            raterID: "SYNTHETIC-RATER",
            appVersion: "test-version",
            deviceModel: "Synthetic Device",
            osVersion: "Synthetic OS",
            sessionDate: Date(timeIntervalSince1970: 1_700_000_000),
            notes: notes,
            affectedSide: .none,
            sessionLabel: "Synthetic Session",
            appMarketingVersion: "9.8.7",
            appBuildNumber: "654",
            rawDataSchemaVersion: "test-schema",
            analysisAlgorithmVersion: "test-analysis",
            captureProtocolVersion: "test-protocol",
            meshCaptureVersion: "not-active",
            landmarkConfigurationVersion: "not-active",
            deviceModelIdentifier: "SyntheticDevice1,1",
            operatingSystemName: "SyntheticOS",
            operatingSystemVersion: "99.1"
        )
    }

    static func summary(metadata: SessionMetadata = metadata()) -> SessionSummary {
        SessionSummary(
            sessionMetadata: metadata,
            taskSummaries: [],
            exportPaths: [],
            overallQC: QCSummary(overallPassed: true, reasons: [],
                                 percentFramesPassing: 1, validForAnalysis: true)
        )
    }

    static func deterministicUUID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}

final class TemporaryDirectory {
    let url: URL

    init(testName: String = UUID().uuidString) throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FaceworkTests-\(testName)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

extension XCTestCase {
    func assertOptionalEqual(
        _ expression1: Double?,
        _ expression2: Double?,
        accuracy: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let first = expression1, let second = expression2 else {
            XCTFail("Expected two non-nil Double values", file: file, line: line)
            return
        }
        XCTAssertEqual(first, second, accuracy: accuracy, file: file, line: line)
    }
}
