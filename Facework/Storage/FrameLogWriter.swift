//
//  FrameLogWriter.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

final class FrameLogWriter {
    private(set) var frames: [FrameCapture] = []

    func append(_ frame: FrameCapture) {
        frames.append(frame)
    }

    func reset() {
        frames.removeAll()
    }
}
