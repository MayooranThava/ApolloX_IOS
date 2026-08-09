//
//  ScoreStore.swift
//  ApolloX
//

import Foundation

enum ScoreStore {
    private static let highScoreKey = "highScoreSaved"

    private(set) static var currentScore = 0

    static var highScore: Int {
        UserDefaults.standard.integer(forKey: highScoreKey)
    }

    static func resetCurrentScore() {
        currentScore = 0
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
            UserDefaults.standard.set(currentScore, forKey: highScoreKey)
            return currentScore
        }
        return best
    }
}
