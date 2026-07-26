import XCTest
@testable import Facework

final class VelocityCalculatorTests: XCTestCase {
    private let calculator = VelocityCalculator()

    func testConstantIncreasingSignal() {
        XCTAssertEqual(calculator.derivative(values: [0, 1, 2], timestamps: [0, 1, 2]), [0, 1, 1])
        XCTAssertEqual(calculator.peakVelocity(values: [0, 1, 2], timestamps: [0, 1, 2]), 1)
    }

    func testConstantDecreasingSignalPreservesSignedPeakBehavior() {
        XCTAssertEqual(calculator.derivative(values: [2, 1, 0], timestamps: [0, 1, 2]), [0, -1, -1])
        XCTAssertEqual(calculator.peakVelocity(values: [2, 1, 0], timestamps: [0, 1, 2]), 0)
    }

    func testConstantSignal() {
        XCTAssertEqual(calculator.derivative(values: [2, 2, 2], timestamps: [0, 1, 2]), [0, 0, 0])
    }

    func testIrregularTimestampSpacing() {
        XCTAssertEqual(calculator.derivative(values: [0, 1, 3], timestamps: [0, 0.5, 2]),
                       [0, 2, 4.0 / 3.0])
    }

    func testDuplicateAndDecreasingTimestampsYieldZeroDerivative() {
        XCTAssertEqual(calculator.derivative(values: [0, 1, 2], timestamps: [0, 0, -1]), [0, 0, 0])
    }

    func testOneSampleAndEmptySequence() {
        XCTAssertEqual(calculator.derivative(values: [1], timestamps: [0]), [])
        XCTAssertEqual(calculator.derivative(values: [], timestamps: []), [])
        XCTAssertNil(calculator.peakVelocity(values: [1], timestamps: [0]))
    }

    func testMeanActiveVelocityUsesProvidedActiveIndices() {
        assertOptionalEqual(calculator.meanActiveVelocity(values: [0, 1, 3],
                                                          timestamps: [0, 1, 2],
                                                          activeIndices: [1, 2]),
                            1.5, accuracy: 0.000_001)
    }
}
