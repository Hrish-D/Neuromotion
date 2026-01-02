//
//  FacCaptureView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2025-12-28.
//

import Foundation
import SwiftUI
import ARKit
import RealityKit

struct FaceCaptureView: View {

    @Environment(\.dismiss) private var dismiss
    var onCapture: (FaceMeasurement) -> Void

    var body: some View {
        ARViewContainer { measurement in
            onCapture(measurement)
            dismiss()
        }
        .ignoresSafeArea()
    }
}

struct ARViewContainer: UIViewRepresentable {

    var onCapture: (FaceMeasurement) -> Void

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARFaceTrackingConfiguration()
        arView.session.run(config)
        arView.session.delegate = context.coordinator

        context.coordinator.onCapture = onCapture

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, ARSessionDelegate {

        var onCapture: ((FaceMeasurement) -> Void)?

        private var maxSmileLeft: Float = 0
        private var maxSmileRight: Float = 0
        private var maxBlinkLeft: Float = 0
        private var maxBlinkRight: Float = 0

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {

            guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }

            maxSmileLeft  = max(maxSmileLeft,  face.blendShapes[.mouthSmileLeft]?.floatValue ?? 0)
            maxSmileRight = max(maxSmileRight, face.blendShapes[.mouthSmileRight]?.floatValue ?? 0)
            maxBlinkLeft  = max(maxBlinkLeft,  face.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0)
            maxBlinkRight = max(maxBlinkRight, face.blendShapes[.eyeBlinkRight]?.floatValue ?? 0)

            if CACurrentMediaTime().truncatingRemainder(dividingBy: 2.0) < 0.02 {

                let smileSym = symmetry(left: maxSmileLeft, right: maxSmileRight)
                let blinkSym = symmetry(left: maxBlinkLeft, right: maxBlinkRight)

                let measurement = FaceMeasurement(
                    timestamp: Date(),
                    smileLeft: maxSmileLeft,
                    smileRight: maxSmileRight,
                    blinkLeft: maxBlinkLeft,
                    blinkRight: maxBlinkRight,
                    smileSymmetry: smileSym,
                    blinkSymmetry: blinkSym
                )

                onCapture?(measurement)

                maxSmileLeft = 0
                maxSmileRight = 0
                maxBlinkLeft = 0
                maxBlinkRight = 0
            }
        }

        private func symmetry(left: Float, right: Float) -> Float {
            guard max(left, right) > 0 else { return 1.0 }
            return min(left, right) / max(left, right)
        }
    }
}
