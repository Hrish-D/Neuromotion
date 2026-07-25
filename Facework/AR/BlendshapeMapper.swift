//
//  BlendshapeMapper.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation
import ARKit

enum BlendshapeMapper {
    static let allSupportedLocations: [ARFaceAnchor.BlendShapeLocation] = [
        .browInnerUp,
        .browDownLeft, .browDownRight,
        .browOuterUpLeft, .browOuterUpRight,
        .eyeBlinkLeft, .eyeBlinkRight,
        .eyeWideLeft, .eyeWideRight,
        .cheekPuff,
        .cheekSquintLeft, .cheekSquintRight,
        .mouthSmileLeft, .mouthSmileRight,
        .mouthFrownLeft, .mouthFrownRight,
        .mouthPucker,
        .mouthPressLeft, .mouthPressRight,
        .jawOpen,
        .jawLeft, .jawRight,
        .mouthLeft, .mouthRight,
        .mouthClose,
        .noseSneerLeft, .noseSneerRight
    ]

    static func stableName(for location: ARFaceAnchor.BlendShapeLocation) -> String {
        String(describing: location.rawValue)
    }

    static func map(_ raw: [ARFaceAnchor.BlendShapeLocation: NSNumber]) -> [String: Double] {
        var output: [String: Double] = [:]
        for key in allSupportedLocations {
            output[stableName(for: key)] = raw[key]?.doubleValue ?? 0
        }
        return output
    }
}
