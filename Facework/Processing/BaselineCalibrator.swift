//
//  BaselineCalibrator.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct BaselineCalibrator {
    func computeBaseline(from frames: [FrameCapture]) -> [String: Double] {
        guard !frames.isEmpty else { return [:] }
        let validFrames = frames.filter(\.isValidFrame)
        let source = validFrames.isEmpty ? frames : validFrames
        let allKeys = Set(source.flatMap { $0.rawBlendshapes.keys })
        var baseline: [String: Double] = [:]
        for key in allKeys {
            let values = source.compactMap { $0.rawBlendshapes[key] }
            guard !values.isEmpty else { continue }
            baseline[key] = values.reduce(0, +) / Double(values.count)
        }
        return baseline
    }

    func normalize(raw: [String: Double], baseline: [String: Double]) -> [String: Double] {
        var output: [String: Double] = [:]
        let keys = Set(raw.keys).union(baseline.keys)
        for key in keys {
            output[key] = (raw[key] ?? 0) - (baseline[key] ?? 0)
        }
        return output
    }
}
