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
        guard let frame = session.currentFrame else {
            process(.noFaceUpdate(sourceTimestamp: CACurrentMediaTime()))
            return
        }
        let timestamp = frame.timestamp
        let cameraTrackingState = String(describing: frame.camera.trackingState)
        let faceAnchors = frame.anchors.compactMap { $0 as? ARFaceAnchor }

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
                ),
                validationImageSource: ValidationImageSource(
                    sourceTimestamp: timestamp,
                    payload: .pixelBuffer(frame.capturedImage)
                ),
                faceMeshSnapshot: makeMeshSnapshot(
                    geometry: faceAnchor.geometry,
                    sourceTimestamp: timestamp
                ),
                frameCameraTrackingState: cameraTrackingState
            )
        } else if faceAnchors.count > 1 {
            // Face tracking currently uses ARKit's default maximum of one face.
            // This branch is defensive; this callback count is not a visible-face census.
            process(
                .multipleFaceUpdate(
                    sourceTimestamp: timestamp,
                    updatedFaceAnchorCount: faceAnchors.count
                ),
                frameCameraTrackingState: cameraTrackingState
            )
        } else {
            process(
                .noFaceUpdate(sourceTimestamp: timestamp),
                frameCameraTrackingState: cameraTrackingState
            )
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard anchors.contains(where: { $0 is ARFaceAnchor }) else { return }
        // Read once for this removal callback, using the same source as updates.
        let timestamp = session.currentFrame?.timestamp ?? CACurrentMediaTime()
        process(.faceRemoved(sourceTimestamp: timestamp))
    }

    func process(
        _ event: FaceTrackingCallbackEvent,
        validationImageSource: ValidationImageSource? = nil,
        faceMeshSnapshot: FaceMeshSnapshot? = nil,
        frameCameraTrackingState: String? = nil
    ) {
        manager?.receive(
            SynchronizedFaceObservationBuilder.make(
                event: event,
                validationImageSource: validationImageSource,
                faceMeshSnapshot: faceMeshSnapshot,
                frameCameraTrackingState: frameCameraTrackingState
            )
        )
    }

    /// Deep-copies all pointer-backed ARKit values before the callback returns.
    /// No ARFaceGeometry or ARFaceAnchor reference crosses this boundary.
    private func makeMeshSnapshot(
        geometry: ARFaceGeometry,
        sourceTimestamp: TimeInterval
    ) -> FaceMeshSnapshot {
        let vertices = geometry.vertices.map(FaceMeshVertex.init)
        let textureCoordinates = geometry.textureCoordinates.map(FaceMeshTextureCoordinate.init)
        let triangleIndices = Array(geometry.triangleIndices)
        let topology = FaceMeshTopology(
            vertexCount: vertices.count,
            triangleCount: geometry.triangleCount,
            triangleIndices: triangleIndices,
            textureCoordinates: textureCoordinates
        )
        return FaceMeshSnapshot(
            sourceTimestamp: sourceTimestamp,
            topology: topology,
            vertices: vertices
        )
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        // This camera/session status remains a separate compatibility input to
        // existing QC. It is not part of an atomic face-anchor observation.
        manager?.trackingStateDescription = String(describing: camera.trackingState)
    }
}
