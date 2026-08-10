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
        XCTAssertTrue(GameRules.isInOpeningGrace(elapsed: 11.9))
        XCTAssertFalse(GameRules.isInOpeningGrace(elapsed: 12.0))

        for roll in 0...99 {
            let kind = GameRules.obstacleKind(level: 3, elapsed: 5, roll: roll)
            XCTAssertTrue(
                kind == .asteroid || kind == .asteroidAlt,
                "Grace period must not spawn \(kind) for roll \(roll)"
            )
        }
    }

    func testOpeningSpawnIntervalIsSlower() {
        let grace = GameRules.spawnInterval(level: 4, elapsed: 3)
        let later = GameRules.spawnInterval(level: 4, elapsed: 20)
        XCTAssertEqual(grace, GameRules.openingSpawnInterval)
        XCTAssertEqual(later, GameConstants.levelSpawnInterval(for: 4))
        XCTAssertGreaterThan(grace, later)
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

    func testLateGameCanSpawnMinesAndComets() {
        let mine = GameRules.obstacleKind(level: 4, elapsed: 30, roll: 95)
        XCTAssertEqual(mine, .mine)
        let comet = GameRules.obstacleKind(level: 4, elapsed: 30, roll: 70)
        XCTAssertEqual(comet, .comet)
    }

    func testInvulnerabilityDurationIsPlayable() {
        XCTAssertGreaterThanOrEqual(GameRules.invulnerabilityDuration, 1.0)
        XCTAssertLessThanOrEqual(GameRules.invulnerabilityDuration, 2.5)
    }
}
