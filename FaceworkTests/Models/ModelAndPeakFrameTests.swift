import XCTest
@testable import Facework

final class ModelAndPeakFrameTests: XCTestCase {
    func testDeterministicFixtureBuildersUseExplicitValues() {
        let frames = TestFixtures.asymmetricMovementFrames()
        XCTAssertEqual(frames.map(\.timestamp), [0, 0.1, 0.2])
        XCTAssertEqual(frames[2].normalizedBlendshapes["mouthSmileLeft"], 0.8)
        XCTAssertEqual(frames[2].normalizedBlendshapes["mouthSmileRight"], 0.4)
    }

    func testInvalidFixtureBuildersCarryExpectedFlags() {
        XCTAssertTrue(TestFixtures.invalidTrackingFrames().allSatisfy {
            !$0.isValidFrame && $0.qcFlags == [.trackingLost]
        })
        XCTAssertTrue(TestFixtures.invalidFramingFrames().allSatisfy {
            !$0.isValidFrame && $0.qcFlags == [.poorFraming]
        })
        XCTAssertTrue(TestFixtures.excessivePoseFrames().allSatisfy {
            !$0.isValidFrame && $0.qcFlags == [.poseOutOfRange]
        })
    }

    func testPeakFrameFinderSelectsHighestValidSmoothedSignal() {
        let frames = [
            TestFixtures.frame(index: 0, task: .smileClosed,
                               raw: ["mouthSmileLeft": 0.1],
                               smoothed: ["mouthSmileLeft": 0.1]),
            TestFixtures.frame(index: 1, timestamp: 0.1, task: .smileClosed,
                               raw: ["mouthSmileLeft": 0.9],
                               smoothed: ["mouthSmileLeft": 0.9]),
            TestFixtures.frame(index: 2, timestamp: 0.2, task: .smileClosed,
                               raw: ["mouthSmileLeft": 1],
                               smoothed: ["mouthSmileLeft": 1], valid: false)
        ]
        let peak = PeakFrameFinder().findPeak(task: .smileClosed, frames: frames)
        XCTAssertEqual(peak?.frame.frameIndex, 1)
        XCTAssertEqual(peak?.signalValue, 0.9)
    }

    func testNeutralTaskHasNoPeakCandidate() {
        XCTAssertNil(PeakFrameFinder().findPeak(
            task: .neutralRest,
            frames: [TestFixtures.frame(raw: ["mouthSmileLeft": 1])]
        ))
    }
}
