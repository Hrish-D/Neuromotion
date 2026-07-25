//
//  SignalPreprocessor.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct SignalPreprocessor {
    func preprocess(frames: [FrameCapture], key: String) -> [Double] {
        let validFrames = frames.filter(\.isValidFrame)
        let values = validFrames.map { $0.normalizedBlendshapes[key] ?? 0 }
        guard AppConfiguration.shared.smoothingEnabled else { return values }
        return TimeSeriesUtils.movingAverage(values: values, window: AppConfiguration.shared.smoothingWindow)
    }
}
