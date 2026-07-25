//
//  PeakFrameFinder.swift
//  Neuromotion
//
//  Created for validation-frame export.
//

import Foundation

struct PeakFrameCandidate {
    let frame: FrameCapture
    let signalValue: Double
}

struct PeakFrameFinder {
    func findPeak(task: TaskType, frames: [FrameCapture]) -> PeakFrameCandidate? {
        let validFrames = frames.filter(\.isValidFrame)
        guard !validFrames.isEmpty else { return nil }

        let candidates = validFrames.compactMap { frame -> PeakFrameCandidate? in
            guard let value = validationSignal(for: task, frame: frame) else { return nil }
            return PeakFrameCandidate(frame: frame, signalValue: value)
        }

        return candidates.max { a, b in
            a.signalValue < b.signalValue
        }
    }

    private func validationSignal(for task: TaskType, frame: FrameCapture) -> Double? {
        switch task {
        case .neutralRest:
            return nil

        case .browRaise:
            return maxValue(frame, keys: ["browOuterUp_L", "browOuterUpLeft", "browOuterUp_R", "browOuterUpRight"])

        case .eyeClosure:
            return maxValue(frame, keys: ["eyeBlink_L", "eyeBlinkLeft", "eyeBlink_R", "eyeBlinkRight"])

        case .smileTeeth, .smileClosed:
            return maxValue(frame, keys: ["mouthSmile_L", "mouthSmileLeft", "mouthSmile_R", "mouthSmileRight"])

        case .lipPucker:
            return maxValue(frame, keys: ["mouthPucker"])

        case .cheekPuff:
            return maxValue(frame, keys: ["cheekPuff"])
        }
    }

    private func maxValue(_ frame: FrameCapture, keys: [String]) -> Double? {
        let values = keys.compactMap { key in
            frame.smoothedBlendshapes[key] ?? frame.normalizedBlendshapes[key] ?? frame.rawBlendshapes[key]
        }
        return values.max()
    }
}
