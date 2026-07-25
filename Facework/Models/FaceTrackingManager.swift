//
//  FaceTrackingManager.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation
import ARKit
import AVFoundation
import Combine

final class FaceTrackingManager: NSObject, ObservableObject {
    @Published var latestBlendshapes: [String: Double] = [:]
    @Published var latestPose: HeadPose = HeadPose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0)
    @Published var trackingStateDescription: String = "Not Started"
    @Published var faceIsPresent: Bool = false
    @Published var visibleFaceCount: Int = 0
    @Published var faceCenter: CGPoint = .zero
    @Published var faceScale: Double = 0
    @Published var latestTimestamp: TimeInterval = 0
    @Published var currentAnchor: ARFaceAnchor?

    let session = ARSession()
    private let coordinator: ARSessionCoordinator

    override init() {
        coordinator = ARSessionCoordinator()
        super.init()
        coordinator.manager = self
        session.delegate = coordinator
    }

    func start() {
        guard ARFaceTrackingConfiguration.isSupported else {
            trackingStateDescription = "Face tracking unsupported"
            return
        }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        trackingStateDescription = "Running"
    }

    func stop() {
        session.pause()
        trackingStateDescription = "Paused"
    }

    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
        default:
            completion(false)
        }
    }

    func update(anchor: ARFaceAnchor, timestamp: TimeInterval) {
        currentAnchor = anchor
        latestTimestamp = timestamp
        latestBlendshapes = BlendshapeMapper.map(anchor.blendShapes)
        latestPose = Self.poseFromTransform(anchor.transform)
        faceIsPresent = true
        visibleFaceCount = 1
        faceCenter = CGPoint(x: 0.5, y: 0.5)
        faceScale = 0.35
    }

    func updateNoFace(timestamp: TimeInterval) {
        latestTimestamp = timestamp
        faceIsPresent = false
        visibleFaceCount = 0
        currentAnchor = nil
    }

    static func poseFromTransform(_ transform: simd_float4x4) -> HeadPose {
        let yawRadians = Double(atan2(transform.columns.0.z, transform.columns.0.x))
        let pitchRadians = Double(asin(-transform.columns.0.y))
        let rollRadians = Double(atan2(transform.columns.1.x, transform.columns.1.y))

        let radiansToDegrees = 180.0 / Double.pi

        return HeadPose(
            yawDegrees: yawRadians * radiansToDegrees,
            pitchDegrees: pitchRadians * radiansToDegrees,
            rollDegrees: rollRadians * radiansToDegrees
        )
    }
}
