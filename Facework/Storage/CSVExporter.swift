//
//  CSVExporter.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct CSVExporter {

    func exportFrames(
        _ frames: [FrameCapture],
        metadata: SessionMetadata? = nil,
        to url: URL
    ) throws {
        var lines: [String] = []

        let blendshapeKeys = Array(
            Set(
                frames.flatMap { frame in
                    Array(frame.rawBlendshapes.keys) +
                    Array(frame.normalizedBlendshapes.keys) +
                    Array(frame.smoothedBlendshapes.keys)
                }
            )
        ).sorted()

        var header: [String] = [
            "timestamp",
            "frameIndex",
            "task",
            "repetition",
            "trackingState",
            "isValidFrame",
            "qcFlags",
            "imageReference",
            "yawDegrees",
            "pitchDegrees",
            "rollDegrees"
        ]

        header += blendshapeKeys.map { "raw_\($0)" }
        header += blendshapeKeys.map { "normalized_\($0)" }
        header += blendshapeKeys.map { "smoothed_\($0)" }
        header += identityHeaders

        lines.append(header.map { escape($0) }.joined(separator: ","))

        for frame in frames {
            let qcFlags = frame.qcFlags.map { $0.rawValue }.joined(separator: "|")

            var row: [String] = [
                String(frame.timestamp),
                String(frame.frameIndex),
                frame.taskType.rawValue,
                String(frame.repetitionIndex),
                frame.trackingState,
                String(frame.isValidFrame),
                qcFlags,
                frame.imageReference ?? "",
                format(frame.headPose.yawDegrees),
                format(frame.headPose.pitchDegrees),
                format(frame.headPose.rollDegrees)
            ]

            row += blendshapeKeys.map { key in
                format(frame.rawBlendshapes[key])
            }

            row += blendshapeKeys.map { key in
                format(frame.normalizedBlendshapes[key])
            }

            row += blendshapeKeys.map { key in
                format(frame.smoothedBlendshapes[key])
            }
            row += identityValues(metadata)

            lines.append(row.map { escape($0) }.joined(separator: ","))
        }

        try writeCSV(lines, to: url)
    }
    
    func exportImageManifest(
        _ frames: [FrameCapture],
        metadata: SessionMetadata? = nil,
        to url: URL
    ) throws {
        var lines: [String] = []

        let header: [String] = [
            "task",
            "repetition",
            "frameIndex",
            "timestamp",
            "isValidFrame",
            "imageFileName",
            "imageReference"
        ]

        lines.append((header + identityHeaders).map { escape($0) }.joined(separator: ","))

        let imageFrames = frames.filter { frame in
            guard let imageReference = frame.imageReference else { return false }
            return !imageReference.isEmpty
        }

        for frame in imageFrames {
            let imageReference = frame.imageReference ?? ""
            let imageFileName = URL(fileURLWithPath: imageReference).lastPathComponent

            var row: [String] = [
                frame.taskType.rawValue,
                String(frame.repetitionIndex),
                String(frame.frameIndex),
                String(frame.timestamp),
                String(frame.isValidFrame),
                imageFileName,
                imageReference
            ]
            row += identityValues(metadata)

            lines.append(row.map { escape($0) }.joined(separator: ","))
        }

        try writeCSV(lines, to: url)
    }

    func exportRepetitions(
        _ repetitions: [RepetitionResult],
        metadata: SessionMetadata? = nil,
        to url: URL
    ) throws {
        var lines: [String] = []

        let header: [String] = [
            "task",
            "repetition",
            "valid",
            "partial",
            "failureReason",
            "startTime",
            "endTime",
            "peakAmplitudeLeft",
            "peakAmplitudeRight",
            "peakVelocityLeft",
            "peakVelocityRight",
            "symmetry",
            "confidenceScore",
            "peakFrameReference",
            "peakFrameIndex",
            "peakFrameTimestamp",
            "peakSignalValue"
        ]

        lines.append((header + identityHeaders).map { escape($0) }.joined(separator: ","))

        for rep in repetitions {
            let metrics = rep.derivedMetrics

            var row: [String] = [
                rep.taskType.rawValue,
                String(rep.repetitionIndex),
                String(rep.valid),
                String(rep.partial),
                rep.failureReason ?? "",
                String(rep.startTime),
                String(rep.endTime),
                format(metrics.peakAmplitudeLeft),
                format(metrics.peakAmplitudeRight),
                format(metrics.peakVelocityLeft),
                format(metrics.peakVelocityRight),
                format(metrics.symmetry),
                format(metrics.confidenceScore),
                rep.peakFrameReference ?? "",
                rep.peakFrameIndex.map(String.init) ?? "",
                format(rep.peakFrameTimestamp),
                format(rep.peakSignalValue)
            ]
            row += identityValues(metadata)

            lines.append(row.map { escape($0) }.joined(separator: ","))
        }

        try writeCSV(lines, to: url)
    }

    private func writeCSV(_ lines: [String], to url: URL) throws {
        let csvText = lines.joined(separator: "\n")
        try csvText.write(to: url, atomically: true, encoding: .utf8)
    }

    private var identityHeaders: [String] {
        [
            "sessionID",
            "rawDataSchemaVersion",
            "analysisAlgorithmVersion",
            "captureProtocolVersion"
        ]
    }

    private func identityValues(_ metadata: SessionMetadata?) -> [String] {
        [
            metadata?.sessionID ?? "",
            metadata?.rawDataSchemaVersion ?? "",
            metadata?.analysisAlgorithmVersion ?? "",
            metadata?.captureProtocolVersion ?? ""
        ]
    }

    private func format(_ value: Double) -> String {
        String(format: "%.6f", value)
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.6f", value)
    }

    private func escape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")

        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }

        return escaped
    }
}
