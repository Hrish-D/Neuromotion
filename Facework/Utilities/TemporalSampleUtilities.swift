//
//  TemporalSampleUtilities.swift
//  Facework
//

import Foundation

/// Deterministic helpers for calculations based on recorded source timestamps.
enum TemporalSampleUtilities {
    static let comparisonTolerance: TimeInterval = 1e-9

    static func positiveInterval(from start: TimeInterval,
                                 to end: TimeInterval) -> TimeInterval? {
        let interval = end - start
        return interval > 0 ? interval : nil
    }

    static func elapsedTime(from start: TimeInterval,
                            to end: TimeInterval) -> TimeInterval? {
        guard end >= start else { return nil }
        return end - start
    }

    static func meetsDuration(_ elapsed: TimeInterval,
                              required: TimeInterval) -> Bool {
        elapsed + comparisonTolerance >= required
    }

    static func sustainedOnsetIndex(signal: [Double],
                                    timestamps: [TimeInterval],
                                    threshold: Double,
                                    requiredDuration: TimeInterval) -> Int? {
        guard signal.count == timestamps.count, !signal.isEmpty else { return nil }

        for candidateIndex in signal.indices where signal[candidateIndex] >= threshold {
            for sustainIndex in candidateIndex..<signal.count {
                guard signal[sustainIndex] >= threshold else { break }
                guard let elapsed = elapsedTime(
                    from: timestamps[candidateIndex],
                    to: timestamps[sustainIndex]
                ) else { break }

                if meetsDuration(elapsed, required: requiredDuration) {
                    return candidateIndex
                }
            }
        }

        return nil
    }
}
