//
//  ScoreStoreTests.swift
//  ApolloXTests
//

import XCTest
@testable import ApolloX

final class ScoreStoreTests: XCTestCase {
    private var suiteName = ""

    override func setUp() {
        super.setUp()
        suiteName = "ApolloXTests.ScoreStore.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("could not create isolated UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        ScoreStore.storage = defaults
        ScoreStore.resetCurrentScore()
        ScoreStore.highScoreReporter = { _ in }
    }

    override func tearDown() {
        ScoreStore.highScoreReporter = { GameCenterService.reportScore($0) }
        ScoreStore.storage.removePersistentDomain(forName: suiteName)
        ScoreStore.storage = .standard
        ScoreStore.resetCurrentScore()
        super.tearDown()
    }

    func testAddPointIncrementsCurrentScoreOnly() {
        XCTAssertEqual(ScoreStore.addPoint(1), 1)
        XCTAssertEqual(ScoreStore.addPoint(4), 5)
        XCTAssertEqual(ScoreStore.currentScore, 5)
        XCTAssertEqual(ScoreStore.highScore, 0, "in-run score must not write high score until commit")
    }

    func testCommitPersistsNewHighScore() {
        ScoreStore.addPoint(12)
        XCTAssertEqual(ScoreStore.commitHighScoreIfNeeded(), 12)
        XCTAssertEqual(ScoreStore.highScore, 12)

        ScoreStore.resetCurrentScore()
        XCTAssertEqual(ScoreStore.currentScore, 0)
        XCTAssertEqual(ScoreStore.highScore, 12, "high score must survive a new run")
    }

    func testCommitDoesNotLowerHighScore() {
        ScoreStore.addPoint(10)
        XCTAssertEqual(ScoreStore.commitHighScoreIfNeeded(), 10)

        ScoreStore.resetCurrentScore()
        ScoreStore.addPoint(3)
        XCTAssertEqual(ScoreStore.commitHighScoreIfNeeded(), 10)
        XCTAssertEqual(ScoreStore.highScore, 10)
    }
}
