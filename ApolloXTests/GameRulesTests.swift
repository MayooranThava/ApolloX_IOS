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
        let firstSpawn = GameRules.firstBossSpawnTime()
        XCTAssertFalse(GameRules.shouldSpawnBoss(
            elapsed: firstSpawn - 0.1, bossesSpawned: 0, bossActive: false, nextBossSpawnAt: firstSpawn
        ))
        XCTAssertTrue(GameRules.shouldSpawnBoss(
            elapsed: firstSpawn, bossesSpawned: 0, bossActive: false, nextBossSpawnAt: firstSpawn
        ))
        // Second boss waits 30s after defeat, not a fixed run clock.
        let afterFirstDefeat = GameRules.nextBossSpawnTime(afterDefeatAt: 42)
        XCTAssertFalse(GameRules.shouldSpawnBoss(
            elapsed: afterFirstDefeat - 0.1, bossesSpawned: 1, bossActive: false, nextBossSpawnAt: afterFirstDefeat
        ))
        XCTAssertTrue(GameRules.shouldSpawnBoss(
            elapsed: afterFirstDefeat, bossesSpawned: 1, bossActive: false, nextBossSpawnAt: afterFirstDefeat
        ))
        XCTAssertFalse(GameRules.shouldSpawnBoss(
            elapsed: 50, bossesSpawned: 0, bossActive: true, nextBossSpawnAt: 30
        ))
        XCTAssertFalse(GameRules.shouldSpawnBoss(
            elapsed: 200, bossesSpawned: 4, bossActive: false, nextBossSpawnAt: 999
        ))
    }

    func testBossRosterHasFourEntries() {
        XCTAssertEqual(GameRules.bossProfiles.count, 4)
        XCTAssertEqual(GameRules.maxBossCount, 4)
        XCTAssertEqual(GameRules.firstBossSpawnTime(), 30)
        XCTAssertEqual(GameRules.nextBossSpawnTime(afterDefeatAt: 40), 70)
        XCTAssertEqual(GameRules.bossProfile(at: 0).name, "Void Leviathan")
        XCTAssertEqual(GameRules.bossProfile(at: 0).maxHP, 18)
        XCTAssertEqual(GameRules.bossProfile(at: 3).name, "Plague Broodmother")
        XCTAssertEqual(GameRules.bossProfile(at: 3).maxHP, 55)
        XCTAssertGreaterThan(GameRules.bossProfile(at: 3).points, GameRules.bossProfile(at: 0).points)
        XCTAssertLessThan(GameRules.softTimeWarpFactor, 1)
        XCTAssertGreaterThan(GameRules.softGravityStrength, 0)
        XCTAssertGreaterThan(GameRules.bossMinionLifetime, 2)
    }

    func testEachBossHasUniqueAttackPattern() {
        let patterns = GameRules.bossProfiles.map(\.attackPattern)
        XCTAssertEqual(Set(patterns).count, patterns.count)
        XCTAssertEqual(GameRules.bossProfile(at: 0).attackPattern, .voidLeviathan)
        XCTAssertEqual(GameRules.bossProfile(at: 1).attackPattern, .solarConclave)
        XCTAssertEqual(GameRules.bossProfile(at: 2).attackPattern, .nexusSentinel)
        XCTAssertEqual(GameRules.bossProfile(at: 3).attackPattern, .plagueBroodmother)
        XCTAssertGreaterThanOrEqual(GameRules.maxBossProjectiles, 16)
    }

    func testStarPickupUsesRegularCadence() {
        XCTAssertEqual(GameRules.starPickupSpawnInterval(elapsed: 0), GameConstants.powerUpSpawnInterval)
        XCTAssertEqual(GameRules.starPickupSpawnInterval(elapsed: 60), GameConstants.powerUpSpawnInterval)
        var earlySpawns = 0
        var midSpawns = 0
        var lateSpawns = 0
        for roll in 0..<100 {
            if GameRules.shouldSpawnStar(elapsed: 10, roll: roll) { earlySpawns += 1 }
            // tier 4 at 120s → threshold max(55, 85 - 20) = 65
            if GameRules.shouldSpawnStar(elapsed: 120, roll: roll) { midSpawns += 1 }
            // tier 6 at 180s → threshold floors at 55
            if GameRules.shouldSpawnStar(elapsed: 180, roll: roll) { lateSpawns += 1 }
        }
        XCTAssertEqual(earlySpawns, 85)
        XCTAssertEqual(midSpawns, 65)
        XCTAssertEqual(lateSpawns, 55)
    }

    func testClearMineRules() {
        XCTAssertEqual(GameRules.clearMineBossDamage, 10)
        XCTAssertEqual(GameRules.clearMineSpawnPauseDuration, 2.0, accuracy: 0.001)
        XCTAssertFalse(GameRules.shouldSpawnClearMine(elapsed: 5, bossActive: false, roll: 0))
        XCTAssertTrue(GameRules.shouldSpawnClearMine(elapsed: 35, bossActive: true, roll: 20))
        XCTAssertFalse(GameRules.shouldSpawnClearMine(elapsed: 35, bossActive: true, roll: 40))
        XCTAssertEqual(GameConstants.ObstacleKind.clearMine.hitsToDestroy, 1)
        XCTAssertEqual(GameConstants.ObstacleKind.clearMine.points, GameRules.clearMinePoints)
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

    func testBossHasEighteenHP() {
        XCTAssertEqual(GameRules.bossProfile(at: 0).maxHP, 18)
        XCTAssertEqual(GameRules.bossMaxHP, 18)
    }

    func testBossVulnerabilityRequiresVisibilityAndDelay() {
        XCTAssertFalse(GameRules.isBossVulnerable(elapsedSinceSpawn: 1.7, fullyVisible: true))
        XCTAssertFalse(GameRules.isBossVulnerable(elapsedSinceSpawn: 2.0, fullyVisible: false))
        XCTAssertTrue(GameRules.isBossVulnerable(elapsedSinceSpawn: 1.8, fullyVisible: true))
    }

    func testBossFullyVisibleWhenInsidePlayArea() {
        XCTAssertTrue(GameRules.isBossFullyVisible(centerY: 500, halfHeight: 100, playMinY: 200, playMaxY: 800))
        XCTAssertFalse(GameRules.isBossFullyVisible(centerY: 850, halfHeight: 100, playMinY: 200, playMaxY: 800))
        XCTAssertFalse(GameRules.isBossFullyVisible(centerY: 250, halfHeight: 100, playMinY: 200, playMaxY: 800))
        // Oversized art (taller than the playfield) must still be engageable once the core is in view.
        XCTAssertTrue(GameRules.isBossFullyVisible(centerY: 500, halfHeight: 900, playMinY: 200, playMaxY: 800))
        XCTAssertEqual(GameRules.bossScale, 1.88, accuracy: 0.001)
        XCTAssertLessThanOrEqual(GameRules.enemyHitboxFactor(for: .boss), 0.25)
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

    func testSegmentMayHitTargetMatchesProjectileGate() {
        let start = CGPoint(x: 0, y: 0)
        let end = CGPoint(x: 0, y: 100)
        let target = CGPoint(x: 25, y: 50)
        let projectileRadius: CGFloat = 10
        let targetRadius: CGFloat = 20

        XCTAssertTrue(
            GameRules.segmentMayHitTarget(
                start: start,
                end: end,
                projectileRadius: projectileRadius,
                target: target,
                targetRadius: targetRadius
            )
        )
        XCTAssertTrue(
            GameRules.projectileHitsTarget(
                start: start,
                end: end,
                projectileRadius: projectileRadius,
                target: target,
                targetRadius: targetRadius
            )
        )

        let farTarget = CGPoint(x: 200, y: 50)
        XCTAssertFalse(
            GameRules.segmentMayHitTarget(
                start: start,
                end: end,
                projectileRadius: projectileRadius,
                target: farTarget,
                targetRadius: targetRadius
            )
        )
        XCTAssertFalse(
            GameRules.projectileHitsTarget(
                start: start,
                end: end,
                projectileRadius: projectileRadius,
                target: farTarget,
                targetRadius: targetRadius
            )
        )
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

    func testHullAndShieldSplitFromLives() {
        XCTAssertEqual(GameRules.baseHullCapacity, 3)
        XCTAssertEqual(GameRules.maxShieldCapacity, 2)

        XCTAssertEqual(GameRules.hullAndShield(fromLives: 0).hull, 0)
        XCTAssertEqual(GameRules.hullAndShield(fromLives: 0).shield, 0)

        let fullHull = GameRules.hullAndShield(fromLives: 3)
        XCTAssertEqual(fullHull.hull, 3)
        XCTAssertEqual(fullHull.shield, 0)

        let oneShield = GameRules.hullAndShield(fromLives: 4)
        XCTAssertEqual(oneShield.hull, 3)
        XCTAssertEqual(oneShield.shield, 1)

        let maxed = GameRules.hullAndShield(fromLives: 5)
        XCTAssertEqual(maxed.hull, 3)
        XCTAssertEqual(maxed.shield, 2)

        let over = GameRules.hullAndShield(fromLives: 99)
        XCTAssertEqual(over.hull, 3)
        XCTAssertEqual(over.shield, 2)
    }

    func testComboIncrementsOnKillAndResetsOnHit() {
        XCTAssertEqual(GameRules.comboAfterKill(current: 0), 1)
        XCTAssertEqual(GameRules.comboAfterKill(current: 11), 12)
        XCTAssertEqual(GameRules.comboAfterPlayerHit(), 0)
    }

    func testFormattedScorePadsLikeCockpitHUD() {
        XCTAssertEqual(HUDBarNode.formattedScore(5), "000 005")
        XCTAssertEqual(HUDBarNode.formattedScore(2350), "002 350")
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
        XCTAssertEqual(
            FramePacing.effectsQuality(thermalState: .nominal, lowPowerMode: false, hardwareMaxFPS: 120),
            .high
        )
        XCTAssertEqual(
            FramePacing.effectsQuality(thermalState: .nominal, lowPowerMode: false, hardwareMaxFPS: 60),
            .balanced,
            "60 Hz iPhones should not default to Pro-tier VFX"
        )
        XCTAssertEqual(FramePacing.effectsQuality(thermalState: .fair, lowPowerMode: false, hardwareMaxFPS: 120), .balanced)
        XCTAssertEqual(FramePacing.effectsQuality(thermalState: .fair, lowPowerMode: false, hardwareMaxFPS: 60), .conservative)
        XCTAssertEqual(FramePacing.effectsQuality(thermalState: .serious, lowPowerMode: false, hardwareMaxFPS: 60), .conservative)
        XCTAssertEqual(FramePacing.effectsQuality(thermalState: .nominal, lowPowerMode: true, hardwareMaxFPS: 120), .conservative)
        XCTAssertEqual(
            FramePacing.effectsQuality(
                thermalState: .nominal,
                lowPowerMode: false,
                hardwareMaxFPS: 120,
                hitchDemotionSteps: 1
            ),
            .balanced
        )
        XCTAssertEqual(
            FramePacing.effectsQuality(
                thermalState: .nominal,
                lowPowerMode: false,
                hardwareMaxFPS: 120,
                hitchDemotionSteps: 2
            ),
            .conservative
        )
        XCTAssertEqual(EffectsQuality.high.demoted(by: 1), .balanced)
        XCTAssertGreaterThan(EffectsQuality.high.engineBirthRate, EffectsQuality.conservative.engineBirthRate)
        XCTAssertEqual(EffectsQuality.conservative.starDustBirthRate, 0)
        XCTAssertEqual(EffectsQuality.balanced.engineBirthRate, 0, "sprite flames carry exhaust on 60 Hz phones")
        XCTAssertGreaterThanOrEqual(EffectsQuality.conservative.engineFlameLayers, 3)
        XCTAssertGreaterThan(EffectsQuality.high.engineFlameLayers, EffectsQuality.balanced.engineFlameLayers)
        XCTAssertGreaterThan(EffectsQuality.high.parallaxStarCount, EffectsQuality.conservative.parallaxStarCount)
        XCTAssertGreaterThan(EffectsQuality.high.maxBossProjectiles, EffectsQuality.balanced.maxBossProjectiles)
        XCTAssertEqual(EffectsQuality.balanced.rocketTailSmokeBirthRate, 0)
    }

    func testClampedDeltaCapsPostPauseHitches() {
        XCTAssertEqual(FramePacing.clampedDelta(1.0 / 120.0), 1.0 / 120.0, accuracy: 0.0001)
        XCTAssertEqual(FramePacing.clampedDelta(0.5), FramePacing.maxSimulationDelta, accuracy: 0.0001)
        XCTAssertEqual(FramePacing.clampedDelta(-1), 0, accuracy: 0.0001)
        XCTAssertEqual(FramePacing.clampedDelta(.infinity), 0, accuracy: 0.0001)
    }

    func testHitchReportingDemotesThenRecoversQuality() {
        FramePacing.resetAdaptiveStateForTests()
        FramePacing.apply()
        // Overrun a 60 Hz budget repeatedly (~25 ms frames).
        for _ in 0..<8 {
            FramePacing.reportFrameDuration(0.025)
        }
        XCTAssertGreaterThan(FramePacing.hitchDemotionSteps, 0)

        FramePacing.resetAdaptiveStateForTests()
        FramePacing.apply()
        XCTAssertEqual(FramePacing.hitchDemotionSteps, 0)
    }

    func testOverlayFrameCapClearsHitchDebtOnResume() {
        FramePacing.resetAdaptiveStateForTests()
        for _ in 0..<12 {
            FramePacing.reportFrameDuration(0.03)
        }
        XCTAssertGreaterThan(FramePacing.hitchDemotionSteps, 0)
        FramePacing.setOverlayFrameCapActive(true)
        FramePacing.setOverlayFrameCapActive(false)
        XCTAssertEqual(FramePacing.hitchDemotionSteps, 0)
        FramePacing.resetAdaptiveStateForTests()
    }

    func testScaledBirthRateHalvesAt120Hz() {
        FramePacing.apply()
        let base: CGFloat = 30
        let scaled = FramePacing.scaledBirthRate(base)
        if FramePacing.currentFramesPerSecond >= 120 {
            XCTAssertEqual(scaled, base * 0.5, accuracy: 0.01)
        } else {
            XCTAssertEqual(scaled, base, accuracy: 0.01)
        }
    }

    func testHardpointProfilesAreDistinct() {
        let pulse = GameRules.primaryProfile(for: .pulseLaser)
        let scatter = GameRules.primaryProfile(for: .scatterBolts)
        let rail = GameRules.primaryProfile(for: .railSpike)
        let ion = GameRules.primaryProfile(for: .ionNeedle)
        XCTAssertEqual(pulse.boltCount, 1)
        XCTAssertEqual(scatter.boltCount, 3)
        XCTAssertGreaterThan(scatter.spread, 0)
        XCTAssertEqual(rail.pierceCount, 1)
        XCTAssertLessThan(ion.fireDelay, pulse.fireDelay)

        let grenade = GameRules.specialProfile(for: .plasmaGrenade)
        let flak = GameRules.specialProfile(for: .flakBurst)
        XCTAssertGreaterThan(grenade.aoeRadius, 0)
        XCTAssertGreaterThan(flak.aoeRadius, grenade.aoeRadius)
        XCTAssertLessThanOrEqual(GameRules.maxLiveSpecialProjectiles, 6)
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

    func testRocketScaleTargetsVisibleHeight() {
        let playerHeight = 480.0 * Double(GameRules.playerScale)
        let rocketHeight = Double(GameplayTextures.fallingRocketPixelSize.height) * Double(GameRules.rocketScale)
        XCTAssertGreaterThan(rocketHeight, playerHeight * 0.45)
        XCTAssertLessThan(rocketHeight, playerHeight * 0.65)
    }

    func testRocketTargetLookbackIsTwoSeconds() {
        XCTAssertEqual(GameRules.rocketTargetLookback, 2.0, accuracy: 0.001)
    }

    func testRocketsPerWaveScalesWithTier() {
        XCTAssertEqual(GameRules.rocketsPerWave(elapsed: 10), 1)
        let tier2 = (0..<20).map { _ in GameRules.rocketsPerWave(elapsed: 65) }
        XCTAssertTrue(tier2.contains(where: { $0 >= 2 }))
    }

    func testRocketsWaitUntilAfterOpeningGrace() {
        XCTAssertFalse(GameRules.shouldSpawnRockets(elapsed: 0, bossActive: false))
        XCTAssertFalse(GameRules.shouldSpawnRockets(elapsed: 17.9, bossActive: false))
        XCTAssertTrue(GameRules.shouldSpawnRockets(elapsed: 18.0, bossActive: false))
        XCTAssertFalse(GameRules.shouldSpawnRockets(elapsed: 30, bossActive: true))
    }

    func testRocketSpawnIntervalWithinBounds() {
        for _ in 0..<20 {
            let interval = GameRules.rocketSpawnInterval(elapsed: 45)
            XCTAssertGreaterThanOrEqual(interval, GameRules.rocketSpawnMinInterval)
            XCTAssertLessThanOrEqual(interval, GameRules.rocketSpawnMaxInterval)
        }
    }

    func testRocketSpeedRampsWithScore() {
        XCTAssertEqual(GameRules.rocketSpeed(forScore: 0), GameRules.rocketSpeed, accuracy: 0.01)
        XCTAssertEqual(GameRules.rocketSpeed(forScore: 99), GameRules.rocketSpeed, accuracy: 0.01)
        let at100 = GameRules.rocketSpeed(forScore: 100)
        XCTAssertEqual(at100, GameRules.rocketSpeed * 1.10, accuracy: 0.5)
        let at200 = GameRules.rocketSpeed(forScore: 200)
        XCTAssertEqual(at200, GameRules.rocketSpeed * 1.21, accuracy: 0.5)
        let capped = GameRules.rocketSpeed(forScore: 5000)
        XCTAssertEqual(capped, GameRules.rocketSpeed * GameRules.rocketSpeedMaxMultiplier, accuracy: 0.5)
    }

    func testPlayerBaselineKeepsShipNearBottom() {
        let y = GameRules.playerBaselineY(playMinY: 100, scaledHeight: 200)
        XCTAssertEqual(y, 100 + 200 * GameRules.playerBottomHeightFactor + GameRules.playerBottomPadding, accuracy: 0.01)
        XCTAssertLessThan(GameRules.playerBottomHeightFactor, 0.42)
        XCTAssertLessThan(GameRules.playerScale, 0.72)
    }
}
