import Combine
@testable import Facework

@MainActor
final class SyntheticFaceObservationProvider: FaceObservationProviding {
    var observations: AnyPublisher<FaceTrackingObservation, Never> {
        subject.eraseToAnyPublisher()
    }

    private let subject = PassthroughSubject<FaceTrackingObservation, Never>()

    func emit(_ observation: FaceTrackingObservation) {
        subject.send(observation)
    }
}
