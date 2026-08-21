import XCTest
@testable import Facework

final class QualityControlTests: XCTestCase {
    func testTrackingValidatorFaceCountAndLimitedState() {
        let validator = TrackingValidator()
        XCTAssertEqual(Set(validator.validate(faceCount: 0, trackingDescription: "Tracking")),
                       Set([.noFace, .trackingLost]))
        XCTAssertEqual(validator.validate(faceCount: 2, trackingDescription: "Tracking"), [.multipleFaces])
        XCTAssertEqual(validator.validate(faceCount: 1, trackingDescription: "limited(excessiveMotion)"),
                       [.trackingLost])
        XCTAssertTrue(validator.validate(faceCount: 1, trackingDescription: "Tracking").isEmpty)
    }

    func testFramingThresholdsAreInclusive() {
        let validator = FramingValidator()
        let config = AppConfiguration.shared
        XCTAssertTrue(validator.validate(
            center: CGPoint(x: 0.5 + config.faceCenterTolerance,
                            y: 0.5 - config.faceCenterTolerance),
            scale: config.faceScaleMin
        ).isEmpty)
        XCTAssertTrue(validator.validate(center: CGPoint(x: 0.5, y: 0.5),
                                         scale: config.faceScaleMax).isEmpty)
    }

    func testFramingJustOutsideEachBoundaryFails() {
        let validator = FramingValidator()
        let config = AppConfiguration.shared
        XCTAssertEqual(validator.validate(
            center: CGPoint(x: 0.5 + config.faceCenterTolerance + 0.0001, y: 0.5),
            scale: 0.35
        ), [.poorFraming])
        XCTAssertEqual(validator.validate(center: CGPoint(x: 0.5, y: 0.5),
                                          scale: config.faceScaleMin - 0.0001),
                       [.poorFraming])
    }

    func testPoseThresholdIsInclusiveAndExceedingItFails() {
        let validator = PoseValidator()
        XCTAssertTrue(validator.validate(HeadPose(yawDegrees: 12, pitchDegrees: -12,
                                                  rollDegrees: 12)).isEmpty)
        XCTAssertEqual(validator.validate(HeadPose(yawDegrees: 12.001, pitchDegrees: 0,
                                                   rollDegrees: 0)),
                       [.poseOutOfRange])
    }

    func testTimestampGapThresholdIsInclusiveAtMaximumAndRejectsNonPositive() {
        let validator = SignalPlausibilityValidator()
        let previous = TestFixtures.frame(timestamp: 1, raw: ["a": 0])
        XCTAssertTrue(validator.validate(previous: previous, currentRaw: ["a": 0],
                                         timestamp: 1.15).isEmpty)
        XCTAssertEqual(validator.validate(previous: previous, currentRaw: ["a": 0],
                                          timestamp: 1),
                       [.invalidTimestampGap])
        XCTAssertEqual(validator.validate(previous: previous, currentRaw: ["a": 0],
                                          timestamp: 1.151),
                       [.invalidTimestampGap])
    }

    func testSignalSpikeBoundaryIsExclusiveAndEmptySignalIsMissing() {
        let validator = SignalPlausibilityValidator()
        let previous = TestFixtures.frame(timestamp: 0, raw: ["a": 0])
        XCTAssertTrue(validator.validate(previous: previous, currentRaw: ["a": 0.55],
                                         timestamp: 0.1).isEmpty)
        XCTAssertEqual(validator.validate(previous: previous, currentRaw: ["a": 0.551],
                                          timestamp: 0.1),
                       [.signalSpike])
        XCTAssertEqual(validator.validate(previous: nil, currentRaw: [:], timestamp: 0),
                       [.missingBlendshapeValue])
    }

    func testQualityControlEnginePassesCleanSyntheticContext() {
        let context = QualityControlContext(
            faceCount: 1, trackingState: "Tracking",
            faceCenter: CGPoint(x: 0.5, y: 0.5), faceScale: 0.35,
            pose: HeadPose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0),
            rawBlendshapes: ["mouthSmileLeft": 0.1], timestamp: 1,
            isNeutralPhase: false
        )
        let result = QualityControlEngine().evaluate(current: context, previous: nil)
        XCTAssertTrue(result.valid)
        XCTAssertTrue(result.flags.isEmpty)
    }

    func testQualityControlEngineNeutralActivationBoundaryIsExclusive() {
        func result(_ activation: Double) -> QualityControlEvaluation {
            QualityControlEngine().evaluate(
                current: QualityControlContext(
                    faceCount: 1, trackingState: "Tracking",
                    faceCenter: CGPoint(x: 0.5, y: 0.5), faceScale: 0.35,
                    pose: HeadPose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0),
                    rawBlendshapes: ["a": activation], timestamp: 1, isNeutralPhase: true
                ),
                previous: nil
            )
        }
        XCTAssertFalse(result(0.15).flags.contains(.facialActivationTooHighAtNeutral))
        let warningResult = result(0.151)
        XCTAssertTrue(warningResult.flags.contains(.facialActivationTooHighAtNeutral))
        XCTAssertEqual(warningResult.warningFlags, [.facialActivationTooHighAtNeutral])
        XCTAssertTrue(warningResult.invalidatingFlags.isEmpty)
        XCTAssertTrue(warningResult.valid)
    }

    func testNeutralActivationWarningDoesNotOverrideHardTrackingFailure() {
        let result = QualityControlEngine().evaluate(
            current: QualityControlContext(
                faceCount: 0, trackingState: "limited",
                faceCenter: CGPoint(x: 0.5, y: 0.5), faceScale: 0.35,
                pose: HeadPose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0),
                rawBlendshapes: ["a": 0.151], timestamp: 1, isNeutralPhase: true
            ),
            previous: nil
        )
        XCTAssertTrue(result.warningFlags.contains(.facialActivationTooHighAtNeutral))
        XCTAssertTrue(result.invalidatingFlags.contains(.trackingLost))
        XCTAssertFalse(result.valid)
    }

    func testQualityControlEngineOcclusionUsesStrictLowerBoundary() {
        let scale = AppConfiguration.shared.faceScaleMin * 0.8
        let context = QualityControlContext(
            faceCount: 1, trackingState: "Tracking",
            faceCenter: CGPoint(x: 0.5, y: 0.5), faceScale: scale,
            pose: HeadPose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0),
            rawBlendshapes: ["a": 0], timestamp: 1, isNeutralPhase: false
        )
        XCTAssertFalse(QualityControlEngine().evaluate(current: context, previous: nil)
            .flags.contains(.likelyOcclusion))
    }

    func testHoldValidatorRequiresContiguousDurationAndThresholdIsInclusive() {
        let validator = HoldValidator()
        XCTAssertTrue(validator.validate(signal: [0.35, 0.35, 0.35],
                                         timestamps: [0, 1, 2],
                                         threshold: 0.35,
                                         requiredDuration: 2).isEmpty)
        XCTAssertEqual(validator.validate(signal: [0.4, 0.1, 0.4],
                                          timestamps: [0, 1, 2],
                                          threshold: 0.35,
                                          requiredDuration: 2),
                       [.holdNotMaintained])
    }

    func testHoldValidatorRejectsInsufficientOrMissingSamples() {
        let validator = HoldValidator()
        XCTAssertEqual(validator.validate(signal: [0.4, 0.4], timestamps: [0, 1],
                                          threshold: 0.35, requiredDuration: 2),
                       [.holdNotMaintained])
        XCTAssertEqual(validator.validate(signal: [], timestamps: [],
                                          threshold: 0.35, requiredDuration: 2),
                       [.notEnoughFrames])
    }
}
