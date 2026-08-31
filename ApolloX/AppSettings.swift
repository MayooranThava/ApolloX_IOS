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
    private static let musicEnabledKey = "apolloX.musicEnabled"
    private static let musicVolumeKey = "apolloX.musicVolume"
    private static let sfxVolumeKey = "apolloX.sfxVolume"
    private static let lastKnownRankKey = "apolloX.lastKnownGameCenterRank"

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

    static var musicEnabled: Bool {
        get {
            if storage.object(forKey: musicEnabledKey) == nil { return true }
            return storage.bool(forKey: musicEnabledKey)
        }
        set { storage.set(newValue, forKey: musicEnabledKey) }
    }

    /// 0…1 effective music loudness when music is enabled.
    static var musicVolume: Float {
        get {
            if storage.object(forKey: musicVolumeKey) == nil { return 0.55 }
            return storage.float(forKey: musicVolumeKey)
        }
        set { storage.set(min(1, max(0, newValue)), forKey: musicVolumeKey) }
    }

    /// 0…1 SFX loudness when sound is enabled.
    static var sfxVolume: Float {
        get {
            if storage.object(forKey: sfxVolumeKey) == nil { return 1.0 }
            return storage.float(forKey: sfxVolumeKey)
        }
        set { storage.set(min(1, max(0, newValue)), forKey: sfxVolumeKey) }
    }

    static var hasCompletedOnboarding: Bool {
        get { storage.bool(forKey: onboardingCompletedKey) }
        set { storage.set(newValue, forKey: onboardingCompletedKey) }
    }

    /// Last global rank fetched for the local player (for run-summary delta).
    static var lastKnownGameCenterRank: Int? {
        get {
            guard storage.object(forKey: lastKnownRankKey) != nil else { return nil }
            let rank = storage.integer(forKey: lastKnownRankKey)
            return rank > 0 ? rank : nil
        }
        set {
            if let newValue, newValue > 0 {
                storage.set(newValue, forKey: lastKnownRankKey)
            } else {
                storage.removeObject(forKey: lastKnownRankKey)
            }
        }
    }

    static func resetForTesting() {
        storage.removeObject(forKey: soundEnabledKey)
        storage.removeObject(forKey: hapticsEnabledKey)
        storage.removeObject(forKey: onboardingCompletedKey)
        storage.removeObject(forKey: musicEnabledKey)
        storage.removeObject(forKey: musicVolumeKey)
        storage.removeObject(forKey: sfxVolumeKey)
        storage.removeObject(forKey: lastKnownRankKey)
    }
}
