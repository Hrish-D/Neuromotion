//
//  FeatureExtractionEngine.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct FeatureExtractionEngine {
    private let preprocessor = SignalPreprocessor()
    private let velocityCalculator = VelocityCalculator()
    private let symmetryCalculator = SymmetryCalculator()

    func deriveMetrics(for task: TaskType,
                       frames: [FrameCapture],
                       config: TaskConfiguration,
                       qcSummary: QCSummary) -> DerivedMetrics {
        let validFrames = frames.filter(\.isValidFrame)
        guard !validFrames.isEmpty else { return .empty }

        let timestamps = validFrames.map(\.timestamp)
        let bilateralKeys = bilateralMetricKeys(for: task)

        if let signal = preprocessedSignal(frames: validFrames, keys: bilateralKeys), !signal.isEmpty {
            return unilateralMetrics(from: signal,
                                     timestamps: timestamps,
                                     config: config,
                                     qcSummary: qcSummary)
        }

        let leftSignal = preprocessedSignal(frames: validFrames, keys: leftMetricKeys(for: task)) ?? []
        let rightSignal = preprocessedSignal(frames: validFrames, keys: rightMetricKeys(for: task)) ?? []

        guard !leftSignal.isEmpty || !rightSignal.isEmpty else {
            return .empty
        }

        let leftOnset = onsetTime(signal: leftSignal, timestamps: timestamps, threshold: config.onsetThreshold)
        let rightOnset = onsetTime(signal: rightSignal, timestamps: timestamps, threshold: config.onsetThreshold)

        let leftPeak = leftSignal.max()
        let rightPeak = rightSignal.max()
        let leftPeakVelocity = velocityCalculator.peakVelocity(values: leftSignal, timestamps: timestamps)
        let rightPeakVelocity = velocityCalculator.peakVelocity(values: rightSignal, timestamps: timestamps)
        let leftPeakIndex = leftSignal.enumerated().max(by: { $0.element < $1.element })?.offset
        let rightPeakIndex = rightSignal.enumerated().max(by: { $0.element < $1.element })?.offset

        let leftTimeToPeak = timeToPeak(onset: leftOnset, peakIndex: leftPeakIndex, timestamps: timestamps)
        let rightTimeToPeak = timeToPeak(onset: rightOnset, peakIndex: rightPeakIndex, timestamps: timestamps)
        let leftActiveIndices = activeIndices(signal: leftSignal, threshold: config.onsetThreshold)
        let rightActiveIndices = activeIndices(signal: rightSignal, threshold: config.onsetThreshold)

        let combinedHoldSignal = zip(leftSignal, rightSignal).map { left, right in
            (left + right) / 2.0
        }
        let holdSource = combinedHoldSignal.isEmpty ? leftSignal + rightSignal : combinedHoldSignal
        let holdStability = holdStability(signal: holdSource, threshold: config.holdThreshold)
        let confidence = confidenceScore(qcSummary: qcSummary)

        return DerivedMetrics(
            peakAmplitudeLeft: leftPeak,
            peakAmplitudeRight: rightPeak,
            peakVelocityLeft: leftPeakVelocity,
            peakVelocityRight: rightPeakVelocity,
            symmetry: symmetryCalculator.symmetry(left: leftPeak, right: rightPeak),
            onsetTimeLeft: leftOnset,
            onsetTimeRight: rightOnset,
            timeToPeakLeft: leftTimeToPeak,
            timeToPeakRight: rightTimeToPeak,
            meanActiveVelocityLeft: velocityCalculator.meanActiveVelocity(values: leftSignal, timestamps: timestamps, activeIndices: leftActiveIndices),
            meanActiveVelocityRight: velocityCalculator.meanActiveVelocity(values: rightSignal, timestamps: timestamps, activeIndices: rightActiveIndices),
            holdStability: holdStability,
            fatigueSlope: nil,
            confidenceScore: confidence
        )
    }

    private func unilateralMetrics(from signal: [Double], timestamps: [TimeInterval], config: TaskConfiguration, qcSummary: QCSummary) -> DerivedMetrics {
        let onset = onsetTime(signal: signal, timestamps: timestamps, threshold: config.onsetThreshold)
        let peak = signal.max()
        let peakVelocity = velocityCalculator.peakVelocity(values: signal, timestamps: timestamps)
        let peakIndex = signal.enumerated().max(by: { $0.element < $1.element })?.offset
        let timeToPeakValue = timeToPeak(onset: onset, peakIndex: peakIndex, timestamps: timestamps)
        let active = activeIndices(signal: signal, threshold: config.onsetThreshold)
        let hold = holdStability(signal: signal, threshold: config.holdThreshold)

        return DerivedMetrics(
            peakAmplitudeLeft: peak,
            peakAmplitudeRight: nil,
            peakVelocityLeft: peakVelocity,
            peakVelocityRight: nil,
            symmetry: nil,
            onsetTimeLeft: onset,
            onsetTimeRight: nil,
            timeToPeakLeft: timeToPeakValue,
            timeToPeakRight: nil,
            meanActiveVelocityLeft: velocityCalculator.meanActiveVelocity(values: signal, timestamps: timestamps, activeIndices: active),
            meanActiveVelocityRight: nil,
            holdStability: hold,
            fatigueSlope: nil,
            confidenceScore: confidenceScore(qcSummary: qcSummary)
        )
    }

    private func preprocessedSignal(frames: [FrameCapture], keys: [String]) -> [Double]? {
        guard let key = keys.first(where: { candidate in
            frames.contains { frame in
                frame.normalizedBlendshapes[candidate] != nil || frame.rawBlendshapes[candidate] != nil
            }
        }) else {
            return nil
        }

        return preprocessor.preprocess(frames: frames, key: key)
    }

    private func onsetTime(signal: [Double], timestamps: [TimeInterval], threshold: Double) -> Double? {
        guard signal.count == timestamps.count, !signal.isEmpty else { return nil }
        let requiredDuration = AppConfiguration.shared.onsetSustainDurationSeconds
        guard let onsetIndex = TemporalSampleUtilities.sustainedOnsetIndex(
            signal: signal,
            timestamps: timestamps,
            threshold: threshold,
            requiredDuration: requiredDuration
        ) else { return nil }
        return TemporalSampleUtilities.elapsedTime(from: timestamps[0], to: timestamps[onsetIndex])
    }

    private func timeToPeak(onset: Double?, peakIndex: Int?, timestamps: [TimeInterval]) -> Double? {
        guard let onset, let peakIndex, timestamps.indices.contains(peakIndex) else { return nil }
        return (timestamps[peakIndex] - timestamps[0]) - onset
    }

    private func activeIndices(signal: [Double], threshold: Double) -> [Int] {
        signal.enumerated().filter { $0.element >= threshold }.map(\.offset)
    }

    private func holdStability(signal: [Double], threshold: Double) -> Double? {
        let holdValues = signal.filter { $0 >= threshold }
        guard !holdValues.isEmpty else { return nil }
        return TimeSeriesUtils.standardDeviation(holdValues)
    }

    private func confidenceScore(qcSummary: QCSummary) -> Double {
        let base = qcSummary.percentFramesPassing
        return qcSummary.overallPassed ? min(1, base) : max(0, base * 0.5)
    }

    private func leftMetricKeys(for task: TaskType) -> [String] {
        switch task {
        case .browRaise:
            return ["browOuterUp_L", "browOuterUpLeft"]
        case .eyeClosure:
            return ["eyeBlink_L", "eyeBlinkLeft"]
        case .smileTeeth, .smileClosed:
            return ["mouthSmile_L", "mouthSmileLeft"]
        default:
            return []
        }
    }

    private func rightMetricKeys(for task: TaskType) -> [String] {
        switch task {
        case .browRaise:
            return ["browOuterUp_R", "browOuterUpRight"]
        case .eyeClosure:
            return ["eyeBlink_R", "eyeBlinkRight"]
        case .smileTeeth, .smileClosed:
            return ["mouthSmile_R", "mouthSmileRight"]
        default:
            return []
        }
    }

    private func bilateralMetricKeys(for task: TaskType) -> [String] {
        switch task {
        case .lipPucker:
            return ["mouthPucker"]
        case .cheekPuff:
            return ["cheekPuff"]
        default:
            return []
        }
    }
}
