import SceneKit
import SwiftUI

private final class FaceMeshSCNView: SCNView {
    var layoutHandler: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutHandler?()
    }
}

struct StoredFaceMeshSceneView: UIViewRepresentable {
    let frame: RawFaceMeshFrame
    let topology: FaceMeshTopology
    let selectedVertexIndex: Int?
    let regionVertexIndices: Set<Int>
    let draftConfiguration: ResearchFaceGeometryConfiguration?
    let preset: FaceMeshViewPreset
    let resetViewGeneration: Int
    let onSelection: (Int?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> SCNView {
        let view = FaceMeshSCNView()
        view.scene = SCNScene()
        view.backgroundColor = UIColor.secondarySystemGroupedBackground
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        let camera = SCNNode()
        camera.name = "researchCamera"
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        view.scene?.rootNode.addChildNode(camera)
        view.pointOfView = camera
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.view = view
        view.layoutHandler = { [weak coordinator = context.coordinator] in
            coordinator?.updateCameraFraming()
        }
        context.coordinator.rebuild(parent: self)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.rebuild(parent: self)
    }

    final class Coordinator: NSObject {
        var parent: StoredFaceMeshSceneView
        weak var view: SCNView?
        private var lastFramingKey: String?
        init(parent: StoredFaceMeshSceneView) { self.parent = parent }

        func rebuild(parent: StoredFaceMeshSceneView) {
            guard let root = view?.scene?.rootNode else { return }
            root.childNodes.filter { $0.name != "researchCamera" }.forEach { $0.removeFromParentNode() }
            let aspect = viewportAspect
            guard let framing = FaceMeshCameraFraming.calculate(
                vertices: parent.frame.vertices,
                preset: parent.preset,
                viewportAspectRatio: aspect
            ), let specification = FaceMeshRenderSpecification.make(frame: parent.frame, topology: parent.topology) else { return }
            let content = SCNNode()
            content.name = "storedMeshContent"
            content.eulerAngles.y = parent.preset.yawRadians
            root.addChildNode(content)
            let centered = SCNNode()
            centered.name = "centeredRawMesh"
            centered.position = SCNVector3(-framing.displayCenter.x, -framing.displayCenter.y, -framing.displayCenter.z)
            content.addChildNode(centered)
            let vertices = parent.frame.vertices.map { SCNVector3($0.x, $0.y, $0.z) }
            let source = SCNGeometrySource(vertices: vertices)
            let indexData = parent.topology.triangleIndices.withUnsafeBufferPointer { Data(buffer: $0) }
            let triangles = SCNGeometryElement(data: indexData, primitiveType: .triangles,
                                               primitiveCount: parent.topology.triangleCount,
                                               bytesPerIndex: MemoryLayout<Int16>.size)
            let geometry = SCNGeometry(sources: [source], elements: [triangles])
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemTeal
            material.emission.contents = UIColor.systemTeal
            material.lightingModel = .constant
            material.fillMode = .lines
            material.isDoubleSided = true
            material.transparency = CGFloat(specification.materialOpacity)
            geometry.materials = [material]
            let meshNode = SCNNode(geometry: geometry)
            meshNode.name = "storedRawMesh"
            centered.addChildNode(meshNode)

            let pointElement = SCNGeometryElement(data: nil, primitiveType: .point, primitiveCount: vertices.count, bytesPerIndex: 0)
            pointElement.pointSize = CGFloat(specification.pointSize)
            pointElement.minimumPointScreenSpaceRadius = CGFloat(specification.minimumPointRadius)
            pointElement.maximumPointScreenSpaceRadius = CGFloat(specification.maximumPointRadius)
            let points = SCNGeometry(sources: [source], elements: [pointElement])
            let pointMaterial = SCNMaterial()
            pointMaterial.diffuse.contents = UIColor.label
            pointMaterial.emission.contents = UIColor.label
            pointMaterial.lightingModel = .constant
            pointMaterial.transparency = CGFloat(specification.materialOpacity)
            points.materials = [pointMaterial]
            centered.addChildNode(SCNNode(geometry: points))

            let markerRadius = max(framing.rawBounds.largestExtent * 0.012, 0.000_5)
            let overlays = FaceMeshDraftOverlayResolver.resolve(configuration: parent.draftConfiguration, frame: parent.frame)
            for landmark in overlays.landmarks {
                addMarker(at: SCNVector3(landmark.position.x, landmark.position.y, landmark.position.z), color: .systemPurple,
                          root: centered, radius: CGFloat(markerRadius * 1.35))
                addLabel("\(landmark.name) · \(landmark.index)", at: landmark.position, root: centered,
                         offset: markerRadius * 2.2)
            }
            for region in overlays.regions {
                for position in region.positions {
                    addMarker(at: SCNVector3(position.x, position.y, position.z), color: .systemCyan,
                              root: centered, radius: CGFloat(markerRadius * 0.85))
                }
            }
            for line in overlays.lines { addPath(line.positions, color: .systemGreen, root: centered, radius: markerRadius * 0.32) }
            for path in overlays.polylines { addPath(path.positions, color: .systemBlue, root: centered, radius: markerRadius * 0.25) }
            for plane in overlays.planes {
                addPath(plane.positions + [plane.positions[0]], color: .systemPink, root: centered, radius: markerRadius * 0.28)
            }
            for index in parent.regionVertexIndices where vertices.indices.contains(index) {
                addMarker(at: vertices[index], color: .systemOrange, root: centered, radius: CGFloat(markerRadius))
            }
            if let index = parent.selectedVertexIndex, vertices.indices.contains(index) {
                addMarker(at: vertices[index], color: .systemYellow, root: centered, radius: CGFloat(markerRadius * 1.8))
            }

            updateCameraFraming(framing: framing)
        }

        func updateCameraFraming() {
            guard let framing = FaceMeshCameraFraming.calculate(vertices: parent.frame.vertices,
                                                                 preset: parent.preset,
                                                                 viewportAspectRatio: viewportAspect) else { return }
            updateCameraFraming(framing: framing)
        }

        private var viewportAspect: Float {
            Float(max(view?.bounds.width ?? 0, 1) / max(view?.bounds.height ?? 0, 1))
        }

        private func updateCameraFraming(framing: FaceMeshCameraFraming) {
            let sizeKey = "\(Int(view?.bounds.width ?? 0))x\(Int(view?.bounds.height ?? 0))"
            let framingKey = "\(parent.frame.id.uuidString)|\(parent.preset.rawValue)|\(parent.resetViewGeneration)|\(sizeKey)"
            guard framingKey != lastFramingKey, let cameraNode = view?.pointOfView, let camera = cameraNode.camera else { return }
            camera.usesOrthographicProjection = true
            camera.orthographicScale = Double(framing.orthographicScale)
            camera.zNear = Double(framing.zNear)
            camera.zFar = Double(framing.zFar)
            cameraNode.position = SCNVector3(0, 0, framing.cameraDistance)
            cameraNode.orientation = SCNQuaternion(0, 0, 0, 1)
            lastFramingKey = framingKey
        }

        @objc func didTap(_ recognizer: UITapGestureRecognizer) {
            guard let view else { return }
            let tap = recognizer.location(in: view)
            guard let centered = view.scene?.rootNode.childNode(withName: "centeredRawMesh", recursively: true) else { return }
            let projected = parent.frame.vertices.enumerated().map { index, vertex -> ProjectedFaceMeshVertex in
                let worldPoint = centered.presentation.convertPosition(SCNVector3(vertex.x, vertex.y, vertex.z), to: nil)
                let point = view.projectPoint(worldPoint)
                return ProjectedFaceMeshVertex(index: index, screenPoint: CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)), depth: point.z)
            }.filter { $0.depth >= 0 && $0.depth <= 1 }
            parent.onSelection(FaceMeshProjection.nearestVertex(to: tap, projectedVertices: projected, tolerance: 18))
        }

        private func addMarker(at position: SCNVector3, color: UIColor, root: SCNNode, radius: CGFloat) {
            let sphere = SCNSphere(radius: radius)
            sphere.firstMaterial?.diffuse.contents = color
            sphere.firstMaterial?.emission.contents = color
            sphere.firstMaterial?.lightingModel = .constant
            let node = SCNNode(geometry: sphere)
            node.position = position
            root.addChildNode(node)
        }

        private func addPath(_ positions: [FaceMeshVertex], color: UIColor, root: SCNNode, radius: Float) {
            guard positions.count >= 2 else { return }
            for pair in zip(positions, positions.dropFirst()) {
                let a = pair.0.simdValue, b = pair.1.simdValue
                let delta = b - a, length = simd_length(delta)
                guard length > 0 else { continue }
                let cylinder = SCNCylinder(radius: CGFloat(radius), height: CGFloat(length))
                cylinder.firstMaterial?.diffuse.contents = color
                cylinder.firstMaterial?.emission.contents = color
                cylinder.firstMaterial?.lightingModel = .constant
                let node = SCNNode(geometry: cylinder)
                node.simdPosition = (a + b) / 2
                node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: delta / length)
                root.addChildNode(node)
            }
        }

        private func addLabel(_ text: String, at position: FaceMeshVertex, root: SCNNode, offset: Float) {
            let geometry = SCNText(string: text, extrusionDepth: 0)
            geometry.font = .systemFont(ofSize: 5, weight: .semibold)
            geometry.flatness = 0.2
            geometry.firstMaterial?.diffuse.contents = UIColor.systemPurple
            geometry.firstMaterial?.emission.contents = UIColor.systemPurple
            geometry.firstMaterial?.lightingModel = .constant
            let node = SCNNode(geometry: geometry)
            let scale = offset / 32
            node.scale = SCNVector3(scale, scale, scale)
            node.position = SCNVector3(position.x + offset, position.y + offset, position.z)
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .all
            node.constraints = [billboard]
            root.addChildNode(node)
        }
    }
}
