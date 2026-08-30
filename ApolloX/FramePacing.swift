//
//  FramePacing.swift
//  ApolloX
//
//  ProMotion / Low Power / thermal policy following Apple's
//  "Optimizing iPhone and iPad apps to support ProMotion displays".
//  Also clamps hitch deltas and demotes VFX when frames overrun budget
//  so play stays smooth after pause/resume and during busy combat.
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
    /// Sprite flames carry the look; particles are optional polish on ProMotion hardware.
    var engineBirthRate: CGFloat {
        switch self {
        case .high: return 28
        case .balanced: return 0
        case .conservative: return 0
        }
    }

    var starDustBirthRate: CGFloat {
        switch self {
        case .high: return 6
        case .balanced: return 2
        case .conservative: return 0
        }
    }

    var parallaxStarCount: Int {
        switch self {
        case .high: return 18
        case .balanced: return 6
        case .conservative: return 0
        }
    }

    /// How many flame tongue sprites to keep active (always enough to read as exhaust).
    var engineFlameLayers: Int {
        switch self {
        case .high: return 5
        case .balanced: return 3
        case .conservative: return 3
        }
    }

    /// Soft cap on simultaneous boss dodgeables — rings need headroom but 22 is heavy on 60 Hz phones.
    var maxBossProjectiles: Int {
        switch self {
        case .high: return GameRules.maxBossProjectiles
        case .balanced: return 14
        case .conservative: return 10
        }
    }

    /// Grey rocket-trail smoke is costly when several rockets are on screen at once.
    var rocketTailSmokeBirthRate: CGFloat {
        switch self {
        case .high: return 56
        case .balanced: return 0
        case .conservative: return 0
        }
    }

    func demoted(by steps: Int) -> EffectsQuality {
        var quality = self
        for _ in 0..<max(0, steps) {
            switch quality {
            case .high: quality = .balanced
            case .balanced: quality = .conservative
            case .conservative: return .conservative
            }
        }
        return quality
    }
}

/// Chooses a refresh rate the system can actually honor on iPhone 16/17.
///
/// iPhone ProMotion (Pro / Pro Max) reports `maximumFramesPerSecond == 120`.
/// Non-Pro iPhones stay at 60. Apple still caps iPhone at 60 Hz unless
/// `CADisableMinimumFrameDurationOnPhone` is set in Info.plist.
enum FramePacing {
    /// Ignore debugger / multitasking stalls larger than this when scoring hitches.
    static let hitchIgnoreThreshold: TimeInterval = 0.25
    /// Cap simulation steps so a post-pause hitch cannot jump scroll or soft-pull.
    static let maxSimulationDelta: TimeInterval = 1.0 / 20.0
    /// Overlay / Control Center: keep touches alive without burning a ProMotion budget.
    static let overlayFramesPerSecond = 30
    /// Recover one demotion step after this many consecutive on-budget frames.
    static let hitchRecoveryFrameStreak = 180

    private static weak var skView: SKView?
    private static var observerTokens: [NSObjectProtocol] = []

    private(set) static var currentFramesPerSecond: Int = 60
    private(set) static var currentQuality: EffectsQuality = .high
    /// Extra VFX demotion steps from measured frame overruns (0…2).
    private(set) static var hitchDemotionSteps: Int = 0
    private static var overlayFrameCapActive = false
    private static var smoothedFrameDuration: TimeInterval = 1.0 / 60.0
    private static var goodFrameStreak = 0

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
        lowPowerMode: Bool,
        hardwareMaxFPS: Int = hardwareMaximumFramesPerSecond,
        hitchDemotionSteps demotion: Int = 0
    ) -> EffectsQuality {
        // 60 Hz iPhones (15, 15 Plus, SE, etc.) stay on balanced at nominal thermal —
        // ProMotion headroom is what makes `.high` sustainable during long sessions.
        let baseline: EffectsQuality = hardwareMaxFPS >= 120 ? .high : .balanced

        let policy: EffectsQuality
        if lowPowerMode || thermalState == .serious || thermalState == .critical {
            policy = .conservative
        } else if thermalState == .fair {
            policy = baseline == .high ? .balanced : .conservative
        } else {
            policy = baseline
        }
        return policy.demoted(by: demotion)
    }

    static func clampedDelta(_ raw: TimeInterval) -> TimeInterval {
        guard raw.isFinite, raw > 0 else { return 0 }
        return min(raw, maxSimulationDelta)
    }

    /// Call once per played frame with the raw display link delta (before clamping).
    static func reportFrameDuration(_ rawDelta: TimeInterval) {
        guard rawDelta.isFinite, rawDelta > 0, rawDelta < hitchIgnoreThreshold else { return }

        smoothedFrameDuration = smoothedFrameDuration * 0.85 + rawDelta * 0.15
        let budget = 1.0 / TimeInterval(max(currentFramesPerSecond, 30))

        if smoothedFrameDuration > budget * 1.35 {
            goodFrameStreak = 0
            guard hitchDemotionSteps < 2 else { return }
            hitchDemotionSteps += 1
            apply()
            return
        }

        if smoothedFrameDuration < budget * 1.08 {
            goodFrameStreak += 1
            if goodFrameStreak >= hitchRecoveryFrameStreak, hitchDemotionSteps > 0 {
                hitchDemotionSteps -= 1
                goodFrameStreak = 0
                apply()
            }
        } else {
            goodFrameStreak = 0
        }
    }

    /// Drop to 30 Hz while the pause overlay (or a temporary system freeze) is up so
    /// resume starts from a cooler GPU/CPU budget.
    static func setOverlayFrameCapActive(_ active: Bool) {
        guard overlayFrameCapActive != active else { return }
        overlayFrameCapActive = active
        if !active {
            // Fresh resume: clear hitch debt so we try the policy target again.
            hitchDemotionSteps = 0
            goodFrameStreak = 0
            smoothedFrameDuration = 1.0 / TimeInterval(max(hardwareMaximumFramesPerSecond, 60))
        }
        apply()
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
        var fps = preferredFramesPerSecond(
            hardwareMax: hardware,
            thermalState: thermal,
            lowPowerMode: lowPower
        )
        if overlayFrameCapActive {
            fps = min(fps, overlayFramesPerSecond)
        }
        let quality = effectsQuality(
            thermalState: thermal,
            lowPowerMode: lowPower,
            hardwareMaxFPS: hardware,
            hitchDemotionSteps: hitchDemotionSteps
        )

        let fpsChanged = currentFramesPerSecond != fps
        let qualityChanged = currentQuality != quality
        currentFramesPerSecond = fps
        currentQuality = quality
        skView?.preferredFramesPerSecond = fps
        if fpsChanged || qualityChanged {
            NotificationCenter.default.post(name: .apolloXPerformanceDidChange, object: nil)
        }
    }

    /// Keeps particle density stable when ProMotion runs above 60 Hz.
    static func scaledBirthRate(_ baseRate: CGFloat) -> CGFloat {
        guard baseRate > 0 else { return 0 }
        let fps = CGFloat(max(currentFramesPerSecond, 30))
        return baseRate * (60.0 / fps)
    }

    /// Test seam — resets hitch / overlay state without touching the live SKView.
    static func resetAdaptiveStateForTests() {
        hitchDemotionSteps = 0
        goodFrameStreak = 0
        overlayFrameCapActive = false
        smoothedFrameDuration = 1.0 / 60.0
    }
}
