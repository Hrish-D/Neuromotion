//
//  TrackingValidator.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct TrackingValidator {
    func validate(faceCount: Int, trackingDescription: String) -> [QCFlag] {
        if faceCount == 0 { return [.noFace, .trackingLost] }
        if faceCount > 1 { return [.multipleFaces] }
        if trackingDescription.localizedCaseInsensitiveContains("limited") { return [.trackingLost] }
        return []
    }
}
