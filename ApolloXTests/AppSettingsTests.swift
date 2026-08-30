//
//  AppSettingsTests.swift
//  ApolloXTests
//

import XCTest
@testable import ApolloX

final class AppSettingsTests: XCTestCase {
    private var suiteName = ""

    override func setUp() {
        super.setUp()
        suiteName = "ApolloXTests.AppSettings.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("could not create isolated UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        ScoreStore.storage = defaults
        AppSettings.resetForTesting()
    }

    override func tearDown() {
        AppSettings.resetForTesting()
        ScoreStore.storage.removePersistentDomain(forName: suiteName)
        ScoreStore.storage = .standard
        super.tearDown()
    }

    func testDefaultsAreEnabledAndOnboardingIncomplete() {
        XCTAssertTrue(AppSettings.soundEnabled)
        XCTAssertTrue(AppSettings.hapticsEnabled)
        XCTAssertFalse(AppSettings.hasCompletedOnboarding)
    }

    func testTogglesPersist() {
        AppSettings.soundEnabled = false
        AppSettings.hapticsEnabled = false
        AppSettings.hasCompletedOnboarding = true

        XCTAssertFalse(AppSettings.soundEnabled)
        XCTAssertFalse(AppSettings.hapticsEnabled)
        XCTAssertTrue(AppSettings.hasCompletedOnboarding)
    }

    func testLegalURLsAreHTTPS() {
        XCTAssertEqual(AppSettings.privacyPolicyURL.scheme, "https")
        XCTAssertEqual(AppSettings.supportURL.scheme, "https")
        XCTAssertEqual(AppSettings.classicLeaderboardDisplayName, "High Score")
    }
}
