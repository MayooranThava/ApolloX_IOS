//
//  HapticManager.swift
//  ApolloX
//

import UIKit

enum HapticManager {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notify = UINotificationFeedbackGenerator()
    private static var lastCombatHaptic: TimeInterval = 0
    /// Combat can exceed 10 impacts/sec during boost; Core Haptics will coalesce poorly.
    private static let combatInterval: TimeInterval = 0.055

    static func prepare() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
        notify.prepare()
    }

    static func fire() {
        light.impactOccurred(intensity: 0.55)
        light.prepare()
    }

    static func starHit() {
        medium.impactOccurred(intensity: 0.85)
        medium.prepare()
    }

    static func enemyDestroyed() {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastCombatHaptic >= combatInterval else { return }
        lastCombatHaptic = now
        medium.impactOccurred()
        medium.prepare()
    }

    static func lifeLost() {
        notify.notificationOccurred(.warning)
        notify.prepare()
    }

    static func gameOver() {
        heavy.impactOccurred()
        notify.notificationOccurred(.error)
        heavy.prepare()
        notify.prepare()
    }

    static func upgrade() {
        notify.notificationOccurred(.success)
        notify.prepare()
    }
}
