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

@MainActor
protocol FaceObservationProviding: AnyObject {
    var observations: AnyPublisher<SynchronizedFaceObservation, Never> { get }
}

@MainActor
final class FaceTrackingManager: NSObject, ObservableObject, FaceObservationProviding {
    // Transitional compatibility state for the timer-driven capture views.
    @Published var latestBlendshapes: [String: Double] = [:]
    @Published var latestPose: HeadPose = HeadPose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0)
    @Published var trackingStateDescription: String = "Not Started"
    @Published var faceIsPresent: Bool = false
    @Published var visibleFaceCount: Int = 0
    @Published var faceCenter: CGPoint = .zero
    @Published var faceScale: Double = 0
    @Published var latestTimestamp: TimeInterval = 0
    @Published private(set) var latestObservation: FaceTrackingObservation?

    var observations: AnyPublisher<SynchronizedFaceObservation, Never> {
        observationSubject.eraseToAnyPublisher()
    }

    private lazy var coordinator: ARSessionCoordinator = {
        let coordinator = ARSessionCoordinator()
        coordinator.manager = self
        return coordinator
    }()
    private let observationSubject = PassthroughSubject<SynchronizedFaceObservation, Never>()
    private(set) lazy var session: ARSession = {
        let session = ARSession()
        session.delegate = coordinator
        session.delegateQueue = .main
        return session
    }()

    override init() {
        super.init()
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

    func requestCameraPermission(completion: @escaping @Sendable (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
        default:
            completion(false)
        }
    }

    func receive(_ synchronizedObservation: SynchronizedFaceObservation) {
        let observation = synchronizedObservation.observation
        switch observation.trackingState {
        case .tracking:
            latestTimestamp = observation.sourceTimestamp
            faceIsPresent = true
            visibleFaceCount = observation.visibleFaceCount
            faceCenter = observation.faceCenter
            faceScale = observation.faceScale
            latestBlendshapes = observation.rawBlendshapes
            if let headPose = observation.headPose {
                latestPose = headPose
            }
        case .noFace:
            latestTimestamp = observation.sourceTimestamp
            faceIsPresent = false
            visibleFaceCount = 0
        case .multipleFaces:
            visibleFaceCount = observation.visibleFaceCount
        }
        trackingStateDescription = observation.trackingState.description
        latestObservation = observation

        observationSubject.send(synchronizedObservation)
    }

    func receive(_ observation: FaceTrackingObservation) {
        receive(SynchronizedFaceObservation(observation: observation))
    }

    static func poseFromTransform(_ transform: simd_float4x4) -> HeadPose {
        FaceTrackingObservationBuilder.poseFromTransform(transform)
    }
}

private extension FaceTrackingObservationState {
    var description: String {
        switch self {
        case .tracking:
            "Tracking"
        case .noFace:
            "No face"
        case .multipleFaces:
            "Multiple faces detected"
        }
    }
}
