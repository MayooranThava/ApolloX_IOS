//
//  FramePacing.swift
//  ApolloX
//
//  ProMotion / Low Power / thermal policy following Apple's
//  "Optimizing iPhone and iPad apps to support ProMotion displays".
//

import SpriteKit
import UIKit

extension Notification.Name {
    static let apolloXPerformanceDidChange = Notification.Name("apolloXPerformanceDidChange")
}

enum EffectsQuality: Equatable {
    case high
    case balanced
    case conservative

    /// Particles/sec. Birth rate is time-based; per-frame sim cost still scales with FPS.
    /// Engine particles are an additive trail on top of sprite flames — keep them light.
    var engineBirthRate: CGFloat {
        switch self {
        case .high: return 22
        case .balanced: return 0
        case .conservative: return 0
        }
    }

    var starDustBirthRate: CGFloat {
        switch self {
        case .high: return 6
        case .balanced: return 3
        case .conservative: return 0
        }
    }

    var parallaxStarCount: Int {
        switch self {
        case .high: return 18
        case .balanced: return 10
        case .conservative: return 0
        }
    }

    /// How many flame tongue sprites to keep active (tips → mid → core).
    var engineFlameLayers: Int {
        switch self {
        case .high: return 5
        case .balanced: return 3
        case .conservative: return 1
        }
    }
}

/// Chooses a refresh rate the system can actually honor on iPhone 16/17.
///
/// iPhone ProMotion (Pro / Pro Max) reports `maximumFramesPerSecond == 120`.
/// Non-Pro iPhones stay at 60. Apple still caps iPhone at 60 Hz unless
/// `CADisableMinimumFrameDurationOnPhone` is set in Info.plist.
enum FramePacing {
    private static weak var skView: SKView?
    private static var observerTokens: [NSObjectProtocol] = []

    private(set) static var currentFramesPerSecond: Int = 60
    private(set) static var currentQuality: EffectsQuality = .high

    static var hardwareMaximumFramesPerSecond: Int {
        let native = UIScreen.main.maximumFramesPerSecond
        return max(60, native)
    }

    static func preferredFramesPerSecond(
        hardwareMax: Int,
        thermalState: ProcessInfo.ThermalState,
        lowPowerMode: Bool
    ) -> Int {
        let cap: Int
        if lowPowerMode {
            cap = 60
        } else {
            switch thermalState {
            case .serious, .critical:
                cap = 30
            case .fair:
                cap = 60
            default:
                cap = hardwareMax
            }
        }
        return max(30, min(max(hardwareMax, 30), cap))
    }

    static func effectsQuality(
        thermalState: ProcessInfo.ThermalState,
        lowPowerMode: Bool
    ) -> EffectsQuality {
        if lowPowerMode || thermalState == .serious || thermalState == .critical {
            return .conservative
        }
        if thermalState == .fair {
            return .balanced
        }
        return .high
    }

    static func start(on view: SKView?) {
        skView = view
        stopMonitoring()
        apply()
        let center = NotificationCenter.default
        observerTokens = [
            center.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in apply() },
            center.addObserver(
                forName: .NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { _ in apply() }
        ]
    }

    static func stopMonitoring() {
        let center = NotificationCenter.default
        for token in observerTokens {
            center.removeObserver(token)
        }
        observerTokens.removeAll()
    }

    static func apply() {
        let hardware = hardwareMaximumFramesPerSecond
        let thermal = ProcessInfo.processInfo.thermalState
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let fps = preferredFramesPerSecond(
            hardwareMax: hardware,
            thermalState: thermal,
            lowPowerMode: lowPower
        )
        let quality = effectsQuality(thermalState: thermal, lowPowerMode: lowPower)

        currentFramesPerSecond = fps
        currentQuality = quality
        skView?.preferredFramesPerSecond = fps
        NotificationCenter.default.post(name: .apolloXPerformanceDidChange, object: nil)
    }

    /// Keeps particle density stable when ProMotion runs above 60 Hz.
    static func scaledBirthRate(_ baseRate: CGFloat) -> CGFloat {
        guard baseRate > 0 else { return 0 }
        let fps = CGFloat(max(currentFramesPerSecond, 30))
        return baseRate * (60.0 / fps)
    }
}
