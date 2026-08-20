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
    /// Matches the visible bolt (half-width ~20) with a little extra so grazes count.
    static let bulletHitRadius: CGFloat = 22
    /// Points per second. Fast enough that discrete physics can tunnel without a sweep.
    static let bulletSpeed: CGFloat = 1700

    /// Fraction of visible sprite used for collision (smaller = more forgiving).
    static let playerHitboxFactor: CGFloat = 0.26
    /// Default circular enemy hitbox (non-asteroids).
    static let enemyHitboxFactor: CGFloat = 0.28
    /// Fraction of the sprite's circumradius. 1.0 covers every pixel of the asteroid quad.
    static let asteroidHitboxFactor: CGFloat = 1.0
    static let starHitboxFactor: CGFloat = 0.34
    static let healthHitboxFactor: CGFloat = 0.36

    static let healthPickupScale: CGFloat = 0.52
    static let healthPickupPulseScale: CGFloat = 0.60
    static let maxLives = 5
    static let healthPickupMinInterval: TimeInterval = 15.0
    static let healthPickupMaxInterval: TimeInterval = 20.0

    static let invulnerabilityDuration: TimeInterval = 1.6
    /// First 15 seconds: slower spawns and asteroids only.
    static let openingGraceDuration: TimeInterval = 15.0
    static let openingSpawnInterval: TimeInterval = 2.6
    static let openingPowerUpDelay: TimeInterval = 4.0
    /// Every 30 seconds the spawn rate steps up (after opening grace).
    static let spawnRampInterval: TimeInterval = 30.0

    static let bossSpawnInterval: TimeInterval = 30.0
    static let maxBossCount = 6
    static let bossScale: CGFloat = 2.35
    static let bossDescentDuration: TimeInterval = 9.0
    /// Boss ignores player shots until fully on-screen and at least this long has passed.
    static let bossVulnerableDelay: TimeInterval = 1.8
    static let fireballSpeed: CGFloat = 520
    static let fireballScale: CGFloat = 0.72

    /// Small falling rockets (~⅓ player size) that drop on the spawn column after a warning flash.
    static let rocketScale: CGFloat = playerScale / 3.0
    static let rocketSpeed: CGFloat = 820
    static let rocketHitboxFactor: CGFloat = 0.32
    /// Seconds the "!" warning flashes at the top before the rocket drops.
    static let rocketWarningDuration: TimeInterval = 1.15
    static let rocketWarningFlashInterval: TimeInterval = 0.07
    static let rocketFirstSpawnDelay: TimeInterval = 18.0
    static let rocketSpawnMinInterval: TimeInterval = 9.0
    static let rocketSpawnMaxInterval: TimeInterval = 15.0

    /// Legacy alias — first boss HP.
    static let bossMaxHP = 15
    static let bossPoints = 25
    static let bossFireInterval: TimeInterval = 2.1

    /// Space monsters that appear every 30s (up to six per run).
    struct BossProfile {
        let name: String
        let sprite: String
        let maxHP: Int
        let points: Int
        let tintRed: CGFloat
        let tintGreen: CGFloat
        let tintBlue: CGFloat
        let tintBlend: CGFloat
        let fireInterval: TimeInterval
        let scale: CGFloat
        let bannerRed: CGFloat
        let bannerGreen: CGFloat
        let bannerBlue: CGFloat
    }

    static let bossProfiles: [BossProfile] = [
        BossProfile(
            name: "Nebula Cyclops",
            sprite: "bossNebula",
            maxHP: 15,
            points: 25,
            tintRed: 1, tintGreen: 1, tintBlue: 1, tintBlend: 0,
            fireInterval: 2.1,
            scale: 2.35,
            bannerRed: 0.85, bannerGreen: 0.35, bannerBlue: 1.0
        ),
        BossProfile(
            name: "Crimson Clawfiend",
            sprite: "bossCrimson",
            maxHP: 22,
            points: 32,
            tintRed: 1, tintGreen: 1, tintBlue: 1, tintBlend: 0,
            fireInterval: 1.95,
            scale: 2.35,
            bannerRed: 1.0, bannerGreen: 0.25, bannerBlue: 0.2
        ),
        BossProfile(
            name: "Acid Hydra",
            sprite: "bossAcid",
            maxHP: 30,
            points: 40,
            tintRed: 1, tintGreen: 1, tintBlue: 1, tintBlend: 0,
            fireInterval: 1.85,
            scale: 2.40,
            bannerRed: 0.45, bannerGreen: 1.0, bannerBlue: 0.25
        ),
        BossProfile(
            name: "Frost Maw",
            sprite: "bossFrost",
            maxHP: 40,
            points: 50,
            tintRed: 1, tintGreen: 1, tintBlue: 1, tintBlend: 0,
            fireInterval: 1.7,
            scale: 2.40,
            bannerRed: 0.45, bannerGreen: 0.85, bannerBlue: 1.0
        ),
        BossProfile(
            name: "Magma Behemoth",
            sprite: "bossMagma",
            maxHP: 52,
            points: 62,
            tintRed: 1, tintGreen: 1, tintBlue: 1, tintBlend: 0,
            fireInterval: 1.55,
            scale: 2.45,
            bannerRed: 1.0, bannerGreen: 0.55, bannerBlue: 0.15
        ),
        BossProfile(
            name: "Void Emperor",
            sprite: "bossEmperor",
            maxHP: 65,
            points: 80,
            tintRed: 1, tintGreen: 1, tintBlue: 1, tintBlend: 0,
            fireInterval: 1.4,
            scale: 2.35,
            bannerRed: 0.75, bannerGreen: 0.2, bannerBlue: 1.0
        )
    ]

    static let levelScoreThresholds = [10, 25, 50, 80]

    static func enemyHitboxFactor(for kind: GameConstants.ObstacleKind) -> CGFloat {
        switch kind {
        case .asteroid, .asteroidAlt:
            return asteroidHitboxFactor
        case .boss:
            return 0.32
        default:
            return enemyHitboxFactor
        }
    }

    /// Scene-space radius that should count as a hit against this obstacle.
    /// Asteroids use the sprite circumradius so a shot that clips any corner still blasts.
    static func obstacleHitRadius(
        for kind: GameConstants.ObstacleKind,
        spriteSize: CGSize,
        scale: CGFloat
    ) -> CGFloat {
        let width = spriteSize.width * scale
        let height = spriteSize.height * scale
        switch kind {
        case .asteroid, .asteroidAlt:
            return hypot(width, height) * 0.5 * asteroidHitboxFactor
        case .boss:
            return min(width, height) * enemyHitboxFactor(for: kind)
        default:
            return min(width, height) * enemyHitboxFactor
        }
    }

    /// Texture polygons miss thin rims and tunnel under fast shots; asteroids use a circle instead.
    static func usesTextureHitbox(_ kind: GameConstants.ObstacleKind) -> Bool {
        switch kind {
        case .asteroid, .asteroidAlt, .mine, .boss:
            return false
        }
    }

    /// Continuous (swept) circle vs circle. Catches shots that skip past a rim between frames.
    static func projectileHitsTarget(
        start: CGPoint,
        end: CGPoint,
        projectileRadius: CGFloat,
        target: CGPoint,
        targetRadius: CGFloat
    ) -> Bool {
        let combined = projectileRadius + targetRadius
        guard combined > 0 else { return false }
        let combinedSquared = combined * combined

        func overlaps(_ point: CGPoint) -> Bool {
            let dx = point.x - target.x
            let dy = point.y - target.y
            return dx * dx + dy * dy <= combinedSquared
        }

        if overlaps(end) || overlaps(start) {
            return true
        }

        let vx = end.x - start.x
        let vy = end.y - start.y
        let lengthSquared = vx * vx + vy * vy
        guard lengthSquared > 0.0001 else { return false }

        var t = ((target.x - start.x) * vx + (target.y - start.y) * vy) / lengthSquared
        t = min(1, max(0, t))
        let closest = CGPoint(x: start.x + t * vx, y: start.y + t * vy)
        return overlaps(closest)
    }

    /// Conservative AABB gate before the full swept circle test.
    static func segmentMayHitTarget(
        start: CGPoint,
        end: CGPoint,
        projectileRadius: CGFloat,
        target: CGPoint,
        targetRadius: CGFloat
    ) -> Bool {
        let combined = projectileRadius + targetRadius
        guard combined > 0 else { return false }
        let minX = min(start.x, end.x) - combined
        let maxX = max(start.x, end.x) + combined
        let minY = min(start.y, end.y) - combined
        let maxY = max(start.y, end.y) + combined
        return target.x >= minX && target.x <= maxX && target.y >= minY && target.y <= maxY
    }

    static func nextHealthPickupDelay() -> TimeInterval {
        Double.random(in: healthPickupMinInterval...healthPickupMaxInterval)
    }

    static func livesAfterHealthPickup(current: Int) -> Int {
        min(current + 1, maxLives)
    }

    static func obstacleScale(for kind: GameConstants.ObstacleKind) -> CGFloat {
        switch kind {
        case .asteroid, .asteroidAlt: return 1.18
        case .mine: return 1.02
        case .boss: return bossScale
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

    /// Time-based difficulty tier; steps every `spawnRampInterval` seconds.
    static func spawnTier(elapsed: TimeInterval) -> Int {
        max(0, Int(elapsed / spawnRampInterval))
    }

    static func spawnInterval(elapsed: TimeInterval) -> TimeInterval {
        if isInOpeningGrace(elapsed: elapsed) {
            return openingSpawnInterval
        }
        return GameConstants.timeSpawnInterval(for: spawnTier(elapsed: elapsed))
    }

    /// Deterministic obstacle picker (pass `roll` in 0...99 for tests).
    static func obstacleKind(elapsed: TimeInterval, roll: Int) -> GameConstants.ObstacleKind {
        let clamped = max(0, min(99, roll))
        if isInOpeningGrace(elapsed: elapsed) {
            return clamped < 70 ? .asteroid : .asteroidAlt
        }
        return GameConstants.randomObstacle(for: spawnTier(elapsed: elapsed), roll: clamped)
    }

    /// Seconds between star boost pickup spawn attempts (~1/5 of the old 5.2s cadence, scaling up with tier).
    static func starPickupSpawnInterval(elapsed: TimeInterval) -> TimeInterval {
        let tier = spawnTier(elapsed: elapsed)
        return 26.0 + Double(tier) * 10.0
    }

    /// Roll in 0...99. Lower chance later in the run.
    static func shouldSpawnStar(elapsed: TimeInterval, roll: Int) -> Bool {
        let tier = spawnTier(elapsed: elapsed)
        let threshold = max(5, 20 - tier * 4)
        return roll < threshold
    }

    /// When the first boss should appear (seconds from run start).
    static func firstBossSpawnTime() -> TimeInterval {
        bossSpawnInterval
    }

    /// Schedule the next boss after the current one is defeated.
    static func nextBossSpawnTime(afterDefeatAt elapsed: TimeInterval) -> TimeInterval {
        elapsed + bossSpawnInterval
    }

    static func bossProfile(at index: Int) -> BossProfile {
        bossProfiles[min(max(0, index), bossProfiles.count - 1)]
    }

    static func shouldSpawnBoss(
        elapsed: TimeInterval,
        bossesSpawned: Int,
        bossActive: Bool,
        nextBossSpawnAt: TimeInterval
    ) -> Bool {
        guard !bossActive, bossesSpawned < maxBossCount else { return false }
        return elapsed >= nextBossSpawnAt
    }

    /// True when the entire boss sprite fits inside the play area vertically.
    static func isBossFullyVisible(
        centerY: CGFloat,
        halfHeight: CGFloat,
        playMinY: CGFloat,
        playMaxY: CGFloat
    ) -> Bool {
        let top = centerY + halfHeight
        let bottom = centerY - halfHeight
        return top <= playMaxY && bottom >= playMinY
    }

    /// Boss can be damaged once it has been on-screen long enough and is fully visible.
    static func isBossVulnerable(elapsedSinceSpawn: TimeInterval, fullyVisible: Bool) -> Bool {
        elapsedSinceSpawn >= bossVulnerableDelay && fullyVisible
    }

    static func shouldAdvanceLevel(previousScore: Int, newScore: Int) -> Bool {
        levelScoreThresholds.contains { previousScore < $0 && newScore >= $0 }
    }

    static func clampPlayerX(x: CGFloat, playMinX: CGFloat, playMaxX: CGFloat, halfWidth: CGFloat) -> CGFloat {
        min(max(x, playMinX + halfWidth), playMaxX - halfWidth)
    }

    // MARK: - Falling rockets

    static func shouldSpawnRockets(elapsed: TimeInterval, bossActive: Bool) -> Bool {
        !bossActive && elapsed >= rocketFirstSpawnDelay
    }

    /// Seconds until the next falling-rocket attempt; tightens slightly as tiers advance.
    static func rocketSpawnInterval(elapsed: TimeInterval) -> TimeInterval {
        let tier = spawnTier(elapsed: elapsed)
        let reduction = min(4.0, Double(tier) * 0.6)
        let maxGap = max(rocketSpawnMinInterval + 2.0, rocketSpawnMaxInterval - reduction)
        return Double.random(in: rocketSpawnMinInterval...(maxGap))
    }
}
