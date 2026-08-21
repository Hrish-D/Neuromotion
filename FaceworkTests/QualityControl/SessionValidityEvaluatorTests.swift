import XCTest
@testable import Facework

final class SessionValidityEvaluatorTests: XCTestCase {
    private let evaluator = SessionValidityEvaluator()
    private let tasks: [TaskType] = [.browRaise, .eyeClosure, .smileTeeth, .smileClosed, .lipPucker, .cheekPuff]

    func testCompleteSessionIsValid() {
        let result = evaluate(repetitions: repetitions(validCounts: Dictionary(uniqueKeysWithValues: tasks.map { ($0, 3) })))
        XCTAssertTrue(result.validForAnalysis)
        XCTAssertTrue(result.overallPassed)
    }

    func testCompleteSessionWithSeventeenOfEighteenValidRemainsValid() {
        var counts = Dictionary(uniqueKeysWithValues: tasks.map { ($0, 3) })
        counts[.smileTeeth] = 2
        XCTAssertTrue(evaluate(repetitions: repetitions(validCounts: counts)).validForAnalysis)
    }

    func testMissingRequiredTaskWithNoFramesIsInvalid() {
        var reps = repetitions(validCounts: Dictionary(uniqueKeysWithValues: tasks.map { ($0, 3) }))
        reps[.cheekPuff] = []
        let result = evaluate(repetitions: reps, omittedFrameTask: .cheekPuff)
        XCTAssertFalse(result.validForAnalysis)
        XCTAssertTrue(result.reasons.contains(.missingRequiredTask))
        XCTAssertTrue(result.reasons.contains(.incompleteProtocol))
    }

    func testRequiredTaskWithNoValidRepetitionIsInvalid() {
        var counts = Dictionary(uniqueKeysWithValues: tasks.map { ($0, 3) })
        counts[.lipPucker] = 0
        let result = evaluate(repetitions: repetitions(validCounts: counts))
        XCTAssertFalse(result.validForAnalysis)
        XCTAssertTrue(result.reasons.contains(.insufficientValidRepetitions))
    }

    func testCalibrationFailureInvalidatesOtherwiseCompleteSession() {
        let result = evaluate(
            calibrationEstablished: false,
            repetitions: repetitions(validCounts: Dictionary(uniqueKeysWithValues: tasks.map { ($0, 3) }))
        )
        XCTAssertFalse(result.validForAnalysis)
        XCTAssertTrue(result.reasons.contains(.calibrationUnavailable))
    }

    func testIncompletePhysicalLikeRunWithSomeFramesIsInvalid() {
        var reps: [TaskType: [RepetitionResult]] = [:]
        reps[.browRaise] = (1...3).map { TestFixtures.repetition(index: $0, task: .browRaise) }
        reps[.eyeClosure] = (1...3).map { TestFixtures.repetition(index: $0, task: .eyeClosure, valid: $0 <= 2) }
        let result = evaluate(repetitions: reps, presentFrameTasks: [.browRaise, .eyeClosure])
        XCTAssertFalse(result.validForAnalysis)
        XCTAssertTrue(result.reasons.contains(.missingRequiredTask))
    }

    private func repetitions(validCounts: [TaskType: Int]) -> [TaskType: [RepetitionResult]] {
        Dictionary(uniqueKeysWithValues: tasks.map { task in
            let validCount = validCounts[task] ?? 0
            return (task, (1...3).map {
                TestFixtures.repetition(index: $0, task: task, valid: $0 <= validCount)
            })
        })
    }

    private func evaluate(
        calibrationEstablished: Bool = true,
        repetitions: [TaskType: [RepetitionResult]],
        omittedFrameTask: TaskType? = nil,
        presentFrameTasks: Set<TaskType>? = nil
    ) -> QCSummary {
        let includedTasks = presentFrameTasks ?? Set(tasks.filter { $0 != omittedFrameTask })
        let frames = includedTasks.enumerated().map { offset, task in
            TestFixtures.frame(index: offset, timestamp: Double(offset), task: task,
                               raw: ["a": 0.2])
        }
        let configs = Dictionary(uniqueKeysWithValues: tasks.map { ($0, TaskConfiguration.default(for: $0)) })
        return evaluator.evaluate(
            calibrationEstablished: calibrationEstablished,
            requiredTasks: tasks,
            configurations: configs,
            repetitionsByTask: repetitions,
            frames: frames
        )
    }
}
