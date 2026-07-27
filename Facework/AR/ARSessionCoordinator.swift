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
        // Callback-sampled current-frame time; ARFaceAnchor has no intrinsic timestamp.
        let timestamp = session.currentFrame?.timestamp ?? CACurrentMediaTime()

        if faceAnchors.count == 1, let faceAnchor = faceAnchors.first {
            process(
                .faceUpdate(
                    FaceTrackingSnapshotInput(
                    sourceTimestamp: timestamp,
                    rawBlendshapes: BlendshapeMapper.map(faceAnchor.blendShapes),
                    faceTransform: faceAnchor.transform,
                    faceIsPresent: true,
                    visibleFaceCount: 1,
                    trackingState: .tracking,
                    faceCenter: CGPoint(x: 0.5, y: 0.5),
                    faceScale: 0.35
                    )
                )
            )
        } else if faceAnchors.count > 1 {
            // Face tracking currently uses ARKit's default maximum of one face.
            // This branch is defensive; this callback count is not a visible-face census.
            process(
                .multipleFaceUpdate(
                    sourceTimestamp: timestamp,
                    updatedFaceAnchorCount: faceAnchors.count
                )
            )
        } else {
            process(.noFaceUpdate(sourceTimestamp: timestamp))
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard anchors.contains(where: { $0 is ARFaceAnchor }) else { return }
        // Read once for this removal callback, using the same source as updates.
        let timestamp = session.currentFrame?.timestamp ?? CACurrentMediaTime()
        process(.faceRemoved(sourceTimestamp: timestamp))
    }

    func process(_ event: FaceTrackingCallbackEvent) {
        manager?.receive(FaceTrackingEventProcessor.observation(for: event))
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        // This camera/session status remains a separate compatibility input to
        // existing QC. It is not part of an atomic face-anchor observation.
        manager?.trackingStateDescription = String(describing: camera.trackingState)
    }
}
