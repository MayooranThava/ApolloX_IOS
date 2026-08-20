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

    private(set) static var currentScore = 0
    /// Prevents GameScene and GameOverScene from crediting the same run twice.
    private static var didCommitWalletForRun = false

    static var highScore: Int {
        storage.integer(forKey: highScoreKey)
    }

    static func resetCurrentScore() {
        currentScore = 0
        didCommitWalletForRun = false
    }

    @discardableResult
    static func addPoint(_ amount: Int = 1) -> Int {
        currentScore += amount
        return currentScore
    }

    @discardableResult
    static func commitHighScoreIfNeeded() -> Int {
        let best = highScore
        if currentScore > best {
            storage.set(currentScore, forKey: highScoreKey)
            return currentScore
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
