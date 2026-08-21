import XCTest
@testable import Facework

@MainActor
final class SessionMetadataCompatibilityTests: XCTestCase {
    func testCurrentMetadataRoundTripPreservesEveryField() throws {
        let metadata = TestFixtures.metadata()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(
            SessionMetadata.self,
            from: encoder.encode(metadata)
        )

        XCTAssertEqual(decoded, metadata)
        XCTAssertFalse(decoded.wasLoadedFromLegacySchema)
    }

    func testLegacyMetadataPreservesOldFieldsAndUsesLegacyDefaults() throws {
        let metadata = try decodeLegacyMetadata()

        XCTAssertEqual(metadata.sessionID, "legacy-session")
        XCTAssertEqual(metadata.studyID, "SYNTHETIC-LEGACY-STUDY")
        XCTAssertEqual(metadata.participantID, "SYNTHETIC-LEGACY-001")
        XCTAssertEqual(metadata.raterID, "SYNTHETIC-LEGACY-RATER")
        XCTAssertEqual(metadata.appVersion, "0.9.0")
        XCTAssertEqual(metadata.deviceModel, "Legacy Synthetic Device")
        XCTAssertEqual(metadata.osVersion, "16.0")
        XCTAssertEqual(metadata.sessionDate, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(metadata.notes, "Synthetic legacy fixture")
        XCTAssertEqual(metadata.affectedSide, .left)
        XCTAssertEqual(metadata.sessionLabel, "Legacy Synthetic Session")

        XCTAssertEqual(metadata.appMarketingVersion, "legacy-unknown")
        XCTAssertEqual(metadata.appBuildNumber, "legacy-unknown")
        XCTAssertEqual(metadata.rawDataSchemaVersion, "legacy-unknown")
        XCTAssertEqual(metadata.analysisAlgorithmVersion, "legacy-unknown")
        XCTAssertEqual(metadata.captureProtocolVersion, "legacy-unknown")
        XCTAssertEqual(metadata.meshCaptureVersion, "not-active")
        XCTAssertEqual(metadata.landmarkConfigurationVersion, "not-active")
        XCTAssertEqual(metadata.deviceModelIdentifier, "not-recorded")
        XCTAssertEqual(metadata.operatingSystemName, "not-recorded")
        XCTAssertEqual(metadata.operatingSystemVersion, "not-recorded")
        XCTAssertTrue(metadata.wasLoadedFromLegacySchema)
    }

    func testLegacyMetadataDoesNotEncodeMigrationMarker() throws {
        let metadata = try decodeLegacyMetadata()
        let data = try JSONEncoder().encode(metadata)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertNil(object["wasLoadedFromLegacySchema"])
    }

    func testHistoricalAnalysisAndCaptureVersionsAreNotUpgradedWhenDecoded() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(TestFixtures.metadata()))
                as? [String: Any]
        )
        object["analysisAlgorithmVersion"] = "0.2.0"
        object["captureProtocolVersion"] = "0.1.0"

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(
            SessionMetadata.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertEqual(decoded.analysisAlgorithmVersion, "0.2.0")
        XCTAssertEqual(decoded.captureProtocolVersion, "0.1.0")
        XCTAssertFalse(decoded.wasLoadedFromLegacySchema)
    }

    private func decodeLegacyMetadata() throws -> SessionMetadata {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SessionMetadata.self, from: Self.legacyJSON)
    }

    static let legacyJSON = Data(
        """
        {
          "sessionID": "legacy-session",
          "studyID": "SYNTHETIC-LEGACY-STUDY",
          "participantID": "SYNTHETIC-LEGACY-001",
          "raterID": "SYNTHETIC-LEGACY-RATER",
          "appVersion": "0.9.0",
          "deviceModel": "Legacy Synthetic Device",
          "osVersion": "16.0",
          "sessionDate": "2023-11-14T22:13:20Z",
          "notes": "Synthetic legacy fixture",
          "affectedSide": "left",
          "sessionLabel": "Legacy Synthetic Session"
        }
        """.utf8
    )
}
