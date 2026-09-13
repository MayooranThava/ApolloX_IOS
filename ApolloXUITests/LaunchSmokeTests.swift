//
//  LaunchSmokeTests.swift
//  ApolloXUITests
//

import XCTest

final class LaunchSmokeTests: XCTestCase {
    func testLaunchShowsTitleScene() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), "Void Runner should finish launching")
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5), "key window should exist")

        let titleScene = app.descendants(matching: .any)["titleScene"]
        XCTAssertTrue(
            titleScene.waitForExistence(timeout: 8),
            "GameTitleScene should be on screen after launch"
        )
    }

    func testLaunchStaysOnTitleWithoutCrashing() {
        let app = XCUIApplication()
        app.launch()

        let titleScene = app.descendants(matching: .any)["titleScene"]
        XCTAssertTrue(titleScene.waitForExistence(timeout: 8), "title should be the first scene")
        XCTAssertFalse(
            app.descendants(matching: .any)["Special weapon"].waitForExistence(timeout: 1),
            "special hardpoint belongs in a run, not on the title"
        )
        XCTAssertEqual(app.state, .runningForeground)
    }
}
