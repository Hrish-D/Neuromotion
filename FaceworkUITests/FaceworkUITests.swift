//
//  FaceworkUITests.swift
//  FaceworkUITests
//
//  Created by Hrish Dave on 2026-07-25.
//

import XCTest

final class FaceworkUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeScreenAppearsAfterLaunch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Facial Motion Baseline"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSessionSetupCanBeOpened() {
        let app = launchAndOpenSetup()
        XCTAssertTrue(app.navigationBars["New Session Setup"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRequiredFieldsControlContinueAvailability() {
        let app = launchAndOpenSetup()
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists)
        XCTAssertFalse(continueButton.isEnabled)

        app.textFields["Study ID"].tap()
        app.textFields["Study ID"].typeText("SYNTHETIC-STUDY")
        app.textFields["Participant ID"].tap()
        app.textFields["Participant ID"].typeText("SYNTHETIC-001")

        XCTAssertTrue(continueButton.isEnabled)
    }

    @MainActor
    func testSimulatorReadinessReportsUnsupportedTrueDepth() {
        let app = launchAndOpenSetup()
        addCameraPermissionHandler(to: app)

        app.textFields["Study ID"].tap()
        app.textFields["Study ID"].typeText("SYNTHETIC-STUDY")
        app.textFields["Participant ID"].tap()
        app.textFields["Participant ID"].typeText("SYNTHETIC-001")
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Device Readiness"].waitForExistence(timeout: 5))
        let unsupportedReason = app.staticTexts
            .containing(NSPredicate(format: "label CONTAINS %@", "Face tracking is not supported"))
            .firstMatch
        XCTAssertTrue(unsupportedReason.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Proceed to Neutral Baseline"].isEnabled)
    }

    @MainActor
    private func launchAndOpenSetup() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Facial Motion Baseline"].waitForExistence(timeout: 5))
        app.staticTexts["Start New Session"].tap()
        return app
    }

    @MainActor
    private func addCameraPermissionHandler(to app: XCUIApplication) {
        addUIInterruptionMonitor(withDescription: "Camera Permission") { alert in
            if alert.buttons["Don’t Allow"].exists {
                alert.buttons["Don’t Allow"].tap()
                return true
            }
            return false
        }
        app.tap()
    }
}
