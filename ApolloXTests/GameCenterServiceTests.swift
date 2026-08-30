//
//  GameCenterServiceTests.swift
//  ApolloXTests
//

import XCTest
import UIKit
@testable import ApolloX

final class GameCenterServiceTests: XCTestCase {
    private var suiteName = ""
    private var fake: FakeGameCenterBackend!
    private var reportedScores: [Int] = []

    override func setUp() {
        super.setUp()
        suiteName = "ApolloXTests.GameCenter.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("could not create isolated UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        ScoreStore.storage = defaults
        ScoreStore.resetCurrentScore()
        ScoreStore.highScoreReporter = { [weak self] score in
            self?.reportedScores.append(score)
        }

        GameCenterService.storage = defaults
        GameCenterService.resetForTesting()
        fake = FakeGameCenterBackend()
        GameCenterService.backend = fake
        reportedScores = []
    }

    override func tearDown() {
        GameCenterService.resetForTesting()
        GameCenterService.backend = LiveGameCenterBackend()
        GameCenterService.storage = .standard
        ScoreStore.highScoreReporter = { GameCenterService.reportScore($0) }
        ScoreStore.storage.removePersistentDomain(forName: suiteName)
        ScoreStore.storage = .standard
        ScoreStore.resetCurrentScore()
        fake = nil
        super.tearDown()
    }

    func testReportScoreQueuesWhenNotAuthenticated() {
        fake.authenticated = false
        GameCenterService.reportScore(120)

        XCTAssertEqual(fake.submittedScores, [])
        XCTAssertEqual(GameCenterService.storage.integer(forKey: "apolloX.pendingGameCenterScore"), 120)
    }

    func testReportScoreSubmitsWhenAuthenticated() {
        fake.authenticated = true
        GameCenterService.reportScore(250)

        let expect = expectation(description: "submit completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            expect.fulfill()
        }
        wait(for: [expect], timeout: 1)

        XCTAssertEqual(fake.submittedScores, [250])
        XCTAssertEqual(
            GameCenterService.storage.integer(forKey: "apolloX.pendingGameCenterScore"),
            0,
            "pending score should clear after successful submit"
        )
    }

    func testReportScoreKeepsHighestPending() {
        fake.authenticated = false
        GameCenterService.reportScore(40)
        GameCenterService.reportScore(90)
        GameCenterService.reportScore(70)
        XCTAssertEqual(GameCenterService.storage.integer(forKey: "apolloX.pendingGameCenterScore"), 90)
    }

    func testLoadTopEntriesRequiresAuth() {
        fake.authenticated = false
        let expect = expectation(description: "load fails")
        GameCenterService.loadTopEntries { result in
            switch result {
            case .failure(let error as GameCenterError):
                XCTAssertEqual(error, .notAuthenticated)
            default:
                XCTFail("expected notAuthenticated")
            }
            expect.fulfill()
        }
        wait(for: [expect], timeout: 1)
    }

    func testLoadTopEntriesReturnsBackendRows() {
        fake.authenticated = true
        fake.entries = [
            LeaderboardEntry(rank: 1, displayName: "Nova", score: 900, isLocalPlayer: false),
            LeaderboardEntry(rank: 2, displayName: "You", score: 400, isLocalPlayer: true)
        ]

        let expect = expectation(description: "load succeeds")
        GameCenterService.loadTopEntries { result in
            switch result {
            case .success(let entries):
                XCTAssertEqual(entries.count, 2)
                XCTAssertEqual(entries[0].displayName, "Nova")
                XCTAssertEqual(entries[1].isLocalPlayer, true)
            case .failure(let error):
                XCTFail("unexpected \(error)")
            }
            expect.fulfill()
        }
        wait(for: [expect], timeout: 1)
    }

    func testScoreStoreReportsBestOncePerRun() {
        ScoreStore.addPoint(15)
        XCTAssertEqual(ScoreStore.commitHighScoreIfNeeded(), 15)
        XCTAssertEqual(reportedScores, [15])

        XCTAssertEqual(ScoreStore.commitHighScoreIfNeeded(), 15)
        XCTAssertEqual(reportedScores, [15], "second commit in same run must not re-report")

        ScoreStore.resetCurrentScore()
        ScoreStore.addPoint(8)
        XCTAssertEqual(ScoreStore.commitHighScoreIfNeeded(), 15)
        XCTAssertEqual(reportedScores, [15, 15], "new run still reports local best for Game Center sync")
    }

    func testLeaderboardIDMatchesAppStoreConnectContract() {
        XCTAssertEqual(
            GameCenterService.classicHighScoreLeaderboardID,
            "com.mayooran.ApolloX.classicHighScore"
        )
        XCTAssertEqual(GameCenterService.classicHighScoreDisplayName, "High Score")
        XCTAssertEqual(GameCenterService.topEntryCount, 5)
    }
}

// MARK: - Fake backend

private final class FakeGameCenterBackend: GameCenterBackend {
    var authenticated = false
    var submittedScores: [Int] = []
    var entries: [LeaderboardEntry] = []
    var submitError: Error?
    private var authHandler: ((UIViewController?, Error?) -> Void)?

    var isAuthenticated: Bool { authenticated }

    func setAuthenticateHandler(_ handler: @escaping (UIViewController?, Error?) -> Void) {
        authHandler = handler
    }

    func submitScore(_ score: Int, leaderboardID: String, completion: @escaping (Error?) -> Void) {
        submittedScores.append(score)
        completion(submitError)
    }

    func loadTopEntries(
        leaderboardID: String,
        limit: Int,
        completion: @escaping (Result<[LeaderboardEntry], Error>) -> Void
    ) {
        completion(.success(Array(entries.prefix(limit))))
    }

    func makeLeaderboardViewController(leaderboardID: String) -> UIViewController {
        UIViewController()
    }

    func completeAuthentication(success: Bool) {
        authenticated = success
        authHandler?(nil, success ? nil : GameCenterError.notAuthenticated)
    }
}
