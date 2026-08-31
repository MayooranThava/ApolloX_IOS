//
//  ScoreStore.swift
//  ApolloX
//

import Foundation

enum ScoreStore {
    private static let highScoreKey = "highScoreSaved"

    /// Production uses `.standard`. Tests swap in a suite-named instance so they never
    /// read or write the real high score on a simulator or device.
    static var storage: UserDefaults = .standard

    /// Hook for Game Center (and tests). Default reports the local best to Game Center.
    static var highScoreReporter: (Int) -> Void = { GameCenterService.reportScore($0) }

    private(set) static var currentScore = 0
    /// Set by `commitHighScoreIfNeeded()` for the run-summary card.
    private(set) static var lastCommitWasNewBest = false
    private(set) static var lastCommitPreviousBest = 0
    /// Prevents GameScene and GameOverScene from crediting the same run twice.
    private static var didCommitWalletForRun = false
    /// Prevents double Game Center submits when GameScene and GameOverScene both commit.
    private static var didReportGameCenterForRun = false

    static var highScore: Int {
        storage.integer(forKey: highScoreKey)
    }

    static func resetCurrentScore() {
        currentScore = 0
        lastCommitWasNewBest = false
        lastCommitPreviousBest = 0
        didCommitWalletForRun = false
        didReportGameCenterForRun = false
    }

    @discardableResult
    static func addPoint(_ amount: Int = 1) -> Int {
        currentScore += amount
        GameCenterAchievementService.checkScoreMilestones(currentScore)
        return currentScore
    }

    @discardableResult
    static func commitHighScoreIfNeeded() -> Int {
        let previousBest = highScore
        lastCommitPreviousBest = previousBest
        lastCommitWasNewBest = currentScore > previousBest
        let best: Int
        if lastCommitWasNewBest {
            storage.set(currentScore, forKey: highScoreKey)
            best = currentScore
        } else {
            best = previousBest
        }

        // Report the player's best once per run so Game Center stays in sync even when
        // the run did not set a new device record (covers offline retry / first sign-in).
        if !didReportGameCenterForRun, best > 0 {
            didReportGameCenterForRun = true
            highScoreReporter(best)
        }
        return best
    }

    /// Adds this run's score to the persistent wallet once. Safe to call from both
    /// `GameScene` and `GameOverScene`.
    @discardableResult
    static func commitWalletIfNeeded() -> Int {
        guard !didCommitWalletForRun else { return PlayerProgress.credits }
        didCommitWalletForRun = true
        if currentScore > 0 {
            PlayerProgress.addCredits(currentScore)
        }
        return PlayerProgress.credits
    }
}
