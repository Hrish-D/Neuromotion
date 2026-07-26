import XCTest
@testable import Facework

final class SymmetryCalculatorTests: XCTestCase {
    private let calculator = SymmetryCalculator()

    func testIdenticalPositiveValuesAreFullySymmetric() {
        XCTAssertEqual(calculator.symmetry(left: 0.8, right: 0.8), 1)
    }

    func testLeftGreaterAndRightGreaterAreEquivalent() {
        XCTAssertEqual(calculator.symmetry(left: 1, right: 0.5), 0.5)
        XCTAssertEqual(calculator.symmetry(left: 0.5, right: 1), 0.5)
    }

    func testOneZeroAndBothZero() {
        XCTAssertEqual(calculator.symmetry(left: 1, right: 0), 0)
        XCTAssertEqual(calculator.symmetry(left: 0, right: 0), 1)
    }

    func testNegativeNormalizedValuesUseAbsoluteDenominator() {
        assertOptionalEqual(calculator.symmetry(left: -0.2, right: -0.1), 0.5,
                            accuracy: 0.000_001)
    }

    func testVerySmallValuesUseEpsilonFloor() {
        assertOptionalEqual(calculator.symmetry(left: 0.000_000_1, right: 0),
                            0.9, accuracy: 0.000_001)
    }

    func testOutputIsClampedToLowerBoundAndNeverExceedsOneForFiniteInputs() {
        // Current task analysis compares independent side peaks, not simultaneous samples.
        let inputs: [(Double, Double)] = [(1, -1), (4, 1), (-3, 2), (0.2, 0.7)]
        for (left, right) in inputs {
            let value = try! XCTUnwrap(calculator.symmetry(left: left, right: right))
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThanOrEqual(value, 1)
        }
    }
}
