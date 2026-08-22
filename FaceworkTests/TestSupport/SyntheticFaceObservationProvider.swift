import Combine
@testable import Facework

@MainActor
final class SyntheticFaceObservationProvider: FaceObservationProviding {
    var observations: AnyPublisher<SynchronizedFaceObservation, Never> {
        subject.eraseToAnyPublisher()
    }

    private let subject = PassthroughSubject<SynchronizedFaceObservation, Never>()

    func emit(_ observation: FaceTrackingObservation) {
        subject.send(SynchronizedFaceObservation(observation: observation))
    }

    func emit(_ synchronizedObservation: SynchronizedFaceObservation) {
        subject.send(synchronizedObservation)
    }
}
