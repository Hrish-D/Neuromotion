//
//  DeviceReadinessStatus.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation

struct DeviceReadinessStatus: Equatable {
    var isFaceTrackingSupported: Bool = false
    var cameraPermissionGranted: Bool = false
    var frontCameraAvailable: Bool = false
    var exactlyOneFaceVisible: Bool = false
    var framingReady: Bool = false
    var poseReady: Bool = false
    var trackingStable: Bool = false
    var blockingReasons: [String] = []

    var canProceed: Bool {
        isFaceTrackingSupported && cameraPermissionGranted && frontCameraAvailable && exactlyOneFaceVisible && framingReady && poseReady && trackingStable
    }
}
