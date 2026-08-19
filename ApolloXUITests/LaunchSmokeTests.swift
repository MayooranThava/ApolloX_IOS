//
//  LaunchSmokeTests.swift
//  ApolloXUITests
//

import XCTest

final class LaunchSmokeTests: XCTestCase {
    func testLaunchShowsTitleScene() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), "ApolloX should finish launching")
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5), "key window should exist")

        let titleScene = app.descendants(matching: .any)["titleScene"]
        XCTAssertTrue(
            titleScene.waitForExistence(timeout: 8),
            "GameTitleScene should be on screen after launch"
        )
    }
}
