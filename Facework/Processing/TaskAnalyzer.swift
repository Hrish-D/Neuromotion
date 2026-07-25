//
//  TaskAnalyzer.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct TaskAnalyzer {
    func summarize(task: TaskType, repetitions: [RepetitionResult]) -> TaskSummary {
        let valid = repetitions.filter(\.valid)
        let invalid = repetitions.filter { !$0.valid }

        let amplitudes = valid.compactMap { [$0.derivedMetrics.peakAmplitudeLeft, $0.derivedMetrics.peakAmplitudeRight].compactMap { $0 }.max() }
        let peakVelocities = valid.compactMap { [$0.derivedMetrics.peakVelocityLeft, $0.derivedMetrics.peakVelocityRight].compactMap { $0 }.max() }
        let timesToPeak = valid.compactMap { [$0.derivedMetrics.timeToPeakLeft, $0.derivedMetrics.timeToPeakRight].compactMap { $0 }.max() }

        let averageMetrics = DerivedMetrics(
            peakAmplitudeLeft: average(valid.compactMap { $0.derivedMetrics.peakAmplitudeLeft }),
            peakAmplitudeRight: average(valid.compactMap { $0.derivedMetrics.peakAmplitudeRight }),
            peakVelocityLeft: average(valid.compactMap { $0.derivedMetrics.peakVelocityLeft }),
            peakVelocityRight: average(valid.compactMap { $0.derivedMetrics.peakVelocityRight }),
            symmetry: average(valid.compactMap { $0.derivedMetrics.symmetry }),
            onsetTimeLeft: average(valid.compactMap { $0.derivedMetrics.onsetTimeLeft }),
            onsetTimeRight: average(valid.compactMap { $0.derivedMetrics.onsetTimeRight }),
            timeToPeakLeft: average(valid.compactMap { $0.derivedMetrics.timeToPeakLeft }),
            timeToPeakRight: average(valid.compactMap { $0.derivedMetrics.timeToPeakRight }),
            meanActiveVelocityLeft: average(valid.compactMap { $0.derivedMetrics.meanActiveVelocityLeft }),
            meanActiveVelocityRight: average(valid.compactMap { $0.derivedMetrics.meanActiveVelocityRight }),
            holdStability: average(valid.compactMap { $0.derivedMetrics.holdStability }),
            fatigueSlope: TimeSeriesUtils.linearSlope(x: Array(0..<amplitudes.count).map(Double.init), y: amplitudes),
            confidenceScore: average(valid.compactMap { $0.derivedMetrics.confidenceScore })
        )

        let repeatability: [String: Double] = [
            "amplitudeCV": TimeSeriesUtils.coefficientOfVariation(amplitudes),
            "timeToPeakCV": TimeSeriesUtils.coefficientOfVariation(timesToPeak),
            "peakVelocityCV": TimeSeriesUtils.coefficientOfVariation(peakVelocities),
            "fatigueAmplitudeSlope": TimeSeriesUtils.linearSlope(x: Array(0..<amplitudes.count).map(Double.init), y: amplitudes),
            "fatigueVelocitySlope": TimeSeriesUtils.linearSlope(x: Array(0..<peakVelocities.count).map(Double.init), y: peakVelocities)
        ]

        return TaskSummary(taskType: task,
                           validRepetitionCount: valid.count,
                           invalidRepetitionCount: invalid.count,
                           averageMetrics: averageMetrics,
                           repeatabilityMetrics: repeatability)
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
