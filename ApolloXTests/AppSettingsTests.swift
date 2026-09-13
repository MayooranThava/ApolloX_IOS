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
        XCTAssertTrue(AppSettings.musicEnabled)
        XCTAssertEqual(AppSettings.musicVolume, 0.55, accuracy: 0.01)
        XCTAssertEqual(AppSettings.sfxVolume, 1.0, accuracy: 0.01)
        XCTAssertFalse(AppSettings.hasCompletedOnboarding)
    }

    func testTogglesPersist() {
        AppSettings.soundEnabled = false
        AppSettings.hapticsEnabled = false
        AppSettings.musicEnabled = false
        AppSettings.musicVolume = 0.25
        AppSettings.sfxVolume = 0.5
        AppSettings.hasCompletedOnboarding = true

        XCTAssertFalse(AppSettings.soundEnabled)
        XCTAssertFalse(AppSettings.hapticsEnabled)
        XCTAssertFalse(AppSettings.musicEnabled)
        XCTAssertEqual(AppSettings.musicVolume, 0.25, accuracy: 0.01)
        XCTAssertEqual(AppSettings.sfxVolume, 0.5, accuracy: 0.01)
        XCTAssertTrue(AppSettings.hasCompletedOnboarding)
    }

    func testLegalURLsAreHTTPS() {
        XCTAssertEqual(AppSettings.privacyPolicyURL.scheme, "https")
        XCTAssertEqual(AppSettings.supportURL.scheme, "https")
        XCTAssertEqual(AppSettings.classicLeaderboardDisplayName, "High Score")
    }

    func testSettingsLayoutKeepsLinksOffHapticsOnIPhone13() {
        // Scene-space safe area for 1536×2732 aspectFill on iPhone 13 (390×844).
        let safe = CGRect(x: 181, y: 134, width: 1174, height: 2418)
        let place = SettingsLayout.positions(in: safe)

        XCTAssertGreaterThan(
            place.haptics - place.howToPlay,
            SettingsLayout.minimumControlGap,
            "How to Play must sit below Haptics, not on top of it"
        )
        XCTAssertGreaterThan(place.howToPlay - place.privacy, SettingsLayout.minimumControlGap)
        XCTAssertGreaterThan(place.privacy - place.support, SettingsLayout.minimumControlGap)
        XCTAssertGreaterThan(place.support - place.back, SettingsLayout.minimumControlGap)
        XCTAssertGreaterThan(place.title - place.sound, 90)

        let centers = place.controlCenters
        for index in 0..<(centers.count - 1) {
            XCTAssertGreaterThan(
                centers[index] - centers[index + 1],
                SettingsLayout.minimumControlGap,
                "settings row \(index) overlaps the next control"
            )
        }

        // The old midY-pinned links collided with the toggle stack on this size.
        let oldHowToPlay = safe.midY - 120
        XCTAssertGreaterThan(
            abs(place.haptics - oldHowToPlay),
            1,
            "layout must not keep the old midY How to Play pin"
        )
        XCTAssertNotEqual(place.howToPlay, oldHowToPlay)
    }

    func testSettingsLayoutFitsShorterSafeArea() {
        let safe = CGRect(x: 80, y: 80, width: 1000, height: 1800)
        let place = SettingsLayout.positions(in: safe)
        XCTAssertGreaterThan(place.support, place.back + SettingsLayout.minimumControlGap)
        XCTAssertLessThan(place.sound, place.title - 90)
        for index in 0..<(place.controlCenters.count - 1) {
            XCTAssertGreaterThan(
                place.controlCenters[index] - place.controlCenters[index + 1],
                SettingsLayout.minimumControlGap
            )
        }
    }
}
