import XCTest
@testable import Facework

@MainActor
final class ExporterTests: XCTestCase {
    func testPerFrameHeaderAndBlendshapeColumnsAreDeterministicallySorted() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let url = directory.url.appendingPathComponent("frames.csv")
        let frames = [
            TestFixtures.frame(raw: ["z": 1, "a": 2], normalized: ["z": 1, "a": 2])
        ]

        try CSVExporter().exportFrames(frames, to: url)
        let header = try contents(url).components(separatedBy: "\n")[0]

        XCTAssertTrue(header.hasPrefix(
            "timestamp,frameIndex,task,repetition,trackingState,isValidFrame,qcFlags,imageReference,yawDegrees,pitchDegrees,rollDegrees"
        ))
        XCTAssertTrue(header.contains("raw_a,raw_z,normalized_a,normalized_z,smoothed_a,smoothed_z"))
    }

    func testPerRepetitionHeaderIsCurrentExpectedSchema() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let url = directory.url.appendingPathComponent("repetitions.csv")
        try CSVExporter().exportRepetitions([TestFixtures.repetition(index: 1)], to: url)

        let header = try contents(url).components(separatedBy: "\n")[0]
        XCTAssertEqual(
            header,
            "task,repetition,valid,partial,failureReason,startTime,endTime,peakAmplitudeLeft,peakAmplitudeRight,peakVelocityLeft,peakVelocityRight,symmetry,confidenceScore,peakFrameReference,peakFrameIndex,peakFrameTimestamp,peakSignalValue,sessionID,rawDataSchemaVersion,analysisAlgorithmVersion,captureProtocolVersion"
        )
    }

    func testCSVQuotesCommasQuotesAndLineBreaks() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let url = directory.url.appendingPathComponent("frames.csv")
        let frame = TestFixtures.frame(
            trackingState: "state,\"quoted\"\nnext",
            flags: [.signalSpike]
        )

        try CSVExporter().exportFrames([frame], to: url)
        let csv = try contents(url)
        XCTAssertTrue(csv.contains("\"state,\"\"quoted\"\"\nnext\""))
    }

    func testEmptyOptionalRepetitionValuesProduceEmptyCSVFields() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let url = directory.url.appendingPathComponent("repetitions.csv")
        let repetition = TestFixtures.repetition(
            index: 1, amplitudeLeft: nil, amplitudeRight: nil,
            peakVelocity: nil, timeToPeak: nil
        )

        try CSVExporter().exportRepetitions([repetition], to: url)
        let row = try contents(url).components(separatedBy: "\n")[1]
        XCTAssertTrue(row.contains(",,,,"))
        XCTAssertFalse(row.contains("Optional"))
    }

    func testImageManifestHasExpectedStructureAndOnlyImageFrames() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let url = directory.url.appendingPathComponent("manifest.csv")
        let absolutePath = directory.url.appendingPathComponent("validation.jpg").path
        let frames = [
            TestFixtures.frame(index: 0),
            TestFixtures.frame(index: 1, timestamp: 0.1, task: .smileClosed,
                               imageReference: absolutePath)
        ]

        try CSVExporter().exportImageManifest(frames, to: url)
        let lines = try contents(url).components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0],
                       "task,repetition,frameIndex,timestamp,isValidFrame,imageFileName,imageReference,sessionID,rawDataSchemaVersion,analysisAlgorithmVersion,captureProtocolVersion")
        XCTAssertTrue(lines[1].contains("validation.jpg"))
        XCTAssertTrue(lines[1].contains(absolutePath))
    }

    func testCurrentFrameExportPreservesAbsoluteImageReference() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let url = directory.url.appendingPathComponent("frames.csv")
        let absolutePath = directory.url.appendingPathComponent("image.jpg").path

        try CSVExporter().exportFrames(
            [TestFixtures.frame(imageReference: absolutePath)],
            to: url
        )
        XCTAssertTrue(try contents(url).contains(absolutePath))
    }

    func testJSONRoundTripPreservesSyntheticMetadata() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let url = directory.url.appendingPathComponent("metadata.json")
        let metadata = TestFixtures.metadata(notes: TestFixtures.multilineText)

        try JSONExporter().export(metadata, to: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SessionMetadata.self, from: Data(contentsOf: url))

        XCTAssertEqual(decoded, metadata)
    }

    func testJSONOutputUsesSortedKeysAndStableISODateEncoding() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let url = directory.url.appendingPathComponent("metadata.json")
        try JSONExporter().export(TestFixtures.metadata(), to: url)
        let json = try contents(url)

        XCTAssertLessThan(try XCTUnwrap(json.range(of: "\"affectedSide\"")?.lowerBound),
                          try XCTUnwrap(json.range(of: "\"appVersion\"")?.lowerBound))
        XCTAssertTrue(json.contains("2023-11-14T22:13:20Z"))
        XCTAssertTrue(json.contains("\"appMarketingVersion\" : \"9.8.7\""))
        XCTAssertTrue(json.contains("\"appBuildNumber\" : \"654\""))
        XCTAssertTrue(json.contains("\"rawDataSchemaVersion\" : \"test-schema\""))
        XCTAssertTrue(json.contains("\"analysisAlgorithmVersion\" : \"test-analysis\""))
        XCTAssertTrue(json.contains("\"captureProtocolVersion\" : \"test-protocol\""))
        XCTAssertTrue(json.contains("\"deviceModelIdentifier\" : \"SyntheticDevice1,1\""))
        XCTAssertTrue(json.contains("\"operatingSystemName\" : \"SyntheticOS\""))
        XCTAssertFalse(json.contains("wasLoadedFromLegacySchema"))
    }

    func testFrameJSONRoundTripPreservesAllCurrentDictionaries() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let url = directory.url.appendingPathComponent("frame.json")
        let frame = TestFixtures.frame(
            raw: ["a": 1],
            normalized: ["a": 0.8],
            smoothed: ["a": 0.7],
            flags: [.signalSpike],
            imageReference: "/synthetic/absolute/image.jpg"
        )

        try JSONExporter().export(frame, to: url)
        let decoded = try JSONDecoder().decode(FrameCapture.self, from: Data(contentsOf: url))
        XCTAssertEqual(decoded, frame)
    }

    func testCSVUnsafeSyntheticMetadataValuesRoundTripThroughJSON() throws {
        let directory = try TemporaryDirectory(testName: #function)
        for (index, value) in [
            TestFixtures.safeText,
            TestFixtures.commaText,
            TestFixtures.quoteText,
            TestFixtures.multilineText
        ].enumerated() {
            let url = directory.url.appendingPathComponent("metadata-\(index).json")
            let metadata = TestFixtures.metadata(notes: value)
            try JSONExporter().export(metadata, to: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            XCTAssertEqual(try decoder.decode(SessionMetadata.self,
                                              from: Data(contentsOf: url)).notes,
                           value)
        }
    }

    func testCSVExportsAppendDeterministicSessionVersionIdentity() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let metadata = TestFixtures.metadata()
        let frameURL = directory.url.appendingPathComponent("frames.csv")
        let repetitionURL = directory.url.appendingPathComponent("repetitions.csv")
        let manifestURL = directory.url.appendingPathComponent("manifest.csv")
        let frame = TestFixtures.frame(imageReference: "/synthetic/validation.jpg")

        let exporter = CSVExporter()
        try exporter.exportFrames([frame], metadata: metadata, to: frameURL)
        try exporter.exportRepetitions(
            [TestFixtures.repetition(index: 1)],
            metadata: metadata,
            to: repetitionURL
        )
        try exporter.exportImageManifest([frame], metadata: metadata, to: manifestURL)

        let expectedIdentity = [
            metadata.sessionID,
            metadata.rawDataSchemaVersion,
            metadata.analysisAlgorithmVersion,
            metadata.captureProtocolVersion
        ].joined(separator: ",")

        for url in [frameURL, repetitionURL, manifestURL] {
            let lines = try contents(url).components(separatedBy: "\n")
            XCTAssertTrue(lines[0].hasSuffix(
                "sessionID,rawDataSchemaVersion,analysisAlgorithmVersion,captureProtocolVersion"
            ))
            XCTAssertTrue(try XCTUnwrap(lines.last).hasSuffix(expectedIdentity))
        }
    }

    private func contents(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }
}
