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

    /// Core hull capacity shown as cyan HP blocks. Lives beyond this become shields.
    static let baseHullCapacity = startingLives
    static let maxLives = 5
    static var maxShieldCapacity: Int { max(0, maxLives - baseHullCapacity) }

    /// ~10% under the prior 0.72 so the starter ship sits smaller on playfield.
    static let playerScale: CGFloat = 0.65
    /// Hull center above playfield bottom: keep thruster flames fully visible.
    static let playerBottomHeightFactor: CGFloat = 0.38
    static let playerBottomPadding: CGFloat = 8
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

    /// Falling nuclear rockets use a tall procedural sprite; scale targets ~55% of player height.
    static let rocketScale: CGFloat = 0.78
    /// Base fall speed; scales up with score (see `rocketSpeed(forScore:)`).
    static let rocketSpeed: CGFloat = 780
    /// +10% fall speed every this many points — readable ramp without time-tier coupling.
    static let rocketSpeedScoreStep = 100
    static let rocketSpeedStepMultiplier: CGFloat = 1.10
    /// Cap so late-game rockets stay reactable (~2.5× ≈ score 1000+).
    static let rocketSpeedMaxMultiplier: CGFloat = 2.5
    static let rocketHitboxFactor: CGFloat = 0.30
    /// Jetpack Joyride-style: rockets aim where the player was this many seconds ago.
    static let rocketTargetLookback: TimeInterval = 2.0
    /// Width of the semi-transparent red danger column shown during the warning.
    static let rocketWarningStripeWidth: CGFloat = 88
    /// Seconds the lane warning flashes before the rocket drops.
    static let rocketWarningDuration: TimeInterval = 1.25
    static let rocketWarningFlashInterval: TimeInterval = 0.08
    static let rocketFirstSpawnDelay: TimeInterval = 18.0
    static let rocketSpawnMinInterval: TimeInterval = 7.0
    static let rocketSpawnMaxInterval: TimeInterval = 13.0
    static let rocketWaveStagger: TimeInterval = 0.38
    static let maxConcurrentRockets = 8

    /// Yellow chain mine: one shot clears the screen (10 HP vs boss during boss fights).
    static let clearMineBossDamage = 10
    static let clearMineSpawnPauseDuration: TimeInterval = 2.0
    static let clearMineSpawnMinInterval: TimeInterval = 22.0
    static let clearMineSpawnMaxInterval: TimeInterval = 32.0
    static let clearMineBossSpawnInterval: TimeInterval = 18.0
    static let clearMinePoints = 8

    /// Legacy alias — first boss HP.
    static let bossMaxHP = 15
    static let bossPoints = 25
    static let bossFireInterval: TimeInterval = 2.1
    /// Soft cap on simultaneous boss dodgeables (rings need more than a triple fan).
    static let maxBossProjectiles = 22

    /// Space monsters that appear every 30s (up to six per run).
    enum BossAttackPattern: String, CaseIterable {
        /// Aimed plasma bolts + purple ring-of-fire with a dodge gap.
        case nebulaCyclops
        /// Fast claw fans + descending claw wall with a safe lane.
        case crimsonClawfiend
        /// Slime volleys + acid curtain with one clear corridor.
        case acidHydra
        /// Ice shard spreads + closing frost gates with a drifting gap.
        case frostMaw
        /// Magma boulders + erupting pillar columns with a safe lane.
        case magmaBehemoth
        /// Void orbs + collapsing ring with a dodge gap.
        case voidEmperor
    }

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
        let attackPattern: BossAttackPattern
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
            bannerRed: 0.85, bannerGreen: 0.35, bannerBlue: 1.0,
            attackPattern: .nebulaCyclops
        ),
        BossProfile(
            name: "Crimson Clawfiend",
            sprite: "bossCrimson",
            maxHP: 22,
            points: 32,
            tintRed: 1, tintGreen: 1, tintBlue: 1, tintBlend: 0,
            fireInterval: 1.95,
            scale: 2.35,
            bannerRed: 1.0, bannerGreen: 0.25, bannerBlue: 0.2,
            attackPattern: .crimsonClawfiend
        ),
        BossProfile(
            name: "Acid Hydra",
            sprite: "bossAcid",
            maxHP: 30,
            points: 40,
            tintRed: 1, tintGreen: 1, tintBlue: 1, tintBlend: 0,
            fireInterval: 1.85,
            scale: 2.40,
            bannerRed: 0.45, bannerGreen: 1.0, bannerBlue: 0.25,
            attackPattern: .acidHydra
        ),
        BossProfile(
            name: "Frost Maw",
            sprite: "bossFrost",
            maxHP: 40,
            points: 50,
            tintRed: 1, tintGreen: 1, tintBlue: 1, tintBlend: 0,
            fireInterval: 1.7,
            scale: 2.40,
            bannerRed: 0.45, bannerGreen: 0.85, bannerBlue: 1.0,
            attackPattern: .frostMaw
        ),
        BossProfile(
            name: "Magma Behemoth",
            sprite: "bossMagma",
            maxHP: 52,
            points: 62,
            tintRed: 1, tintGreen: 1, tintBlue: 1, tintBlend: 0,
            fireInterval: 1.55,
            scale: 2.45,
            bannerRed: 1.0, bannerGreen: 0.55, bannerBlue: 0.15,
            attackPattern: .magmaBehemoth
        ),
        BossProfile(
            name: "Void Emperor",
            sprite: "bossEmperor",
            maxHP: 65,
            points: 80,
            tintRed: 1, tintGreen: 1, tintBlue: 1, tintBlend: 0,
            fireInterval: 1.4,
            scale: 2.35,
            bannerRed: 0.75, bannerGreen: 0.2, bannerBlue: 1.0,
            attackPattern: .voidEmperor
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
        case .asteroid, .asteroidAlt, .mine, .clearMine, .boss:
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

    /// Splits total lives into hull HP (first `baseHullCapacity`) and stacked shields.
    static func hullAndShield(fromLives lives: Int) -> (hull: Int, shield: Int) {
        let clamped = max(0, lives)
        let hull = min(clamped, baseHullCapacity)
        let shield = min(max(0, clamped - baseHullCapacity), maxShieldCapacity)
        return (hull, shield)
    }

    static func obstacleScale(for kind: GameConstants.ObstacleKind) -> CGFloat {
        switch kind {
        case .asteroid, .asteroidAlt: return 1.18
        case .mine: return 1.02
        case .clearMine: return 1.08
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

    /// Kill-streak combo: +1 on destroy, reset to 0 when the player is hit.
    static func comboAfterKill(current: Int) -> Int {
        max(0, current) + 1
    }

    static func comboAfterPlayerHit() -> Int { 0 }

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

    /// Seconds between star boost pickup spawn attempts (restored ~5.2s cadence).
    static func starPickupSpawnInterval(elapsed: TimeInterval) -> TimeInterval {
        GameConstants.powerUpSpawnInterval
    }

    /// Roll in 0...99. Stars appear reliably but taper slightly in late tiers.
    static func shouldSpawnStar(elapsed: TimeInterval, roll: Int) -> Bool {
        let tier = spawnTier(elapsed: elapsed)
        let threshold = max(55, 85 - tier * 5)
        return roll < threshold
    }

    /// Seconds until the next yellow clear-mine spawn attempt.
    static func clearMineSpawnInterval(elapsed: TimeInterval, bossActive: Bool) -> TimeInterval {
        if bossActive {
            return clearMineBossSpawnInterval
        }
        let tier = spawnTier(elapsed: elapsed)
        let reduction = min(4.0, Double(tier) * 0.5)
        let maxGap = max(clearMineSpawnMinInterval + 2.0, clearMineSpawnMaxInterval - reduction)
        return Double.random(in: clearMineSpawnMinInterval...maxGap)
    }

    /// Roll in 0...99. Clear mines are uncommon but appear throughout a run.
    static func shouldSpawnClearMine(elapsed: TimeInterval, bossActive: Bool, roll: Int) -> Bool {
        if isInOpeningGrace(elapsed: elapsed) { return false }
        if bossActive { return roll < 35 }
        let tier = spawnTier(elapsed: elapsed)
        let threshold = min(18, 8 + tier * 2)
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

    /// Player hull center Y — slightly above the playfield floor so flames stay on-screen.
    static func playerBaselineY(playMinY: CGFloat, scaledHeight: CGFloat) -> CGFloat {
        playMinY + scaledHeight * playerBottomHeightFactor + playerBottomPadding
    }

    // MARK: - Falling nuclear rockets

    static func shouldSpawnRockets(elapsed: TimeInterval, bossActive: Bool) -> Bool {
        !bossActive && elapsed >= rocketFirstSpawnDelay
    }

    /// Fall speed ramps +10% every 100 points, soft-capped for fairness.
    static func rocketSpeed(forScore score: Int) -> CGFloat {
        let steps = max(0, score / rocketSpeedScoreStep)
        var multiplier: CGFloat = 1
        if steps > 0 {
            multiplier = min(
                rocketSpeedMaxMultiplier,
                pow(rocketSpeedStepMultiplier, CGFloat(steps))
            )
        }
        return rocketSpeed * multiplier
    }

    /// Seconds until the next falling-rocket attempt; tightens slightly as tiers advance.
    static func rocketSpawnInterval(elapsed: TimeInterval) -> TimeInterval {
        let tier = spawnTier(elapsed: elapsed)
        let reduction = min(5.0, Double(tier) * 0.75)
        let maxGap = max(rocketSpawnMinInterval + 1.5, rocketSpawnMaxInterval - reduction)
        return Double.random(in: rocketSpawnMinInterval...(maxGap))
    }

    /// How many lane warnings / rockets to queue in one wave; ramps with time tier.
    static func rocketsPerWave(elapsed: TimeInterval) -> Int {
        let tier = spawnTier(elapsed: elapsed)
        switch tier {
        case 0: return 1
        case 1: return Int.random(in: 1...2)
        case 2: return Int.random(in: 2...3)
        default: return min(4, 2 + tier / 2)
        }
    }
}
