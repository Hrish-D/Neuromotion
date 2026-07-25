//
//  RepetitionAnalyzer.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct RepetitionAnalyzer {
    private let featureEngine = FeatureExtractionEngine()

    func analyze(task: TaskType,
                 repetitionIndex: Int,
                 frames: [FrameCapture],
                 config: TaskConfiguration,
                 peakFrameReference: String?,
                 peakFrameIndex: Int? = nil,
                 peakFrameTimestamp: TimeInterval? = nil,
                 peakSignalValue: Double? = nil) -> RepetitionResult {
        let qcSummary = summary(for: frames)
        let metrics = featureEngine.deriveMetrics(for: task, frames: frames, config: config, qcSummary: qcSummary)
        return RepetitionResult(
            id: UUID(),
            repetitionIndex: repetitionIndex,
            taskType: task,
            startTime: frames.first?.timestamp ?? 0,
            endTime: frames.last?.timestamp ?? 0,
            valid: qcSummary.validForAnalysis,
            partial: !qcSummary.validForAnalysis && qcSummary.percentFramesPassing > 0.4,
            failureReason: qcSummary.validForAnalysis ? nil : qcSummary.reasons.map(\.rawValue).joined(separator: ", "),
            qcSummary: qcSummary,
            derivedMetrics: metrics,
            peakFrameReference: peakFrameReference,
            peakFrameIndex: peakFrameIndex,
            peakFrameTimestamp: peakFrameTimestamp,
            peakSignalValue: peakSignalValue
        )
    }

    private func summary(for frames: [FrameCapture]) -> QCSummary {
        guard !frames.isEmpty else {
            return QCSummary(overallPassed: false, reasons: [.notEnoughFrames], percentFramesPassing: 0, validForAnalysis: false)
        }
        let validCount = frames.filter(\.isValidFrame).count
        let percentage = Double(validCount) / Double(frames.count)
        let reasons = Array(Set(frames.flatMap(\.qcFlags)))
        let passed = percentage >= AppConfiguration.shared.minimumValidFramePercentage && !reasons.contains(.trackingLost)
        return QCSummary(overallPassed: passed,
                         reasons: passed ? [] : (reasons.isEmpty ? [.lowValidFramePercentage] : reasons),
                         percentFramesPassing: percentage,
                         validForAnalysis: passed)
    }
}
