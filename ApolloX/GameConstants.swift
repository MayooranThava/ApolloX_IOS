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
    static let poweredShotCount = 24

    static let baseFireDelay: TimeInterval = 0.45
    static let poweredFireDelay: TimeInterval = 0.18
    static let powerUpSpawnInterval: TimeInterval = 5.5
    static let enemyTravelDuration: TimeInterval = 2.2
    static let powerUpTravelDuration: TimeInterval = 7.5

    static let bulletImage = "bullet"
    static let poweredBulletImage = "powerbullet"
    static let starImage = "star_power"

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
        case 1: return 2.0
        case 2: return 1.15
        case 3: return 0.85
        case 4: return 0.6
        default: return 0.5
        }
    }
}
