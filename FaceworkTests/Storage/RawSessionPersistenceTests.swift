import Foundation
import XCTest
@testable import Facework

@MainActor
final class RawSessionPersistenceTests: XCTestCase {
    func testSessionStoreProjectionWritesIndependentAuthoritativeRawFramesFile() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let frame = TestFixtures.frame(
            timestamp: 1.11665,
            raw: ["jawOpen": 0.4],
            normalized: ["jawOpen": 0.3],
            smoothed: ["jawOpen": 0.3],
            imageReference: "/synthetic/validation.jpg"
        )

        let rawURL = directory.url.appendingPathComponent(SessionStore.rawFramesFileName)
        try JSONExporter().export(SessionStore.authoritativeRawFrames(from: [frame]), to: rawURL)
        let rawFrames = try JSONDecoder().decode([RawFrameCapture].self, from: Data(contentsOf: rawURL))
        XCTAssertEqual(rawFrames, [frame.raw])
        XCTAssertEqual(rawFrames.first?.validationImageReference, frame.imageReference)
        XCTAssertEqual(rawURL.lastPathComponent, "raw_frames.json")
    }
}
