//
//  GameCenterService.swift
//  ApolloX
//
//  Game Center auth, classic high-score submit, and top-5 fetch.
//  Follows Apple guidance: authenticate at launch, never block play when
//  Game Center is unavailable, submit best score, retry pending offline scores.
//

import Foundation
import GameKit
import UIKit

/// One row on the classic high-score board (Game Center or local placeholder).
struct LeaderboardEntry: Equatable {
    let rank: Int
    let displayName: String
    let score: Int
    let isLocalPlayer: Bool
}

enum GameCenterService {

    /// Must match the leaderboard ID created in App Store Connect → Game Center.
    static let classicHighScoreLeaderboardID = "com.mayooran.ApolloX.classicHighScore"

    /// Must match the App Store Connect localization name (avoids "*MISSING TITLE*").
    static let classicHighScoreDisplayName = AppSettings.classicLeaderboardDisplayName

    /// Public top-N shown in `LeaderboardScene`.
    static let topEntryCount = 5

    private static let pendingScoreKey = "apolloX.pendingGameCenterScore"

    /// Production uses `.standard`. Tests swap a suite so pending-score logic stays isolated.
    static var storage: UserDefaults = .standard

    /// Tests replace this with a no-op / stub so GameKit is never hit from XCTest.
    static var backend: GameCenterBackend = LiveGameCenterBackend()

    private(set) static var isAuthenticated = false
    private static var gameCenterDelegate: GameCenterViewControllerDelegate?

    // MARK: - Authentication

    /// Call at launch and before Game Center UI. Safe to call repeatedly; Apple expects
    /// the authenticate handler to be set each time the game becomes ready.
    static func authenticateAtLaunch() {
        backend.setAuthenticateHandler { viewController, error in
            DispatchQueue.main.async {
                if let viewController {
                    present(viewController)
                    return
                }

                if let error {
                    isAuthenticated = false
                    #if DEBUG
                    print("Game Center auth failed: \(error.localizedDescription)")
                    #endif
                    return
                }

                let wasAuthenticated = isAuthenticated
                isAuthenticated = backend.isAuthenticated
                if isAuthenticated {
                    flushPendingScoreIfPossible()
                    // One sync when the player first becomes authenticated this session.
                    if !wasAuthenticated {
                        let localBest = ScoreStore.highScore
                        if localBest > 0 {
                            reportScore(localBest)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Score reporting

    /// Reports the player's best score. Queues when offline / unsigned-in.
    static func reportScore(_ score: Int) {
        guard score > 0 else { return }

        let pending = max(storage.integer(forKey: pendingScoreKey), score)
        storage.set(pending, forKey: pendingScoreKey)

        guard isAuthenticated || backend.isAuthenticated else { return }
        isAuthenticated = true

        backend.submitScore(pending, leaderboardID: classicHighScoreLeaderboardID) { error in
            DispatchQueue.main.async {
                if let error {
                    #if DEBUG
                    print("Game Center score submit failed: \(error.localizedDescription)")
                    #endif
                    return
                }
                let stillPending = storage.integer(forKey: pendingScoreKey)
                if stillPending <= pending {
                    storage.removeObject(forKey: pendingScoreKey)
                }
            }
        }
    }

    static func flushPendingScoreIfPossible() {
        let pending = storage.integer(forKey: pendingScoreKey)
        guard pending > 0 else { return }
        reportScore(pending)
    }

    // MARK: - Leaderboard fetch

    static func loadTopEntries(completion: @escaping (Result<[LeaderboardEntry], Error>) -> Void) {
        guard isAuthenticated || backend.isAuthenticated else {
            completion(.failure(GameCenterError.notAuthenticated))
            return
        }
        isAuthenticated = true

        backend.loadTopEntries(
            leaderboardID: classicHighScoreLeaderboardID,
            limit: topEntryCount
        ) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /// Fetches the signed-in player's global rank on the classic board (nil when unranked).
    static func loadLocalPlayerRank(completion: @escaping (Int?) -> Void) {
        guard isAuthenticated || backend.isAuthenticated else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        isAuthenticated = true

        backend.loadLocalPlayerRank(leaderboardID: classicHighScoreLeaderboardID) { rank in
            DispatchQueue.main.async {
                if let rank, rank > 0 {
                    AppSettings.lastKnownGameCenterRank = rank
                    GameCenterAchievementService.checkRank(rank)
                }
                completion(rank)
            }
        }
    }

    // MARK: - Apple dashboard

    /// Presents Apple's Game Center leaderboard UI (App Review–friendly escape hatch).
    static func presentSystemLeaderboard() {
        guard isAuthenticated || backend.isAuthenticated else { return }
        isAuthenticated = true

        let viewController = backend.makeLeaderboardViewController(
            leaderboardID: classicHighScoreLeaderboardID
        )
        let delegate = GameCenterViewControllerDelegate()
        gameCenterDelegate = delegate
        if let gcVC = viewController as? GKGameCenterViewController {
            gcVC.gameCenterDelegate = delegate
        }
        present(viewController)
    }

    // MARK: - Presentation helpers

    private static func present(_ viewController: UIViewController) {
        guard let presenter = topViewController() else { return }
        if presenter.presentedViewController != nil {
            presenter.dismiss(animated: false) {
                presenter.present(viewController, animated: true)
            }
        } else {
            presenter.present(viewController, animated: true)
        }
    }

    private static func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    /// Test seam: reset auth state between cases.
    static func resetForTesting() {
        isAuthenticated = false
        gameCenterDelegate = nil
        storage.removeObject(forKey: pendingScoreKey)
    }
}

// MARK: - Errors

enum GameCenterError: LocalizedError, Equatable {
    case notAuthenticated
    case leaderboardUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Sign in to Game Center to see global ranks."
        case .leaderboardUnavailable:
            return "Leaderboard is unavailable right now."
        }
    }
}

// MARK: - Backend protocol (testable)

protocol GameCenterBackend: AnyObject {
    var isAuthenticated: Bool { get }
    func setAuthenticateHandler(_ handler: @escaping (UIViewController?, Error?) -> Void)
    func submitScore(_ score: Int, leaderboardID: String, completion: @escaping (Error?) -> Void)
    func loadTopEntries(
        leaderboardID: String,
        limit: Int,
        completion: @escaping (Result<[LeaderboardEntry], Error>) -> Void
    )
    func loadLocalPlayerRank(leaderboardID: String, completion: @escaping (Int?) -> Void)
    func makeLeaderboardViewController(leaderboardID: String) -> UIViewController
}

final class LiveGameCenterBackend: GameCenterBackend {
    var isAuthenticated: Bool {
        GKLocalPlayer.local.isAuthenticated
    }

    func setAuthenticateHandler(_ handler: @escaping (UIViewController?, Error?) -> Void) {
        GKLocalPlayer.local.authenticateHandler = handler
    }

    func submitScore(_ score: Int, leaderboardID: String, completion: @escaping (Error?) -> Void) {
        GKLeaderboard.submitScore(
            score,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [leaderboardID],
            completionHandler: completion
        )
    }

    func loadTopEntries(
        leaderboardID: String,
        limit: Int,
        completion: @escaping (Result<[LeaderboardEntry], Error>) -> Void
    ) {
        Task {
            do {
                let boards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
                guard let board = boards.first else {
                    completion(.failure(GameCenterError.leaderboardUnavailable))
                    return
                }
                let range = NSRange(location: 1, length: max(1, limit))
                let (_, entries, _) = try await board.loadEntries(
                    for: .global,
                    timeScope: .allTime,
                    range: range
                )
                let localID = GKLocalPlayer.local.gamePlayerID
                let mapped = entries.map { entry in
                    LeaderboardEntry(
                        rank: entry.rank,
                        displayName: entry.player.displayName,
                        score: Int(entry.score),
                        isLocalPlayer: entry.player.gamePlayerID == localID
                    )
                }
                completion(.success(mapped))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func loadLocalPlayerRank(leaderboardID: String, completion: @escaping (Int?) -> Void) {
        Task {
            do {
                let boards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
                guard let board = boards.first else {
                    completion(nil)
                    return
                }
                let (localEntry, _) = try await board.loadEntries(
                    for: [GKLocalPlayer.local],
                    timeScope: .allTime
                )
                completion(localEntry?.rank)
            } catch {
                completion(nil)
            }
        }
    }

    func makeLeaderboardViewController(leaderboardID: String) -> UIViewController {
        GKGameCenterViewController(
            leaderboardID: leaderboardID,
            playerScope: .global,
            timeScope: .allTime
        )
    }
}

/// Dismisses Apple's Game Center dashboard when the player closes it.
private final class GameCenterViewControllerDelegate: NSObject, GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
