//
//  GameCenterAchievementService.swift
//  ApolloX
//
//  Reports Game Center achievements. Safe when unsigned-in; queues nothing
//  (achievements are fire-and-forget). Create matching IDs in App Store Connect.
//

import Foundation
import GameKit

enum GameCenterAchievement: String, CaseIterable {
    case firstBoss = "com.mayooran.ApolloX.firstBoss"
    case score50 = "com.mayooran.ApolloX.score50"
    case score100 = "com.mayooran.ApolloX.score100"
    case score500 = "com.mayooran.ApolloX.score500"
    case score1000 = "com.mayooran.ApolloX.score1000"
    case fiveLives = "com.mayooran.ApolloX.fiveLives"
    case buyShip = "com.mayooran.ApolloX.buyShip"
    case allBosses = "com.mayooran.ApolloX.allBosses"
    case wallet500 = "com.mayooran.ApolloX.wallet500"
    case ranksTop5 = "com.mayooran.ApolloX.ranksTop5"

    /// Human-readable title for App Store Connect localization reference.
    var referenceTitle: String {
        switch self {
        case .firstBoss: return "First Boss Down"
        case .score50: return "Rising Pilot"
        case .score100: return "Ace in Training"
        case .score500: return "Void Veteran"
        case .score1000: return "Legend of ApolloX"
        case .fiveLives: return "Full Hull"
        case .buyShip: return "Hangar Upgrade"
        case .allBosses: return "Boss Slayer"
        case .wallet500: return "Credit Hoarder"
        case .ranksTop5: return "Top Five"
        }
    }
}

enum GameCenterAchievementService {

    private static let unlockedKey = "apolloX.unlockedAchievements"

    static var storage: UserDefaults {
        get { ScoreStore.storage }
        set { ScoreStore.storage = newValue }
    }

    static var backend: GameCenterAchievementBackend = LiveGameCenterAchievementBackend()

    private static var unlockedLocally: Set<String> {
        get {
            Set(storage.stringArray(forKey: unlockedKey) ?? [])
        }
        set {
            storage.set(Array(newValue).sorted(), forKey: unlockedKey)
        }
    }

    // MARK: - Unlock API

    static func unlock(_ achievement: GameCenterAchievement) {
        guard !unlockedLocally.contains(achievement.rawValue) else { return }
        var local = unlockedLocally
        local.insert(achievement.rawValue)
        unlockedLocally = local

        guard GameCenterService.isAuthenticated || backend.isAuthenticated else { return }
        backend.reportAchievement(achievement.rawValue, percentComplete: 100)
    }

    static func checkScoreMilestones(_ score: Int) {
        if score >= 50 { unlock(.score50) }
        if score >= 100 { unlock(.score100) }
        if score >= 500 { unlock(.score500) }
        if score >= 1000 { unlock(.score1000) }
    }

    static func checkWallet(_ credits: Int) {
        if credits >= 500 { unlock(.wallet500) }
    }

    static func checkRank(_ rank: Int) {
        if rank > 0, rank <= 5 { unlock(.ranksTop5) }
    }

    static func resetForTesting() {
        storage.removeObject(forKey: unlockedKey)
    }

    static func isUnlockedLocally(_ achievement: GameCenterAchievement) -> Bool {
        unlockedLocally.contains(achievement.rawValue)
    }
}

// MARK: - Backend

protocol GameCenterAchievementBackend: AnyObject {
    var isAuthenticated: Bool { get }
    func reportAchievement(_ identifier: String, percentComplete: Double)
}

final class LiveGameCenterAchievementBackend: GameCenterAchievementBackend {
    var isAuthenticated: Bool {
        GKLocalPlayer.local.isAuthenticated
    }

    func reportAchievement(_ identifier: String, percentComplete: Double) {
        let achievement = GKAchievement(identifier: identifier)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { error in
            #if DEBUG
            if let error {
                print("Achievement report failed (\(identifier)): \(error.localizedDescription)")
            }
            #endif
        }
    }
}
