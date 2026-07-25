//
//  SignalPlausibilityValidator.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct SignalPlausibilityValidator {
    func validate(previous: FrameCapture?, currentRaw: [String: Double], timestamp: TimeInterval) -> [QCFlag] {
        var flags: [QCFlag] = []
        if let previous {
            let dt = timestamp - previous.timestamp
            if dt <= 0 || dt > AppConfiguration.shared.maxFrameGapSeconds {
                flags.append(.invalidTimestampGap)
            }
            for (key, value) in currentRaw {
                guard let old = previous.rawBlendshapes[key] else { continue }
                if abs(value - old) > AppConfiguration.shared.signalSpikeDeltaThreshold {
                    flags.append(.signalSpike)
                    break
                }
            }
        }

        if currentRaw.isEmpty {
            flags.append(.missingBlendshapeValue)
        }
        return flags
    }
}
