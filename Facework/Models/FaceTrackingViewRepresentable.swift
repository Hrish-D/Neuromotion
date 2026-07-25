//
//  FaceTrackingViewRepresentable.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import SwiftUI
import ARKit
import SceneKit
import UIKit

struct FaceTrackingViewRepresentable: UIViewRepresentable {
    @ObservedObject var trackingManager: FaceTrackingManager
    var showMeshOverlay: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(showMeshOverlay: showMeshOverlay)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session = trackingManager.session
        view.delegate = context.coordinator
        context.coordinator.sceneView = view
        view.automaticallyUpdatesLighting = true
        view.backgroundColor = .black
        view.scene = SCNScene()
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.showMeshOverlay = showMeshOverlay
        context.coordinator.setMeshVisibility(showMeshOverlay)
    }

    final class Coordinator: NSObject, ARSCNViewDelegate {
        weak var sceneView: ARSCNView?
        var showMeshOverlay: Bool
        private weak var faceMeshNode: SCNNode?

        init(showMeshOverlay: Bool) {
            self.showMeshOverlay = showMeshOverlay
        }

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard anchor is ARFaceAnchor else { return nil }
            let node = SCNNode()

            guard showMeshOverlay,
                  let device = sceneView?.device,
                  let faceGeometry = ARSCNFaceGeometry(device: device) else {
                return node
            }

            faceGeometry.firstMaterial = meshMaterial()
            node.geometry = faceGeometry
            node.isHidden = !showMeshOverlay
            faceMeshNode = node
            return node
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor else { return }

            if let faceGeometry = node.geometry as? ARSCNFaceGeometry {
                faceGeometry.update(from: faceAnchor.geometry)
            } else if showMeshOverlay,
                      let device = sceneView?.device,
                      let faceGeometry = ARSCNFaceGeometry(device: device) {
                faceGeometry.firstMaterial = meshMaterial()
                faceGeometry.update(from: faceAnchor.geometry)
                node.geometry = faceGeometry
            }

            node.isHidden = !showMeshOverlay
            faceMeshNode = node
        }

        func setMeshVisibility(_ isVisible: Bool) {
            faceMeshNode?.isHidden = !isVisible
        }

        private func meshMaterial() -> SCNMaterial {
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.85)
            material.emission.contents = UIColor.systemGreen.withAlphaComponent(0.35)
            material.lightingModel = .constant
            material.isDoubleSided = true
            material.fillMode = .lines
            return material
        }
    }
}
