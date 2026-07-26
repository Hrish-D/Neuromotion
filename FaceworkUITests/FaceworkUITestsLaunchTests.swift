//
//  FaceworkUITestsLaunchTests.swift
//  FaceworkUITests
//
//  Created by Hrish Dave on 2026-07-25.
//

import XCTest

final class FaceworkUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Facial Motion Baseline"].waitForExistence(timeout: 5))
    }
}
