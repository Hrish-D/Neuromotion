//
//  FaceObservationCollector.swift
//  Facework
//

import Combine
import Foundation

enum FaceObservationCollectionMode: Equatable {
    case neutral
    case task(task: TaskType, repetitionIndex: Int)
}

struct CollectedFaceObservation {
    let recordingID: UUID
    let mode: FaceObservationCollectionMode
    let observation: FaceTrackingObservation
    let cameraTrackingState: String
}

nonisolated final class FaceObservationCollector {
    typealias ObservationHandler = (CollectedFaceObservation) -> Void

    private struct ActiveCollection {
        let recordingID: UUID
        let mode: FaceObservationCollectionMode
        let handler: ObservationHandler
        var lastAcceptedTimestamp: TimeInterval?
    }

    private let minimumSampleInterval: TimeInterval
    private let cameraTrackingState: () -> String
    private var activeCollection: ActiveCollection?
    private var observationCancellable: AnyCancellable?

    @MainActor
    init(
        provider: any FaceObservationProviding,
        minimumSampleInterval: TimeInterval = 0.1,
        cameraTrackingState: @escaping () -> String
    ) {
        self.minimumSampleInterval = minimumSampleInterval
        self.cameraTrackingState = cameraTrackingState
        observationCancellable = provider.observations.sink { [weak self] observation in
            self?.receive(observation)
        }
    }

    @MainActor
    @discardableResult
    func start(
        mode: FaceObservationCollectionMode,
        handler: @escaping ObservationHandler
    ) -> UUID {
        let recordingID = UUID()
        activeCollection = ActiveCollection(
            recordingID: recordingID,
            mode: mode,
            handler: handler,
            lastAcceptedTimestamp: nil
        )
        return recordingID
    }

    @MainActor
    func stop(recordingID: UUID? = nil) {
        guard let activeCollection else { return }
        guard recordingID == nil || recordingID == activeCollection.recordingID else { return }
        self.activeCollection = nil
    }

    @MainActor
    private func receive(_ observation: FaceTrackingObservation) {
        guard var activeCollection else { return }

        if let lastTimestamp = activeCollection.lastAcceptedTimestamp,
           observation.sourceTimestamp - lastTimestamp + 1e-9 < minimumSampleInterval {
            return
        }

        activeCollection.lastAcceptedTimestamp = observation.sourceTimestamp
        self.activeCollection = activeCollection

        activeCollection.handler(
            CollectedFaceObservation(
                recordingID: activeCollection.recordingID,
                mode: activeCollection.mode,
                observation: observation,
                cameraTrackingState: cameraTrackingState()
            )
        )
    }
}
