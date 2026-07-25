//
//  FaceGeometryExtractor.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation
import ARKit

struct FaceGeometryExtractor {
    func extractVertices(from anchor: ARFaceAnchor) -> [[Float]]? {
        guard AppConfiguration.shared.enableMeshCaptureStub else { return nil }
        let vertices = anchor.geometry.vertices
        return vertices.map { [$0.x, $0.y, $0.z] }
    }
}
