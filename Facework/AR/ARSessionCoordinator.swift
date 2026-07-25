//
//  ARSessionCoordinator.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation
import ARKit

final class ARSessionCoordinator: NSObject, ARSessionDelegate {
    weak var manager: FaceTrackingManager?

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let faceAnchors = anchors.compactMap { $0 as? ARFaceAnchor }
        let timestamp = session.currentFrame?.timestamp ?? CACurrentMediaTime()

        if faceAnchors.count == 1, let faceAnchor = faceAnchors.first {
            manager?.update(anchor: faceAnchor, timestamp: timestamp)
            manager?.trackingStateDescription = "Tracking"
        } else if faceAnchors.count > 1 {
            manager?.visibleFaceCount = faceAnchors.count
            manager?.trackingStateDescription = "Multiple faces detected"
        } else {
            manager?.updateNoFace(timestamp: timestamp)
            manager?.trackingStateDescription = "No face"
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        manager?.trackingStateDescription = String(describing: camera.trackingState)
    }
}
