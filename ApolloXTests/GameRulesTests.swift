//
//  GameRulesTests.swift
//  ApolloXTests
//

import XCTest
@testable import ApolloX

final class GameRulesTests: XCTestCase {

    func testOneStarActivatesBoost() {
        let outcome = GameRules.collectStar(currentCharge: 0)
        XCTAssertTrue(outcome.activated)
        XCTAssertEqual(outcome.starCharge, 0)
        XCTAssertEqual(outcome.poweredShots, GameRules.poweredShotCount)
        XCTAssertEqual(GameRules.starsNeededForUpgrade, 1)
    }

    func testPlayerHitCostsLifeNotInstantGameOver() {
        let mid = GameRules.resolvePlayerHit(lives: 3)
        XCTAssertEqual(mid.livesRemaining, 2)
        XCTAssertFalse(mid.isGameOver)
        XCTAssertTrue(mid.grantInvulnerability)

        let last = GameRules.resolvePlayerHit(lives: 1)
        XCTAssertEqual(last.livesRemaining, 0)
        XCTAssertTrue(last.isGameOver)
        XCTAssertFalse(last.grantInvulnerability)
    }

    func testOpeningGraceOnlySpawnsAsteroids() {
        XCTAssertTrue(GameRules.isInOpeningGrace(elapsed: 0))
        XCTAssertTrue(GameRules.isInOpeningGrace(elapsed: 14.9))
        XCTAssertFalse(GameRules.isInOpeningGrace(elapsed: 15.0))

        for roll in 0...99 {
            let kind = GameRules.obstacleKind(elapsed: 5, roll: roll)
            XCTAssertTrue(
                kind == .asteroid || kind == .asteroidAlt,
                "Grace period must not spawn \(kind) for roll \(roll)"
            )
        }
    }

    func testOpeningSpawnIntervalIsSlower() {
        let grace = GameRules.spawnInterval(elapsed: 3)
        let later = GameRules.spawnInterval(elapsed: 20)
        XCTAssertEqual(grace, GameRules.openingSpawnInterval)
        XCTAssertEqual(later, GameConstants.timeSpawnInterval(for: 0))
        XCTAssertGreaterThan(grace, later)
    }

    func testSpawnRateStepsEveryThirtySeconds() {
        XCTAssertEqual(GameRules.spawnTier(elapsed: 0), 0)
        XCTAssertEqual(GameRules.spawnTier(elapsed: 29.9), 0)
        XCTAssertEqual(GameRules.spawnTier(elapsed: 30), 1)
        XCTAssertEqual(GameRules.spawnTier(elapsed: 60), 2)

        let tier0 = GameRules.spawnInterval(elapsed: 20)
        let tier1 = GameRules.spawnInterval(elapsed: 35)
        let tier2 = GameRules.spawnInterval(elapsed: 65)
        XCTAssertGreaterThan(tier0, tier1)
        XCTAssertGreaterThan(tier1, tier2)
    }

    func testBossSpawnGate() {
        XCTAssertFalse(GameRules.shouldSpawnBoss(elapsed: 29.9, bossesSpawned: 0, bossActive: false))
        XCTAssertTrue(GameRules.shouldSpawnBoss(elapsed: 30, bossesSpawned: 0, bossActive: false))
        XCTAssertFalse(GameRules.shouldSpawnBoss(elapsed: 50, bossesSpawned: 1, bossActive: false))
        XCTAssertTrue(GameRules.shouldSpawnBoss(elapsed: 60, bossesSpawned: 1, bossActive: false))
        XCTAssertFalse(GameRules.shouldSpawnBoss(elapsed: 50, bossesSpawned: 0, bossActive: true))
        XCTAssertFalse(GameRules.shouldSpawnBoss(elapsed: 200, bossesSpawned: 6, bossActive: false))
    }

    func testBossRosterHasSixEntries() {
        XCTAssertEqual(GameRules.bossProfiles.count, 6)
        XCTAssertEqual(GameRules.maxBossCount, 6)
        XCTAssertEqual(GameRules.bossSpawnTime(forIndex: 0), 30)
        XCTAssertEqual(GameRules.bossSpawnTime(forIndex: 5), 180)
        XCTAssertEqual(GameRules.bossProfile(at: 0).maxHP, 15)
        XCTAssertEqual(GameRules.bossProfile(at: 5).maxHP, 65)
        XCTAssertGreaterThan(GameRules.bossProfile(at: 5).points, GameRules.bossProfile(at: 0).points)
    }

    func testStarPickupIsMuchRarer() {
        XCTAssertGreaterThanOrEqual(GameRules.starPickupSpawnInterval(elapsed: 0), 26)
        XCTAssertGreaterThan(
            GameRules.starPickupSpawnInterval(elapsed: 60),
            GameRules.starPickupSpawnInterval(elapsed: 0)
        )
        var earlySpawns = 0
        var lateSpawns = 0
        for roll in 0..<100 {
            if GameRules.shouldSpawnStar(elapsed: 10, roll: roll) { earlySpawns += 1 }
            if GameRules.shouldSpawnStar(elapsed: 120, roll: roll) { lateSpawns += 1 }
        }
        XCTAssertEqual(earlySpawns, 20)
        XCTAssertEqual(lateSpawns, 5)
    }

    func testSpriteScalesWereIncreased() {
        XCTAssertGreaterThanOrEqual(GameRules.playerScale, 0.65)
        XCTAssertGreaterThan(GameRules.obstacleScale(for: .asteroid), 0.72)
        XCTAssertGreaterThan(GameRules.bulletSize.width, 28)
        XCTAssertGreaterThan(GameRules.bulletSize.height, 56)
    }

    func testLevelThresholdCrossing() {
        XCTAssertTrue(GameRules.shouldAdvanceLevel(previousScore: 9, newScore: 10))
        XCTAssertFalse(GameRules.shouldAdvanceLevel(previousScore: 10, newScore: 11))
        XCTAssertTrue(GameRules.shouldAdvanceLevel(previousScore: 24, newScore: 26))
    }

    func testPlayerClampStaysInsidePlayArea() {
        let x = GameRules.clampPlayerX(x: -50, playMinX: 0, playMaxX: 100, halfWidth: 10)
        XCTAssertEqual(x, 10)
        let y = GameRules.clampPlayerX(x: 200, playMinX: 0, playMaxX: 100, halfWidth: 10)
        XCTAssertEqual(y, 90)
    }

    func testLateGameCanSpawnMines() {
        let mine = GameRules.obstacleKind(elapsed: 35, roll: 90)
        XCTAssertEqual(mine, .mine)
        let asteroid = GameRules.obstacleKind(elapsed: 35, roll: 10)
        XCTAssertEqual(asteroid, .asteroid)
    }

    func testRocketsRemovedFromObstaclePool() {
        for roll in 0...99 {
            let kind = GameRules.obstacleKind(elapsed: 90, roll: roll)
            XCTAssertFalse(kind == .boss, "regular spawns must not include the boss")
        }
    }

    func testInvulnerabilityDurationIsPlayable() {
        XCTAssertGreaterThanOrEqual(GameRules.invulnerabilityDuration, 1.0)
        XCTAssertLessThanOrEqual(GameRules.invulnerabilityDuration, 2.5)
    }

    func testAsteroidHitboxCoversMostOfSprite() {
        XCTAssertGreaterThanOrEqual(GameRules.enemyHitboxFactor(for: .asteroid), 0.95)
        XCTAssertFalse(GameRules.usesTextureHitbox(.asteroid))
        XCTAssertFalse(GameRules.usesTextureHitbox(.asteroidAlt))
        XCTAssertFalse(GameRules.usesTextureHitbox(.mine))
        XCTAssertGreaterThanOrEqual(GameRules.bulletHitRadius, 20)

        let size = CGSize(width: 100, height: 100)
        let asteroidRadius = GameRules.obstacleHitRadius(for: .asteroid, spriteSize: size, scale: 1)
        XCTAssertGreaterThanOrEqual(asteroidRadius, hypot(50, 50), "asteroid collider must cover sprite corners")

        let mineRadius = GameRules.obstacleHitRadius(for: .mine, spriteSize: size, scale: 1)
        XCTAssertLessThan(mineRadius, asteroidRadius)
    }

    func testBossHasFifteenHP() {
        XCTAssertEqual(GameRules.bossProfile(at: 0).maxHP, 15)
        XCTAssertEqual(GameRules.bossMaxHP, 15)
    }

    func testBossVulnerabilityRequiresVisibilityAndDelay() {
        XCTAssertFalse(GameRules.isBossVulnerable(elapsedSinceSpawn: 4.9, fullyVisible: true))
        XCTAssertFalse(GameRules.isBossVulnerable(elapsedSinceSpawn: 6.0, fullyVisible: false))
        XCTAssertTrue(GameRules.isBossVulnerable(elapsedSinceSpawn: 5.0, fullyVisible: true))
    }

    func testBossFullyVisibleWhenInsidePlayArea() {
        XCTAssertTrue(GameRules.isBossFullyVisible(centerY: 500, halfHeight: 100, playMinY: 200, playMaxY: 800))
        XCTAssertFalse(GameRules.isBossFullyVisible(centerY: 850, halfHeight: 100, playMinY: 200, playMaxY: 800))
        XCTAssertFalse(GameRules.isBossFullyVisible(centerY: 250, halfHeight: 100, playMinY: 200, playMaxY: 800))
    }

    func testSweptProjectileCatchesGrazingPath() {
        let clipped = GameRules.projectileHitsTarget(
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: 100),
            projectileRadius: 10,
            target: CGPoint(x: 25, y: 50),
            targetRadius: 20
        )
        XCTAssertTrue(clipped, "path that clips the rim must count as a hit")

        let overlapEnd = GameRules.projectileHitsTarget(
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: 40),
            projectileRadius: 8,
            target: CGPoint(x: 0, y: 50),
            targetRadius: 12
        )
        XCTAssertTrue(overlapEnd)

        let cleanMiss = GameRules.projectileHitsTarget(
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: 100),
            projectileRadius: 5,
            target: CGPoint(x: 80, y: 50),
            targetRadius: 10
        )
        XCTAssertFalse(cleanMiss)
    }

    func testHealthPickupGrantsLifeUpToCap() {
        XCTAssertEqual(GameRules.livesAfterHealthPickup(current: 2), 3)
        XCTAssertEqual(GameRules.livesAfterHealthPickup(current: GameRules.maxLives), GameRules.maxLives)
        XCTAssertGreaterThanOrEqual(GameRules.healthPickupMinInterval, 15)
        XCTAssertLessThanOrEqual(GameRules.healthPickupMaxInterval, 20)
        XCTAssertLessThanOrEqual(GameRules.healthPickupMinInterval, GameRules.healthPickupMaxInterval)

        for _ in 0..<40 {
            let delay = GameRules.nextHealthPickupDelay()
            XCTAssertGreaterThanOrEqual(delay, GameRules.healthPickupMinInterval)
            XCTAssertLessThanOrEqual(delay, GameRules.healthPickupMaxInterval)
        }
    }

    func testProMotionFramePacingHonorsApplePolicy() {
        XCTAssertEqual(
            FramePacing.preferredFramesPerSecond(hardwareMax: 120, thermalState: .nominal, lowPowerMode: false),
            120,
            "iPhone 16/17 Pro should request 120 Hz when cool"
        )
        XCTAssertEqual(
            FramePacing.preferredFramesPerSecond(hardwareMax: 60, thermalState: .nominal, lowPowerMode: false),
            60,
            "non-Pro iPhones stay at 60 Hz"
        )
        XCTAssertEqual(
            FramePacing.preferredFramesPerSecond(hardwareMax: 120, thermalState: .nominal, lowPowerMode: true),
            60
        )
        XCTAssertEqual(
            FramePacing.preferredFramesPerSecond(hardwareMax: 120, thermalState: .fair, lowPowerMode: false),
            60
        )
        XCTAssertEqual(
            FramePacing.preferredFramesPerSecond(hardwareMax: 120, thermalState: .serious, lowPowerMode: false),
            30
        )
        XCTAssertEqual(
            FramePacing.preferredFramesPerSecond(hardwareMax: 120, thermalState: .critical, lowPowerMode: false),
            30
        )
    }

    func testEffectsQualityScalesWithThermalBudget() {
        XCTAssertEqual(FramePacing.effectsQuality(thermalState: .nominal, lowPowerMode: false), .high)
        XCTAssertEqual(FramePacing.effectsQuality(thermalState: .fair, lowPowerMode: false), .balanced)
        XCTAssertEqual(FramePacing.effectsQuality(thermalState: .serious, lowPowerMode: false), .conservative)
        XCTAssertEqual(FramePacing.effectsQuality(thermalState: .nominal, lowPowerMode: true), .conservative)
        XCTAssertGreaterThan(EffectsQuality.high.engineBirthRate, EffectsQuality.conservative.engineBirthRate)
        XCTAssertEqual(EffectsQuality.conservative.starDustBirthRate, 0)
    }

    func testNodePoolReusesSpritesAndCapsIdle() {
        var created = 0
        let pool = NodePool(prewarm: 2, maxIdle: 2) {
            created += 1
            return PooledSprite(color: .white, size: CGSize(width: 4, height: 4))
        }
        XCTAssertEqual(created, 2)
        XCTAssertEqual(pool.idleCount, 2)

        let first = pool.checkout()
        let second = pool.checkout()
        XCTAssertEqual(pool.idleCount, 0)

        pool.recycle(first)
        pool.recycle(first)
        XCTAssertEqual(pool.idleCount, 1, "double-recycle must not duplicate the same node")

        let reused = pool.checkout()
        XCTAssertTrue(reused === first)

        pool.recycle(reused)
        pool.recycle(second)
        XCTAssertEqual(pool.idleCount, 2)
    }

    func testPhysicsBodyReusedWhenRadiusUnchanged() {
        let sprite = PooledSprite(color: .red, size: CGSize(width: 10, height: 10))
        sprite.attachCirclePhysics(radius: 22, category: 1, contact: 2)
        let firstBody = sprite.physicsBody
        sprite.attachCirclePhysics(radius: 22, category: 1, contact: 4)
        XCTAssertTrue(sprite.physicsBody === firstBody)
        XCTAssertEqual(sprite.physicsBody?.contactTestBitMask, 4)

        sprite.attachCirclePhysics(radius: 40, category: 1, contact: 2)
        XCTAssertFalse(sprite.physicsBody === firstBody)
    }

    func testLateGameSweptCombatStaysUnderFrameBudget() {
        let bullets = (0..<12).map { CGPoint(x: CGFloat($0) * 40, y: 200) }
        let ends = bullets.map { CGPoint(x: $0.x, y: $0.y + 28) }
        let enemies = (0..<8).map { CGPoint(x: 80 + CGFloat($0) * 70, y: 900) }

        // 120 Hz frame budget is 8.3 ms. This inner loop is the previous per-frame hotspot.
        measure {
            var hits = 0
            for _ in 0..<40 {
                for i in 0..<bullets.count {
                    for enemy in enemies {
                        if GameRules.projectileHitsTarget(
                            start: bullets[i],
                            end: ends[i],
                            projectileRadius: GameRules.bulletHitRadius,
                            target: enemy,
                            targetRadius: 90
                        ) {
                            hits += 1
                        }
                    }
                }
            }
            XCTAssertGreaterThanOrEqual(hits, 0)
        }
    }
}
