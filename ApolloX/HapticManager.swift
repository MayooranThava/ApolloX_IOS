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

    static func prepare() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
        notify.prepare()
    }

    static func fire() {
        light.impactOccurred(intensity: 0.55)
    }

    static func starHit() {
        medium.impactOccurred(intensity: 0.85)
    }

    static func enemyDestroyed() {
        medium.impactOccurred()
    }

    static func lifeLost() {
        notify.notificationOccurred(.warning)
    }

    static func gameOver() {
        heavy.impactOccurred()
        notify.notificationOccurred(.error)
    }

    static func upgrade() {
        notify.notificationOccurred(.success)
    }
}
