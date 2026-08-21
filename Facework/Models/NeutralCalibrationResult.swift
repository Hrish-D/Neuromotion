import Foundation

enum NeutralCalibrationFailureReason: String, Codable, Equatable, Sendable {
    case noCapturedFrames
    case noEligibleFrames
    case trackingInterrupted
    case insufficientTrackedDuration
}

struct NeutralCalibrationEvent: Equatable, Sendable {
    let sourceTimestamp: TimeInterval
    let faceIsPresent: Bool
    let visibleFaceCount: Int
    let faceTrackingState: FaceTrackingObservationState
    let hasBlendshapeMeasurements: Bool
    let cameraTrackingState: String

    init(
        sourceTimestamp: TimeInterval,
        faceIsPresent: Bool,
        visibleFaceCount: Int,
        faceTrackingState: FaceTrackingObservationState,
        hasBlendshapeMeasurements: Bool,
        cameraTrackingState: String
    ) {
        self.sourceTimestamp = sourceTimestamp
        self.faceIsPresent = faceIsPresent
        self.visibleFaceCount = visibleFaceCount
        self.faceTrackingState = faceTrackingState
        self.hasBlendshapeMeasurements = hasBlendshapeMeasurements
        self.cameraTrackingState = cameraTrackingState
    }

    init(collectedObservation: CollectedFaceObservation) {
        let observation = collectedObservation.observation
        sourceTimestamp = observation.sourceTimestamp
        faceIsPresent = observation.faceIsPresent
        visibleFaceCount = observation.visibleFaceCount
        faceTrackingState = observation.trackingState
        hasBlendshapeMeasurements = !observation.rawBlendshapes.isEmpty
        cameraTrackingState = collectedObservation.cameraTrackingState
    }
}

struct NeutralCalibrationAttemptEvidence: Equatable, Sendable {
    let events: [NeutralCalibrationEvent]
}

enum NeutralCalibrationPhase: Equatable, Sendable {
    case ready
    case capturing
    case checking
    case failed

    var showsRetryControl: Bool { self == .failed }
    var allowsStartControl: Bool { self != .failed }
}

enum NeutralCalibrationLiveStatus: Equatable, Sendable {
    case waiting
    case passing
    case failing
    case noFace
    case multipleFaces
    case trackingInterrupted

    static func resolve(
        phase: NeutralCalibrationPhase,
        latestEvent: NeutralCalibrationEvent?,
        latestFrameIsValid: Bool
    ) -> NeutralCalibrationLiveStatus {
        guard phase == .capturing else { return latestFrameIsValid ? .passing : .waiting }
        guard let latestEvent else { return .waiting }
        if latestEvent.cameraTrackingState.localizedCaseInsensitiveContains("limited") {
            return .trackingInterrupted
        }
        switch latestEvent.faceTrackingState {
        case .noFace:
            return .noFace
        case .multipleFaces:
            return .multipleFaces
        case .tracking:
            return latestFrameIsValid ? .passing : .failing
        }
    }
}

struct NeutralCalibrationDiagnostics: Codable, Equatable, Sendable {
    let totalFrameCount: Int
    let eligibleFrameCount: Int
    let rejectedFrameCount: Int
    let warningCount: Int
    let eligibleDurationSeconds: TimeInterval
    let observedEventCount: Int
    let hardFailureEventCount: Int
    let continuousTrackedDurationSeconds: TimeInterval
    let requiredTrackedDurationSeconds: TimeInterval
    let rejectionReasons: [QCFlag]
    let warningFlags: [QCFlag]
    let baselineEstablished: Bool
}

enum NeutralCalibrationResult: Equatable {
    case success(baseline: [String: Double], eligibleFrames: [FrameCapture], diagnostics: NeutralCalibrationDiagnostics)
    case failure(reason: NeutralCalibrationFailureReason, diagnostics: NeutralCalibrationDiagnostics)

    var diagnostics: NeutralCalibrationDiagnostics {
        switch self {
        case .success(_, _, let diagnostics), .failure(_, let diagnostics):
            diagnostics
        }
    }

    var baseline: [String: Double]? {
        guard case .success(let baseline, _, _) = self else { return nil }
        return baseline
    }

    var isSuccessful: Bool { baseline != nil }
    var allowsTaskNavigation: Bool { isSuccessful }
}
