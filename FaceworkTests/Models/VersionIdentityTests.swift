import XCTest
@testable import Facework

@MainActor
final class VersionIdentityTests: XCTestCase {
    func testBundleMarketingVersionAndBuildNumber() {
        let information = AppBuildInformation.from(infoDictionary: [
            "CFBundleShortVersionString": "2.3.4",
            "CFBundleVersion": "567"
        ])

        XCTAssertEqual(information.marketingVersion, "2.3.4")
        XCTAssertEqual(information.buildNumber, "567")
    }

    func testMissingBundleValuesUseExplicitFallbacks() {
        XCTAssertEqual(
            AppBuildInformation.from(infoDictionary: [:]),
            AppBuildInformation(
                marketingVersion: "unknown-version",
                buildNumber: "unknown-build"
            )
        )
        XCTAssertEqual(
            AppBuildInformation.from(infoDictionary: [
                "CFBundleShortVersionString": " ",
                "CFBundleVersion": ""
            ]),
            AppBuildInformation(
                marketingVersion: "unknown-version",
                buildNumber: "unknown-build"
            )
        )
    }

    func testDisplayVersion() {
        let information = AppBuildInformation(marketingVersion: "1.2", buildNumber: "34")
        XCTAssertEqual(information.displayVersion, "1.2 (34)")
    }

    func testCurrentResearchDataVersionsAreCentralizedAndAccurate() {
        XCTAssertEqual(
            ResearchDataVersions.current,
            ResearchDataVersions(
                rawDataSchemaVersion: "4.0.0",
                analysisAlgorithmVersion: "0.3.0",
                captureProtocolVersion: "0.4.0",
                meshCaptureVersion: "1.0.0",
                landmarkConfigurationVersion: "not-active"
            )
        )
    }

    func testMetadataFactoryUsesInjectedBuildResearchAndDeviceInformation() {
        let factory = SessionMetadataFactory(
            buildInformation: AppBuildInformation(
                marketingVersion: "3.2.1",
                buildNumber: "42"
            ),
            researchDataVersions: ResearchDataVersions(
                rawDataSchemaVersion: "schema-test",
                analysisAlgorithmVersion: "analysis-test",
                captureProtocolVersion: "protocol-test",
                meshCaptureVersion: "mesh-test",
                landmarkConfigurationVersion: "landmark-test"
            ),
            deviceInformation: DeviceInformation(
                modelIdentifier: "SyntheticDevice2,1",
                operatingSystemName: "SyntheticOS",
                operatingSystemVersion: "17.6"
            )
        )
        let metadata = factory.make(
            sessionID: "00000000-0000-0000-0000-000000000099",
            studyID: "SYNTHETIC-STUDY",
            participantID: "SYNTHETIC-001",
            raterID: nil,
            sessionDate: Date(timeIntervalSince1970: 1_700_000_099),
            notes: nil,
            affectedSide: .none,
            sessionLabel: nil
        )

        XCTAssertEqual(metadata.appVersion, "3.2.1")
        XCTAssertEqual(metadata.appMarketingVersion, "3.2.1")
        XCTAssertEqual(metadata.appBuildNumber, "42")
        XCTAssertEqual(metadata.rawDataSchemaVersion, "schema-test")
        XCTAssertEqual(metadata.analysisAlgorithmVersion, "analysis-test")
        XCTAssertEqual(metadata.captureProtocolVersion, "protocol-test")
        XCTAssertEqual(metadata.meshCaptureVersion, "mesh-test")
        XCTAssertEqual(metadata.landmarkConfigurationVersion, "landmark-test")
        XCTAssertEqual(metadata.deviceModel, "SyntheticDevice2,1")
        XCTAssertEqual(metadata.deviceModelIdentifier, "SyntheticDevice2,1")
        XCTAssertEqual(metadata.osVersion, "17.6")
        XCTAssertEqual(metadata.operatingSystemName, "SyntheticOS")
        XCTAssertEqual(metadata.operatingSystemVersion, "17.6")
        XCTAssertFalse(metadata.wasLoadedFromLegacySchema)
    }

    func testAppConfigurationValuesRemainUnchangedWithoutCodableConformance() {
        let configuration = AppConfiguration.shared

        XCTAssertEqual(configuration.neutralCaptureDuration, 2.5)
        XCTAssertEqual(configuration.minimumValidFramePercentage, 0.85)
        XCTAssertEqual(configuration.smoothingWindow, 5)
        XCTAssertEqual(configuration.onsetSustainDurationSeconds, 0.3)
        XCTAssertEqual(configuration.maxFrameGapSeconds, 0.15)
        XCTAssertEqual(configuration.yawThresholdDegrees, 12)
        XCTAssertEqual(configuration.pitchThresholdDegrees, 12)
        XCTAssertEqual(configuration.rollThresholdDegrees, 12)
        XCTAssertEqual(configuration.neutralMaxBlendshapeActivation, 0.15)
        XCTAssertEqual(configuration.holdThresholdDefault, 0.35)
        XCTAssertEqual(configuration.onsetThresholdDefault, 0.20)
        XCTAssertEqual(configuration.signalSpikeDeltaThreshold, 0.55)
        XCTAssertTrue(configuration.enablePeakFrameImageCapture)
    }
}
