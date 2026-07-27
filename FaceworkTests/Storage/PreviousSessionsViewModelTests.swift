import XCTest
@testable import Facework

@MainActor
final class PreviousSessionsViewModelTests: XCTestCase {
    func testLegacyAndCurrentMetadataLoadWhileMalformedMetadataIsIsolated() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let participant = directory.url.appendingPathComponent(
            "SYNTHETIC-PARTICIPANT",
            isDirectory: true
        )
        let currentFolder = participant.appendingPathComponent("current", isDirectory: true)
        let legacyFolder = participant.appendingPathComponent("legacy", isDirectory: true)
        let malformedFolder = participant.appendingPathComponent("malformed", isDirectory: true)
        try FileManager.default.createDirectory(
            at: currentFolder,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: legacyFolder,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: malformedFolder,
            withIntermediateDirectories: true
        )

        try JSONExporter().export(
            TestFixtures.metadata(),
            to: currentFolder.appendingPathComponent("metadata.json")
        )
        try SessionMetadataCompatibilityTests.legacyJSON.write(
            to: legacyFolder.appendingPathComponent("metadata.json")
        )
        try Data("{malformed".utf8).write(
            to: malformedFolder.appendingPathComponent("metadata.json")
        )

        let result = PreviousSessionMetadataLoader().load(from: directory.url)

        XCTAssertEqual(result.sessionFolders.count, 3)
        XCTAssertEqual(result.metadataBySessionFolder.count, 2)
        XCTAssertEqual(result.malformedMetadataFolders, [malformedFolder])
        XCTAssertFalse(
            try XCTUnwrap(result.metadataBySessionFolder[currentFolder])
                .wasLoadedFromLegacySchema
        )
        XCTAssertTrue(
            try XCTUnwrap(result.metadataBySessionFolder[legacyFolder])
                .wasLoadedFromLegacySchema
        )
    }
}
