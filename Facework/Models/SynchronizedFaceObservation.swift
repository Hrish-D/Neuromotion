//
//  SynchronizedFaceObservation.swift
//  Facework
//

import CoreVideo
import Foundation

enum ValidationImagePayload {
    case pixelBuffer(CVPixelBuffer)
    case encodedImageData(Data, identifier: String)

    var testIdentifier: String? {
        guard case .encodedImageData(_, let identifier) = self else { return nil }
        return identifier
    }
}

/// A transient, same-ARFrame image source. The payload is deliberately not
/// Codable and never becomes part of the persisted raw scientific record.
struct ValidationImageSource {
    let sourceTimestamp: TimeInterval
    let payload: ValidationImagePayload
}

/// One atomic face observation and the optional RGB source captured from the
/// exact same ARFrame. Only accepted validation-image frames retain the source
/// long enough for synchronous encoding.
struct SynchronizedFaceObservation {
    let observation: FaceTrackingObservation
    let validationImageSource: ValidationImageSource?
    let frameCameraTrackingState: String?

    init(
        observation: FaceTrackingObservation,
        validationImageSource: ValidationImageSource? = nil,
        frameCameraTrackingState: String? = nil
    ) {
        if let validationImageSource {
            precondition(
                validationImageSource.sourceTimestamp == observation.sourceTimestamp,
                "A synchronized image source must share the observation timestamp"
            )
        }
        self.observation = observation
        self.validationImageSource = validationImageSource
        self.frameCameraTrackingState = frameCameraTrackingState
    }
}

enum SynchronizedFaceObservationBuilder {
    static func make(
        event: FaceTrackingCallbackEvent,
        validationImageSource: ValidationImageSource? = nil,
        frameCameraTrackingState: String? = nil
    ) -> SynchronizedFaceObservation {
        SynchronizedFaceObservation(
            observation: FaceTrackingEventProcessor.observation(for: event),
            validationImageSource: validationImageSource,
            frameCameraTrackingState: frameCameraTrackingState
        )
    }
}

enum ValidationImageCapturePolicy {
    static let stride = 10

    static func shouldCapture(acceptedFrameIndex: Int) -> Bool {
        acceptedFrameIndex >= 0 && acceptedFrameIndex % stride == 0
    }

    static func fileStem(task: TaskType, repetitionIndex: Int, frameIndex: Int) -> String {
        "validation_\(task.rawValue)_rep_\(repetitionIndex)_frame_\(String(format: "%04d", frameIndex))"
    }
}
