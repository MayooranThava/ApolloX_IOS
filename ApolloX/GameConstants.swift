//
//  GameConstants.swift
//  ApolloX
//

import CoreGraphics
import UIKit

enum GameConstants {
    /// Logical scene size used with `.aspectFill` across modern iPhones (including Pro / Dynamic Island).
    static let sceneSize = CGSize(width: 1536, height: 2732)

    static let fontName = "The Bold Font"
    static let fallbackFontName = "AvenirNext-Bold"

    static let startingLives = GameRules.startingLives
    /// Stars required to trigger a fire boost. One star = instant boost for snappier play.
    static let starsNeededForUpgrade = GameRules.starsNeededForUpgrade
    static let poweredShotCount = GameRules.poweredShotCount

    static let baseFireDelay: TimeInterval = 0.42
    static let poweredFireDelay: TimeInterval = 0.16
    static let powerUpSpawnInterval: TimeInterval = 5.2
    static let powerUpTravelDuration: TimeInterval = 7.5

    static let bulletImage = "bullet"
    static let poweredBulletImage = "powerbullet"
    static let starImage = "star_power"
    static let healthImage = "health_plus"

    static let fireballImage = "comet"
    static let rocketImage = "comet"

    enum PowerUpKind: String {
        case star
        case health
    }

    enum ObstacleKind: String, CaseIterable {
        case asteroid
        case asteroidAlt = "asteroid2"
        case mine = "spaceMine"
        case boss = "enemyShip"

        var points: Int {
            switch self {
            case .asteroid, .asteroidAlt: return 1
            case .mine: return 4
            case .boss: return GameRules.bossPoints
            }
        }

        var hitsToDestroy: Int {
            switch self {
            case .mine: return 2
            case .boss: return GameRules.bossMaxHP
            default: return 1
            }
        }

        var travelDuration: TimeInterval {
            switch self {
            case .asteroid, .asteroidAlt: return 2.6
            case .mine: return 3.4
            case .boss: return GameRules.bossDescentDuration
            }
        }

        var scale: CGFloat {
            GameRules.obstacleScale(for: self)
        }
    }

    enum Z {
        static let background: CGFloat = 0
        static let bullet: CGFloat = 1
        static let player: CGFloat = 2
        static let enemy: CGFloat = 2
        static let enemyProjectile: CGFloat = 2
        static let powerUp: CGFloat = 3
        static let effect: CGFloat = 4
        static let hud: CGFloat = 100
        static let overlay: CGFloat = 120
    }

    enum NodeName {
        static let bullet = "Bullet"
        static let enemy = "Enemy"
        static let boss = "Boss"
        static let fireball = "Fireball"
        static let rocket = "Rocket"
        static let rocketWarning = "RocketWarning"
        static let powerUp = "PowerUp"
        static let healthPickup = "HealthPickup"
        static let background = "Background"
        static let scrollingBackground = "ScrollingBackground"
        static let obstacleHP = "hp"
        static let obstacleKind = "kind"
        static let hitRadius = "hitRadius"
        static let powerUpKind = "powerUpKind"
        static let pauseButton = "PauseButton"
        static let resumeButton = "Resume"
        static let starDust = "StarDust"
        static let engine = "Engine"
    }

    /// Identifiers used by VoiceOver and the launch smoke UI test.
    enum Accessibility {
        static let titleScene = "titleScene"
    }

    enum PhysicsCategory {
        static let none: UInt32 = 0
        static let player: UInt32 = 0b1
        static let bullet: UInt32 = 0b10
        static let enemy: UInt32 = 0b100
        static let powerUp: UInt32 = 0b1000
        static let enemyProjectile: UInt32 = 0b10000
    }

    /// Spawn interval after opening grace, keyed by 30-second time tier.
    static func timeSpawnInterval(for tier: Int) -> TimeInterval {
        switch tier {
        case 0: return 1.85
        case 1: return 1.45
        case 2: return 1.15
        case 3: return 0.90
        case 4: return 0.72
        default: return 0.55
        }
    }

    static func levelSpawnInterval(for level: Int) -> TimeInterval {
        switch level {
        case 1: return 1.7
        case 2: return 1.15
        case 3: return 0.85
        case 4: return 0.62
        default: return 0.48
        }
    }

    static func randomObstacle(for level: Int) -> ObstacleKind {
        randomObstacle(for: level, roll: Int.random(in: 0...99))
    }

    /// Deterministic variant for tests. `tier` is `GameRules.spawnTier(elapsed:)`.
    static func randomObstacle(for tier: Int, roll: Int) -> ObstacleKind {
        let roll = max(0, min(99, roll))
        switch tier {
        case 0:
            return roll < 75 ? .asteroid : .asteroidAlt
        case 1:
            if roll < 55 { return .asteroid }
            if roll < 80 { return .asteroidAlt }
            return .mine
        default:
            if roll < 35 { return .asteroid }
            if roll < 60 { return .asteroidAlt }
            return .mine
        }
    }
}
