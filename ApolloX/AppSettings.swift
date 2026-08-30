//
//  AppSettings.swift
//  ApolloX
//
//  Player preferences and first-run flags. Shares ScoreStore's injectable
//  UserDefaults suite so unit tests stay isolated from the device.
//

import Foundation

enum AppSettings {
    private static let soundEnabledKey = "apolloX.soundEnabled"
    private static let hapticsEnabledKey = "apolloX.hapticsEnabled"
    private static let onboardingCompletedKey = "apolloX.onboardingCompleted"

    /// Public URLs for App Store Connect. Host `docs/` via GitHub Pages (or any HTTPS host).
    static let privacyPolicyURL = URL(string: "https://mayooranthava.github.io/ApolloX_IOS/privacy-policy.html")!
    static let supportURL = URL(string: "https://mayooranthava.github.io/ApolloX_IOS/support.html")!

    /// Localized display name for the classic Game Center leaderboard.
    /// Must match the App Store Connect localization (fixes "*MISSING TITLE*").
    static let classicLeaderboardDisplayName = "High Score"

    static var storage: UserDefaults {
        get { ScoreStore.storage }
        set { ScoreStore.storage = newValue }
    }

    static var soundEnabled: Bool {
        get {
            if storage.object(forKey: soundEnabledKey) == nil { return true }
            return storage.bool(forKey: soundEnabledKey)
        }
        set { storage.set(newValue, forKey: soundEnabledKey) }
    }

    static var hapticsEnabled: Bool {
        get {
            if storage.object(forKey: hapticsEnabledKey) == nil { return true }
            return storage.bool(forKey: hapticsEnabledKey)
        }
        set { storage.set(newValue, forKey: hapticsEnabledKey) }
    }

    static var hasCompletedOnboarding: Bool {
        get { storage.bool(forKey: onboardingCompletedKey) }
        set { storage.set(newValue, forKey: onboardingCompletedKey) }
    }

    static func resetForTesting() {
        storage.removeObject(forKey: soundEnabledKey)
        storage.removeObject(forKey: hapticsEnabledKey)
        storage.removeObject(forKey: onboardingCompletedKey)
    }
}
