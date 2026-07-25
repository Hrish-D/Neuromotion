//
//  HoldValidator.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//
import Foundation

struct HoldValidator {
    func validate(signal: [Double], timestamps: [TimeInterval], threshold: Double, requiredDuration: TimeInterval) -> [QCFlag] {
        guard signal.count == timestamps.count, !signal.isEmpty else { return [.notEnoughFrames] }
        var currentStart: TimeInterval?
        for index in signal.indices {
            if signal[index] >= threshold {
                if currentStart == nil { currentStart = timestamps[index] }
                if let start = currentStart, timestamps[index] - start >= requiredDuration {
                    return []
                }
            } else {
                currentStart = nil
            }
        }
        return [.holdNotMaintained]
    }
}

