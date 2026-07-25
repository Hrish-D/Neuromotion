//
//  FramingValidator.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation
import CoreGraphics

struct FramingValidator {
    func validate(center: CGPoint, scale: Double) -> [QCFlag] {
        let config = AppConfiguration.shared
        let centerOK = abs(center.x - 0.5) <= config.faceCenterTolerance && abs(center.y - 0.5) <= config.faceCenterTolerance
        let scaleOK = scale >= config.faceScaleMin && scale <= config.faceScaleMax
        return (centerOK && scaleOK) ? [] : [.poorFraming]
    }
}
