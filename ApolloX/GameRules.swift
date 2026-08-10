//
//  GameRules.swift
//  ApolloX
//
//  Pure gameplay rules used by GameScene and unit tests.
//

import CoreGraphics
import Foundation

enum GameRules {
    // MARK: - Tuning

    static let startingLives = 3
    static let starsNeededForUpgrade = 1
    static let poweredShotCount = 28

    /// Was 0.42 — bumped so the face-rocket reads clearly on device.
    static let playerScale: CGFloat = 0.72
    static let starScale: CGFloat = 0.58
    static let starPulseScale: CGFloat = 0.66

    static let bulletSize = CGSize(width: 40, height: 80)
    static let poweredBulletSize = CGSize(width: 46, height: 92)
    static let bulletHitRadius: CGFloat = 14

    /// Fraction of visible sprite used for collision (smaller = more forgiving).
    static let playerHitboxFactor: CGFloat = 0.26
    /// Default circular enemy hitbox (non-asteroids).
    static let enemyHitboxFactor: CGFloat = 0.28
    /// Asteroids use near-full coverage so grazing shots still blast.
    static let asteroidHitboxFactor: CGFloat = 0.50
    static let starHitboxFactor: CGFloat = 0.34
    static let healthHitboxFactor: CGFloat = 0.36

    static let healthPickupScale: CGFloat = 0.52
    static let healthPickupPulseScale: CGFloat = 0.60
    static let maxLives = 5
    static let healthPickupMinInterval: TimeInterval = 15.0
    static let healthPickupMaxInterval: TimeInterval = 20.0

    static let invulnerabilityDuration: TimeInterval = 1.6
    static let openingGraceDuration: TimeInterval = 12.0
    static let openingSpawnInterval: TimeInterval = 2.15
    static let openingPowerUpDelay: TimeInterval = 4.0

    static let levelScoreThresholds = [10, 25, 50, 80]

    static func enemyHitboxFactor(for kind: GameConstants.ObstacleKind) -> CGFloat {
        switch kind {
        case .asteroid, .asteroidAlt:
            return asteroidHitboxFactor
        default:
            return enemyHitboxFactor
        }
    }

    static func usesTextureHitbox(_ kind: GameConstants.ObstacleKind) -> Bool {
        kind == .asteroid || kind == .asteroidAlt
    }

    static func nextHealthPickupDelay() -> TimeInterval {
        Double.random(in: healthPickupMinInterval...healthPickupMaxInterval)
    }

    static func livesAfterHealthPickup(current: Int) -> Int {
        min(current + 1, maxLives)
    }

    static func obstacleScale(for kind: GameConstants.ObstacleKind) -> CGFloat {
        // ~1.65× prior scales for readability.
        switch kind {
        case .asteroid, .asteroidAlt: return 1.18
        case .drone: return 1.28
        case .comet: return 1.35
        case .mine: return 1.02
        }
    }

    // MARK: - Lives / contact

    /// Result of a player–obstacle collision while lives remain.
    struct HitOutcome: Equatable {
        let livesRemaining: Int
        let isGameOver: Bool
        let grantInvulnerability: Bool
    }

    static func resolvePlayerHit(lives: Int) -> HitOutcome {
        let remaining = max(0, lives - 1)
        return HitOutcome(
            livesRemaining: remaining,
            isGameOver: remaining <= 0,
            grantInvulnerability: remaining > 0
        )
    }

    // MARK: - Boost

    struct BoostOutcome: Equatable {
        let starCharge: Int
        let activated: Bool
        let poweredShots: Int
    }

    static func collectStar(currentCharge: Int) -> BoostOutcome {
        let charge = currentCharge + 1
        if charge >= starsNeededForUpgrade {
            return BoostOutcome(starCharge: 0, activated: true, poweredShots: poweredShotCount)
        }
        return BoostOutcome(starCharge: charge, activated: false, poweredShots: 0)
    }

    // MARK: - Opening grace / spawning

    static func isInOpeningGrace(elapsed: TimeInterval) -> Bool {
        elapsed < openingGraceDuration
    }

    static func spawnInterval(level: Int, elapsed: TimeInterval) -> TimeInterval {
        if isInOpeningGrace(elapsed: elapsed) {
            return openingSpawnInterval
        }
        return GameConstants.levelSpawnInterval(for: level)
    }

    /// Deterministic obstacle picker (pass `roll` in 0...99 for tests).
    static func obstacleKind(level: Int, elapsed: TimeInterval, roll: Int) -> GameConstants.ObstacleKind {
        let clamped = max(0, min(99, roll))
        if isInOpeningGrace(elapsed: elapsed) {
            // Soft open: only asteroids, wider gaps already handled by spawn interval.
            return clamped < 70 ? .asteroid : .asteroidAlt
        }
        return GameConstants.randomObstacle(for: level, roll: clamped)
    }

    static func shouldAdvanceLevel(previousScore: Int, newScore: Int) -> Bool {
        levelScoreThresholds.contains { previousScore < $0 && newScore >= $0 }
    }

    static func clampPlayerX(x: CGFloat, playMinX: CGFloat, playMaxX: CGFloat, halfWidth: CGFloat) -> CGFloat {
        min(max(x, playMinX + halfWidth), playMaxX - halfWidth)
    }
}
