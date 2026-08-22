import Foundation
import XCTest
@testable import Facework

@MainActor
final class ValidationImageSynchronizationTests: XCTestCase {
    func testSuccessfulWriteProducesExactSameFrameAssociation() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let source = source(timestamp: 42.11665, imageID: "image-A")

        let association = ImageCaptureService().saveValidationImage(
            from: source,
            named: "validation_smile_showing_teeth_rep_1_frame_0000",
            in: directory.url
        )

        XCTAssertEqual(association.imageSourceTimestamp, 42.11665)
        XCTAssertEqual(association.synchronizationStatus, .sameARFrame)
        XCTAssertNotNil(association.reference)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(association.reference)))
    }

    func testWriteFailurePreservesRawMeasurementAndDoesNotClaimSynchronization() throws {
        let rawBefore = raw(association: nil)
        let directory = try TemporaryDirectory(testName: #function)
        let nonexistentFolder = directory.url.appendingPathComponent("missing/child", isDirectory: true)

        let association = ImageCaptureService().saveValidationImage(
            from: source(timestamp: rawBefore.sourceTimestamp, imageID: "image-A"),
            named: "validation_failure",
            in: nonexistentFolder
        )
        let rawAfter = raw(association: association)

        XCTAssertEqual(association.synchronizationStatus, .writeFailed)
        XCTAssertNil(association.reference)
        XCTAssertEqual(rawAfter.rawBlendshapes, rawBefore.rawBlendshapes)
        XCTAssertEqual(rawAfter.sourceTimestamp, rawBefore.sourceTimestamp)
        XCTAssertEqual(rawAfter.validationImageSynchronizationStatus, .writeFailed)
    }

    func testManifestMakesSameFrameIdentityExternallyAuditable() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let url = directory.url.appendingPathComponent("manifest.csv")
        let frame = FrameCapture(
            raw: raw(association: ValidationImageAssociation(
                reference: "/synthetic/validation.jpg",
                imageSourceTimestamp: 10.11665,
                synchronizationStatus: .sameARFrame
            )),
            analysis: FrameAnalysis(normalizedBlendshapes: [:], smoothedBlendshapes: [:], qcFlags: [], isValidFrame: true)
        )

        try CSVExporter().exportImageManifest([frame], to: url)
        let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[1].contains(frame.id.uuidString))
        XCTAssertTrue(lines[1].contains(try XCTUnwrap(frame.raw.recordingID).uuidString))
        XCTAssertTrue(lines[1].contains("10.11665,10.11665,sameARFrame"))
    }

    func testFailedWriteManifestHasNoImagePathAndDoesNotClaimSameFrame() throws {
        let directory = try TemporaryDirectory(testName: #function)
        let url = directory.url.appendingPathComponent("manifest.csv")
        let frame = FrameCapture(
            raw: raw(association: ValidationImageAssociation(
                reference: nil,
                imageSourceTimestamp: 10.11665,
                synchronizationStatus: .writeFailed
            )),
            analysis: FrameAnalysis(normalizedBlendshapes: [:], smoothedBlendshapes: [:], qcFlags: [], isValidFrame: true)
        )

        try CSVExporter().exportImageManifest([frame], to: url)
        let row = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")[1]
        let columns = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)

        XCTAssertEqual(columns[0], "smileTeeth")
        XCTAssertEqual(columns[5], "")
        XCTAssertEqual(columns[6], "")
        XCTAssertTrue(row.hasSuffix("10.11665,10.11665,writeFailed"))
        XCTAssertFalse(row.contains("sameARFrame"))
    }

    func testLegacyImageReferenceDecodesAsLegacyUnverified() throws {
        let legacy = raw(association: nil, legacyReference: "/legacy/validation.jpg")
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any]
        )
        object.removeValue(forKey: "validationImageSourceTimestamp")
        object.removeValue(forKey: "validationImageSynchronizationStatus")

        let decoded = try JSONDecoder().decode(
            RawFrameCapture.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertEqual(decoded.validationImageReference, "/legacy/validation.jpg")
        XCTAssertNil(decoded.validationImageSourceTimestamp)
        XCTAssertNil(decoded.validationImageSynchronizationStatus)
        XCTAssertEqual(decoded.effectiveValidationImageSynchronizationStatus, .legacyUnverified)
    }

    func testCurrentRawAssociationRoundTripsWithoutChangingMeasurement() throws {
        let original = raw(association: ValidationImageAssociation(
            reference: "/synthetic/validation.jpg",
            imageSourceTimestamp: 10.11665,
            synchronizationStatus: .sameARFrame
        ))

        let decoded = try JSONDecoder().decode(RawFrameCapture.self, from: JSONEncoder().encode(original))

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.rawBlendshapes, ["jawOpen": 0.4])
    }

    private func source(timestamp: TimeInterval, imageID: String) -> ValidationImageSource {
        ValidationImageSource(
            sourceTimestamp: timestamp,
            payload: .encodedImageData(Data(imageID.utf8), identifier: imageID)
        )
    }

    private func raw(
        association: ValidationImageAssociation?,
        legacyReference: String? = nil
    ) -> RawFrameCapture {
        RawFrameCapture(
            id: TestFixtures.deterministicUUID(800),
            recordingID: TestFixtures.deterministicUUID(801),
            frameIndex: 0,
            sourceTimestamp: 10.11665,
            taskType: .smileTeeth,
            repetitionIndex: 1,
            rawBlendshapes: ["jawOpen": 0.4],
            faceTransform: nil,
            headPose: HeadPose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0),
            faceIsPresent: true,
            visibleFaceCount: 1,
            faceTrackingState: .tracking,
            faceCenter: CGPoint(x: 0.5, y: 0.5),
            faceScale: 0.35,
            cameraTrackingStateAtCapture: "Tracking",
            isNeutralPhase: false,
            validationImageReference: association?.reference ?? legacyReference,
            validationImageSourceTimestamp: association?.imageSourceTimestamp,
            validationImageSynchronizationStatus: association?.synchronizationStatus
        )
    }
}
