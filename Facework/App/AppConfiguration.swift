//
//  AppConfiguration.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation
import CoreGraphics

struct AppConfiguration: Equatable {
    static let shared = AppConfiguration()

    let researchModeDefault: Bool = false
    let neutralCaptureDuration: TimeInterval = 2.5
    let readinessStableDuration: TimeInterval = 1.0
    let minimumValidFramePercentage: Double = 0.85
    let smoothingEnabled: Bool = true
    let smoothingWindow: Int = 5
    let onsetSustainFrameCount: Int = 3
    let maxFrameGapSeconds: Double = 0.15

    let yawThresholdDegrees: Double = 12
    let pitchThresholdDegrees: Double = 12
    let rollThresholdDegrees: Double = 12

    let faceCenterTolerance: Double = 0.22
    let faceScaleMin: Double = 0.18
    let faceScaleMax: Double = 0.75

    let neutralMaxBlendshapeActivation: Double = 0.15
    let neutralMaxHeadDeltaDegrees: Double = 5

    let holdThresholdDefault: Double = 0.35
    let onsetThresholdDefault: Double = 0.20
    let holdStabilityStdThreshold: Double = 0.12
    let signalSpikeDeltaThreshold: Double = 0.55

    let enableMeshCaptureStub: Bool = false
    let enablePeakFrameImageCapture: Bool = true

    let exportRootFolderName: String = "FacialMotionBaselineData"
}
