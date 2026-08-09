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

    static let startingLives = 3
    static let starsNeededForUpgrade = 3
    static let poweredShotCount = 28

    static let baseFireDelay: TimeInterval = 0.42
    static let poweredFireDelay: TimeInterval = 0.16
    static let powerUpSpawnInterval: TimeInterval = 5.2
    static let powerUpTravelDuration: TimeInterval = 7.5

    static let bulletImage = "bullet"
    static let poweredBulletImage = "powerbullet"
    static let starImage = "star_power"

    enum ObstacleKind: String {
        case asteroid
        case asteroidAlt = "asteroid2"
        case drone = "enemyShip"
        case mine = "spaceMine"
        case comet

        var points: Int {
            switch self {
            case .asteroid, .asteroidAlt: return 1
            case .drone: return 2
            case .comet: return 3
            case .mine: return 4
            }
        }

        var hitsToDestroy: Int {
            switch self {
            case .mine: return 2
            default: return 1
            }
        }

        var travelDuration: TimeInterval {
            switch self {
            case .asteroid, .asteroidAlt: return 2.6
            case .drone: return 2.2
            case .comet: return 1.45
            case .mine: return 3.4
            }
        }

        var scale: CGFloat {
            switch self {
            case .asteroid, .asteroidAlt: return 0.72
            case .drone: return 0.78
            case .comet: return 0.85
            case .mine: return 0.62
            }
        }
    }

    enum Z {
        static let background: CGFloat = 0
        static let bullet: CGFloat = 1
        static let player: CGFloat = 2
        static let enemy: CGFloat = 2
        static let powerUp: CGFloat = 3
        static let effect: CGFloat = 4
        static let hud: CGFloat = 100
    }

    enum NodeName {
        static let bullet = "Bullet"
        static let enemy = "Enemy"
        static let powerUp = "PowerUp"
        static let background = "Background"
        static let obstacleHP = "hp"
        static let obstacleKind = "kind"
    }

    enum PhysicsCategory {
        static let none: UInt32 = 0
        static let player: UInt32 = 0b1
        static let bullet: UInt32 = 0b10
        static let enemy: UInt32 = 0b100
        static let powerUp: UInt32 = 0b1000
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
        // Early game: mostly asteroids. Later: mix in mines, comets, drones.
        let roll = Int.random(in: 0...99)
        switch level {
        case 1:
            return roll < 80 ? .asteroid : .asteroidAlt
        case 2:
            if roll < 55 { return .asteroid }
            if roll < 75 { return .asteroidAlt }
            if roll < 90 { return .drone }
            return .comet
        case 3:
            if roll < 40 { return .asteroid }
            if roll < 55 { return .asteroidAlt }
            if roll < 72 { return .drone }
            if roll < 88 { return .comet }
            return .mine
        default:
            if roll < 30 { return .asteroid }
            if roll < 45 { return .asteroidAlt }
            if roll < 62 { return .drone }
            if roll < 82 { return .comet }
            return .mine
        }
    }
}
