//
//  PoseValidator.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct PoseValidator {
    func validate(_ pose: HeadPose) -> [QCFlag] {
        let config = AppConfiguration.shared
        let exceeds = abs(pose.yawDegrees) > config.yawThresholdDegrees ||
                      abs(pose.pitchDegrees) > config.pitchThresholdDegrees ||
                      abs(pose.rollDegrees) > config.rollThresholdDegrees
        return exceeds ? [.poseOutOfRange] : []
    }
}
