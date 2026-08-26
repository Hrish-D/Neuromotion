import XCTest
@testable import Facework

final class RepetitionCompletionCueTests: XCTestCase {
    func testNewValidRepetitionRequestsOneCue() {
        let player = CuePlayerSpy()
        let trigger = RepetitionCompletionCueTrigger(player: player)

        trigger.handle(TestFixtures.repetition(index: 1))

        XCTAssertEqual(player.playCount, 1)
    }

    func testSameCompletedRepetitionDoesNotRequestAnotherCue() {
        let player = CuePlayerSpy()
        let trigger = RepetitionCompletionCueTrigger(player: player)
        let result = TestFixtures.repetition(index: 1)

        trigger.handle(result)
        trigger.handle(result)

        XCTAssertEqual(player.playCount, 1)
    }

    func testSecondCompletedRepetitionRequestsOneNewCue() {
        let player = CuePlayerSpy()
        let trigger = RepetitionCompletionCueTrigger(player: player)

        trigger.handle(TestFixtures.repetition(index: 1))
        trigger.handle(TestFixtures.repetition(index: 2))

        XCTAssertEqual(player.playCount, 2)
    }

    func testInvalidRepetitionDoesNotRequestCue() {
        let player = CuePlayerSpy()
        let trigger = RepetitionCompletionCueTrigger(player: player)

        trigger.handle(TestFixtures.repetition(index: 1, valid: false))

        XCTAssertEqual(player.playCount, 0)
    }

    func testPlaybackFailureIsSwallowedAndDoesNotMutateResult() {
        let player = CuePlayerSpy(error: CuePlayerError.failed)
        let trigger = RepetitionCompletionCueTrigger(player: player)
        let result = TestFixtures.repetition(index: 1)

        trigger.handle(result)
        trigger.handle(result)

        XCTAssertTrue(result.valid)
        XCTAssertEqual(result.repetitionIndex, 1)
        XCTAssertEqual(player.playCount, 1)
    }
}

private enum CuePlayerError: Error {
    case failed
}

nonisolated private final class CuePlayerSpy: RepetitionCompletionCuePlaying {
    private(set) var playCount = 0
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func play() throws {
        playCount += 1
        if let error { throw error }
    }
}
