//
//  BossAttackTextures.swift
//  ApolloX
//
//  Procedural animated boss projectiles — one visual identity per monster attack family.
//  Composite PNG sheets are skipped; all attacks are drawn at runtime.
//

import SpriteKit
import UIKit

enum BossAttackTextures {
    // Void Leviathan
    static let voidPulse = "bossProj_voidPulse"
    static let tentacleOrb = "bossProj_tentacle"
    static let gravityWell = "bossProj_gravityWell"
    static let voidMinion = "bossProj_voidMinion"

    // Solar Conclave
    static let solarFlare = "bossProj_solarFlare"
    static let orbitalSpark = "bossProj_orbital"
    static let coreLaser = "bossProj_coreLaser"
    static let meteor = "bossProj_meteor"

    // Nexus Sentinel
    static let realityShard = "bossProj_realityShard"
    static let dimensionSlash = "bossProj_dimension"
    static let timeWarpOrb = "bossProj_timeWarp"
    static let portalMinion = "bossProj_portalMinion"

    // Plague Broodmother
    static let toxicSpray = "bossProj_toxicSpray"
    static let sporeBomb = "bossProj_sporeBomb"
    static let swarmMinion = "bossProj_swarmMinion"
    static let infectedEgg = "bossProj_infectedEgg"

    /// Legacy alias kept for older sanity checks / callers.
    static let nebulaFlame = voidPulse

    private static var attackAnimationFrames: [String: [SKTexture]] = [:]

    static func animationFrames(for name: String) -> [SKTexture]? {
        attackAnimationFrames[name]
    }

    /// Legacy alias — Solar Conclave lava animations.
    static func lavaFrames(for name: String) -> [SKTexture]? {
        animationFrames(for: name)
    }

    static func registerTextures() {
        guard TextureCache.optional(voidPulse) == nil else { return }
        registerVoidAnimations()
        registerSolarAnimations()
        registerNexusAnimations()
        registerPlagueAnimations()
    }

    // MARK: - Void Leviathan (purple nebula / tentacle theme)

    private static func registerVoidAnimations() {
        registerAttackAnimation(key: voidPulse, frameCount: 5) { frame, total in
            makeVoidPulse(frame: frame, total: total)
        }
        registerAttackAnimation(key: tentacleOrb, frameCount: 4) { frame, total in
            makeTentacleOrb(frame: frame, total: total)
        }
        registerAttackAnimation(key: gravityWell, frameCount: 5) { frame, total in
            makeGravityWell(frame: frame, total: total)
        }
        registerAttackAnimation(key: voidMinion, frameCount: 4) { frame, total in
            makeVoidMinion(frame: frame, total: total)
        }
    }

    private static func makeVoidPulse(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        let pulse = 0.82 + sin(phase * .pi * 2) * 0.18
        return render(CGSize(width: 80, height: 80)) { w, h in
            let cx = w * 0.5
            let cy = h * 0.5
            let outer = w * 0.5 * pulse
            UIBezierPath(ovalIn: CGRect(x: cx - outer, y: cy - outer, width: outer * 2, height: outer * 2))
                .fill(with: SKColor(red: 0.52, green: 0.14, blue: 0.98, alpha: 0.32), alpha: 1)
            let mid = w * 0.34 * pulse
            UIBezierPath(ovalIn: CGRect(x: cx - mid, y: cy - mid, width: mid * 2, height: mid * 2))
                .fill(with: SKColor(red: 0.78, green: 0.40, blue: 1.0, alpha: 1), alpha: 1)
            let core = w * 0.16 * pulse
            UIBezierPath(ovalIn: CGRect(x: cx - core, y: cy - core, width: core * 2, height: core * 2))
                .fill(with: SKColor(red: 0.98, green: 0.88, blue: 1.0, alpha: 1), alpha: 1)
            for index in 0..<3 {
                let angle = phase * .pi * 2 + CGFloat(index) * (.pi * 2 / 3)
                let rx = cx + cos(angle) * w * 0.28
                let ry = cy + sin(angle) * h * 0.28
                UIBezierPath(ovalIn: CGRect(x: rx - 4, y: ry - 4, width: 8, height: 8))
                    .fill(with: SKColor(red: 0.92, green: 0.55, blue: 1.0, alpha: 0.85), alpha: 1)
            }
        }
    }

    private static func makeTentacleOrb(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        return render(CGSize(width: 72, height: 72)) { w, h in
            let cx = w * 0.5
            let cy = h * 0.5
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: w, height: h))
                .fill(with: SKColor(red: 0.42, green: 0.08, blue: 0.72, alpha: 0.25), alpha: 1)
            UIBezierPath(ovalIn: CGRect(x: w * 0.22, y: h * 0.22, width: w * 0.56, height: h * 0.56))
                .fill(with: SKColor(red: 0.28, green: 0.04, blue: 0.48, alpha: 1), alpha: 1)
            UIBezierPath(ovalIn: CGRect(x: w * 0.34, y: h * 0.34, width: w * 0.32, height: h * 0.32))
                .fill(with: SKColor(red: 0.92, green: 0.42, blue: 1.0, alpha: 1), alpha: 1)
            for index in 0..<4 {
                let baseAngle = CGFloat(index) * (.pi / 2) + phase * .pi * 0.5
                let reach = w * (0.38 + sin(phase * .pi * 2 + CGFloat(index)) * 0.08)
                let tentacle = UIBezierPath()
                tentacle.move(to: CGPoint(x: cx, y: cy))
                tentacle.addQuadCurve(
                    to: CGPoint(x: cx + cos(baseAngle) * reach, y: cy + sin(baseAngle) * reach),
                    controlPoint: CGPoint(
                        x: cx + cos(baseAngle + 0.35) * reach * 0.55,
                        y: cy + sin(baseAngle + 0.35) * reach * 0.55
                    )
                )
                SKColor(red: 0.62, green: 0.18, blue: 0.92, alpha: 0.9).setStroke()
                tentacle.lineWidth = 5
                tentacle.lineCapStyle = .round
                tentacle.stroke()
            }
        }
    }

    private static func makeGravityWell(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        return render(CGSize(width: 96, height: 96)) { w, h in
            let cx = w * 0.5
            let cy = h * 0.5
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: w, height: h))
                .fill(with: SKColor(red: 0.55, green: 0.18, blue: 0.95, alpha: 0.28), alpha: 1)
            for ring in 0..<3 {
                let spin = phase * .pi * 2 + CGFloat(ring) * 0.9
                let radius = w * (0.22 + CGFloat(ring) * 0.14)
                let ringPath = UIBezierPath(
                    arcCenter: CGPoint(x: cx, y: cy),
                    radius: radius,
                    startAngle: spin,
                    endAngle: spin + .pi * 1.35,
                    clockwise: true
                )
                SKColor(red: 0.82, green: 0.48, blue: 1.0, alpha: 0.85 - CGFloat(ring) * 0.2).setStroke()
                ringPath.lineWidth = max(3, w * 0.05)
                ringPath.lineCapStyle = .round
                ringPath.stroke()
            }
            UIBezierPath(ovalIn: CGRect(x: cx - w * 0.14, y: cy - h * 0.14, width: w * 0.28, height: h * 0.28))
                .fill(with: SKColor(red: 0.12, green: 0.02, blue: 0.28, alpha: 1), alpha: 1)
            UIBezierPath(ovalIn: CGRect(x: cx - w * 0.06, y: cy - h * 0.06, width: w * 0.12, height: h * 0.12))
                .fill(with: SKColor(red: 0.95, green: 0.75, blue: 1.0, alpha: 0.7), alpha: 1)
        }
    }

    private static func makeVoidMinion(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        let blink = phase > 0.7 && phase < 0.85 ? 0.15 : 1.0
        return render(CGSize(width: 56, height: 56)) { w, h in
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: w, height: h))
                .fill(with: SKColor(red: 0.88, green: 0.45, blue: 1.0, alpha: 0.22), alpha: 1)
            let hull = UIBezierPath()
            hull.move(to: CGPoint(x: w * 0.5, y: h * 0.08))
            hull.addLine(to: CGPoint(x: w * 0.86, y: h * 0.62))
            hull.addLine(to: CGPoint(x: w * 0.68, y: h * 0.90))
            hull.addLine(to: CGPoint(x: w * 0.32, y: h * 0.90))
            hull.addLine(to: CGPoint(x: w * 0.14, y: h * 0.62))
            hull.close()
            SKColor(red: 0.42, green: 0.12, blue: 0.78, alpha: 1).setFill()
            hull.fill()
            SKColor(red: 0.88, green: 0.45, blue: 1.0, alpha: 0.9).setStroke()
            hull.lineWidth = 2
            hull.stroke()
            let eyeH = h * 0.14 * blink
            UIBezierPath(ovalIn: CGRect(x: w * 0.38, y: h * 0.38, width: w * 0.24, height: eyeH))
                .fill(with: SKColor(red: 0.98, green: 0.82, blue: 1.0, alpha: 1), alpha: 1)
        }
    }

    // MARK: - Solar Conclave (lava theme)

    private static func registerSolarAnimations() {
        registerAttackAnimation(key: solarFlare, frameCount: 5) { frame, total in
            makeLavaSpit(frame: frame, total: total)
        }
        registerAttackAnimation(key: orbitalSpark, frameCount: 4) { frame, total in
            makeLavaOrb(frame: frame, total: total, size: 68)
        }
        registerAttackAnimation(key: coreLaser, frameCount: 6) { frame, total in
            makeLavaStream(frame: frame, total: total)
        }
        registerAttackAnimation(key: meteor, frameCount: 5) { frame, total in
            makeMagmaChunk(frame: frame, total: total)
        }
    }

    private static func makeLavaSpit(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        let wobble = sin(phase * .pi * 2) * 0.08
        return render(CGSize(width: 76, height: 76)) { w, h in
            let center = CGPoint(x: w * (0.5 + wobble), y: h * 0.52)
            let ctx = UIGraphicsGetCurrentContext()
            ctx?.setFillColor(SKColor(red: 0.95, green: 0.28, blue: 0.04, alpha: 0.28).cgColor)
            ctx?.fillEllipse(in: CGRect(x: 0, y: 0, width: w, height: h))
            let tail = UIBezierPath()
            tail.move(to: CGPoint(x: center.x, y: h * 0.92))
            tail.addQuadCurve(
                to: CGPoint(x: center.x + w * 0.22, y: center.y + h * 0.08),
                controlPoint: CGPoint(x: center.x + w * 0.34, y: h * 0.72 - phase * h * 0.18)
            )
            tail.addQuadCurve(
                to: CGPoint(x: center.x, y: h * 0.92),
                controlPoint: CGPoint(x: center.x + w * 0.06, y: h * 0.78 - phase * h * 0.12)
            )
            tail.close()
            SKColor(red: 1.0, green: 0.42 + phase * 0.2, blue: 0.08, alpha: 0.85).setFill()
            tail.fill()
            let blob = CGRect(
                x: center.x - w * (0.22 + phase * 0.04),
                y: center.y - h * (0.18 + phase * 0.03),
                width: w * (0.44 + phase * 0.08),
                height: h * (0.36 + phase * 0.06)
            )
            UIBezierPath(ovalIn: blob).fill(with: SKColor(red: 0.92, green: 0.22, blue: 0.02, alpha: 1), alpha: 1)
            UIBezierPath(ovalIn: blob.insetBy(dx: w * 0.08, dy: h * 0.06))
                .fill(with: SKColor(red: 1.0, green: 0.58 + phase * 0.15, blue: 0.12, alpha: 1), alpha: 1)
            UIBezierPath(ovalIn: blob.insetBy(dx: w * 0.14, dy: h * 0.10))
                .fill(with: SKColor(red: 1.0, green: 0.92, blue: 0.45, alpha: 1), alpha: 1)
        }
    }

    private static func makeLavaOrb(frame: Int, total: Int, size: CGFloat) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        let pulse = 0.88 + sin(phase * .pi * 2) * 0.12
        return render(CGSize(width: size, height: size)) { w, h in
            let cx = w * 0.5
            let cy = h * 0.5
            let outer = w * 0.5 * pulse
            UIBezierPath(ovalIn: CGRect(x: cx - outer, y: cy - outer, width: outer * 2, height: outer * 2))
                .fill(with: SKColor(red: 0.95, green: 0.32, blue: 0.05, alpha: 0.35), alpha: 1)
            let mid = w * 0.36 * pulse
            UIBezierPath(ovalIn: CGRect(x: cx - mid, y: cy - mid, width: mid * 2, height: mid * 2))
                .fill(with: SKColor(red: 1.0, green: 0.48, blue: 0.08, alpha: 1), alpha: 1)
            let core = w * 0.18 * pulse
            UIBezierPath(ovalIn: CGRect(x: cx - core, y: cy - core, width: core * 2, height: core * 2))
                .fill(with: SKColor(red: 1.0, green: 0.88, blue: 0.35, alpha: 1), alpha: 1)
            let sparkAngle = phase * .pi * 2
            let sx = cx + cos(sparkAngle) * w * 0.28
            let sy = cy + sin(sparkAngle) * h * 0.28
            UIBezierPath(ovalIn: CGRect(x: sx - 3, y: sy - 3, width: 6, height: 6))
                .fill(with: SKColor.white, alpha: 0.75)
        }
    }

    private static func makeLavaStream(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        return render(CGSize(width: 42, height: 128)) { w, h in
            let ctx = UIGraphicsGetCurrentContext()
            ctx?.setFillColor(SKColor(red: 0.82, green: 0.14, blue: 0.02, alpha: 0.22).cgColor)
            ctx?.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let sway = sin(phase * .pi * 2) * w * 0.06
            let stream = UIBezierPath()
            stream.move(to: CGPoint(x: w * 0.5 + sway, y: h * 0.04))
            stream.addCurve(
                to: CGPoint(x: w * 0.5 - sway * 0.6, y: h * 0.96),
                controlPoint1: CGPoint(x: w * 0.72 + sway, y: h * 0.38),
                controlPoint2: CGPoint(x: w * 0.28 - sway, y: h * 0.68)
            )
            stream.addCurve(
                to: CGPoint(x: w * 0.5 + sway, y: h * 0.04),
                controlPoint1: CGPoint(x: w * 0.72 - sway * 0.5, y: h * 0.68),
                controlPoint2: CGPoint(x: w * 0.28 + sway, y: h * 0.38)
            )
            stream.close()
            SKColor(red: 0.95, green: 0.28, blue: 0.04, alpha: 0.92).setFill()
            stream.fill()
            let dripY = h * (0.22 + phase * 0.62)
            UIBezierPath(ovalIn: CGRect(x: w * 0.38, y: dripY, width: w * 0.24, height: h * 0.10))
                .fill(with: SKColor(red: 1.0, green: 0.72, blue: 0.18, alpha: 1), alpha: 1)
            for index in 0..<3 {
                let t = (phase + CGFloat(index) * 0.28).truncatingRemainder(dividingBy: 1)
                let dropY = h * (0.12 + t * 0.78)
                let dropX = w * (0.46 + sin(t * .pi * 4) * 0.08)
                UIBezierPath(ovalIn: CGRect(x: dropX, y: dropY, width: w * 0.10, height: h * 0.06))
                    .fill(with: SKColor(red: 1.0, green: 0.55, blue: 0.10, alpha: 0.85), alpha: 1)
            }
        }
    }

    private static func makeMagmaChunk(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        let bump = sin(phase * .pi * 2) * 0.06
        return render(CGSize(width: 88, height: 88)) { w, h in
            let ctx = UIGraphicsGetCurrentContext()
            ctx?.setFillColor(SKColor(red: 0.72, green: 0.12, blue: 0.02, alpha: 0.25).cgColor)
            ctx?.fillEllipse(in: CGRect(x: 0, y: 0, width: w, height: h))
            let chunk = UIBezierPath()
            chunk.move(to: CGPoint(x: w * 0.5, y: h * (0.08 + bump)))
            chunk.addCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.55),
                controlPoint1: CGPoint(x: w * 0.78, y: h * 0.12),
                controlPoint2: CGPoint(x: w * 0.92, y: h * 0.32)
            )
            chunk.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.92),
                controlPoint1: CGPoint(x: w * 0.82, y: h * 0.82),
                controlPoint2: CGPoint(x: w * 0.68, y: h * 0.94)
            )
            chunk.addCurve(
                to: CGPoint(x: w * 0.12, y: h * 0.55),
                controlPoint1: CGPoint(x: w * 0.32, y: h * 0.94),
                controlPoint2: CGPoint(x: w * 0.08, y: h * 0.82)
            )
            chunk.addCurve(
                to: CGPoint(x: w * 0.5, y: h * (0.08 + bump)),
                controlPoint1: CGPoint(x: w * 0.08, y: h * 0.32),
                controlPoint2: CGPoint(x: w * 0.22, y: h * 0.12)
            )
            chunk.close()
            SKColor(red: 0.88, green: 0.20, blue: 0.03, alpha: 1).setFill()
            chunk.fill()
            let crack = UIBezierPath()
            crack.move(to: CGPoint(x: w * 0.38, y: h * 0.28))
            crack.addLine(to: CGPoint(x: w * 0.52 + bump * w, y: h * 0.52))
            crack.addLine(to: CGPoint(x: w * 0.44, y: h * 0.72))
            SKColor(red: 1.0, green: 0.78, blue: 0.22, alpha: 0.95).setStroke()
            crack.lineWidth = 3
            crack.stroke()
            UIBezierPath(ovalIn: CGRect(x: w * 0.40, y: h * 0.36, width: w * 0.18, height: h * 0.14))
                .fill(with: SKColor(red: 1.0, green: 0.92, blue: 0.42, alpha: 1), alpha: 1)
        }
    }

    // MARK: - Nexus Sentinel (cyan crystal / portal theme)

    private static func registerNexusAnimations() {
        registerAttackAnimation(key: realityShard, frameCount: 4) { frame, total in
            makeRealityShard(frame: frame, total: total)
        }
        registerAttackAnimation(key: dimensionSlash, frameCount: 5) { frame, total in
            makeDimensionSlash(frame: frame, total: total)
        }
        registerAttackAnimation(key: timeWarpOrb, frameCount: 5) { frame, total in
            makeTimeWarpOrb(frame: frame, total: total)
        }
        registerAttackAnimation(key: portalMinion, frameCount: 4) { frame, total in
            makePortalMinion(frame: frame, total: total)
        }
    }

    private static func makeRealityShard(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        let glitch = sin(phase * .pi * 2) * 4
        return render(CGSize(width: 48, height: 100)) { w, h in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: w * 0.5 + glitch, y: h * 0.04))
            path.addLine(to: CGPoint(x: w * 0.88 + glitch * 0.5, y: h * 0.72))
            path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.96))
            path.addLine(to: CGPoint(x: w * 0.38, y: h * 0.96))
            path.addLine(to: CGPoint(x: w * 0.12 - glitch * 0.5, y: h * 0.72))
            path.close()
            SKColor(red: 0.35, green: 0.88, blue: 1.0, alpha: 1).setFill()
            path.fill()
            SKColor(red: 0.85, green: 0.98, blue: 1.0, alpha: 0.9).setStroke()
            path.lineWidth = 2.5
            path.stroke()
            let gloss = UIBezierPath()
            gloss.move(to: CGPoint(x: w * 0.48 + glitch, y: h * 0.18))
            gloss.addLine(to: CGPoint(x: w * 0.58 + glitch, y: h * 0.62))
            gloss.addLine(to: CGPoint(x: w * 0.46 + glitch, y: h * 0.62))
            gloss.close()
            SKColor(white: 1, alpha: 0.35 + phase * 0.25).setFill()
            gloss.fill()
            UIBezierPath(ovalIn: CGRect(x: w * 0.42, y: h * 0.28, width: w * 0.12, height: h * 0.12))
                .fill(with: SKColor.white, alpha: 0.55)
        }
    }

    private static func makeDimensionSlash(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        return render(CGSize(width: 52, height: 108)) { w, h in
            let ctx = UIGraphicsGetCurrentContext()
            ctx?.setFillColor(SKColor(red: 0.22, green: 0.72, blue: 0.98, alpha: 0.18).cgColor)
            ctx?.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let arc = UIBezierPath()
            let start = h * (0.92 - phase * 0.15)
            let end = h * (0.08 + phase * 0.1)
            arc.move(to: CGPoint(x: w * 0.18, y: start))
            arc.addCurve(
                to: CGPoint(x: w * 0.82, y: end),
                controlPoint1: CGPoint(x: w * 0.05, y: h * 0.45),
                controlPoint2: CGPoint(x: w * 0.95, y: h * 0.55)
            )
            SKColor(red: 0.55, green: 0.95, blue: 1.0, alpha: 0.95).setStroke()
            arc.lineWidth = 6 + phase * 2
            arc.lineCapStyle = .round
            arc.stroke()
            SKColor(red: 0.22, green: 0.72, blue: 0.98, alpha: 1).setStroke()
            arc.lineWidth = 3
            arc.stroke()
            for index in 0..<4 {
                let t = (phase + CGFloat(index) * 0.22).truncatingRemainder(dividingBy: 1)
                let px = w * (0.25 + t * 0.5)
                let py = h * (0.85 - t * 0.75)
                UIBezierPath(ovalIn: CGRect(x: px, y: py, width: 5, height: 5))
                    .fill(with: SKColor.white, alpha: 0.7)
            }
        }
    }

    private static func makeTimeWarpOrb(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        return render(CGSize(width: 88, height: 88)) { w, h in
            let cx = w * 0.5
            let cy = h * 0.5
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: w, height: h))
                .fill(with: SKColor(red: 0.25, green: 0.75, blue: 0.95, alpha: 0.28), alpha: 1)
            for tick in 0..<8 {
                let angle = CGFloat(tick) * (.pi / 4) + phase * .pi * 0.25
                let inner = w * 0.18
                let outer = w * 0.42 + sin(phase * .pi * 2 + CGFloat(tick)) * w * 0.04
                let tickPath = UIBezierPath()
                tickPath.move(to: CGPoint(x: cx + cos(angle) * inner, y: cy + sin(angle) * inner))
                tickPath.addLine(to: CGPoint(x: cx + cos(angle) * outer, y: cy + sin(angle) * outer))
                SKColor(red: 0.55, green: 0.95, blue: 1.0, alpha: 0.85).setStroke()
                tickPath.lineWidth = 2.5
                tickPath.lineCapStyle = .round
                tickPath.stroke()
            }
            let ring = UIBezierPath(ovalIn: CGRect(x: w * 0.16, y: h * 0.16, width: w * 0.68, height: h * 0.68))
            SKColor(red: 0.55, green: 0.95, blue: 1.0, alpha: 1).setStroke()
            ring.lineWidth = max(3, w * 0.05)
            ring.stroke()
            UIBezierPath(ovalIn: CGRect(x: cx - w * 0.12, y: cy - h * 0.12, width: w * 0.24, height: h * 0.24))
                .fill(with: SKColor(red: 0.08, green: 0.28, blue: 0.42, alpha: 1), alpha: 1)
        }
    }

    private static func makePortalMinion(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        let shimmer = sin(phase * .pi * 2) * 0.08
        return render(CGSize(width: 54, height: 54)) { w, h in
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: w, height: h))
                .fill(with: SKColor(red: 0.65, green: 0.95, blue: 1.0, alpha: 0.22), alpha: 1)
            let portal = UIBezierPath()
            portal.move(to: CGPoint(x: w * 0.5, y: h * (0.06 + shimmer)))
            portal.addLine(to: CGPoint(x: w * (0.92 - shimmer), y: h * 0.5))
            portal.addLine(to: CGPoint(x: w * 0.5, y: h * (0.94 - shimmer)))
            portal.addLine(to: CGPoint(x: w * (0.08 + shimmer), y: h * 0.5))
            portal.close()
            SKColor(red: 0.18, green: 0.62, blue: 0.88, alpha: 1).setFill()
            portal.fill()
            SKColor(red: 0.65, green: 0.95, blue: 1.0, alpha: 0.9).setStroke()
            portal.lineWidth = 2
            portal.stroke()
            UIBezierPath(ovalIn: CGRect(x: w * 0.36, y: h * 0.36, width: w * 0.28, height: h * 0.28))
                .fill(with: SKColor(red: 0.85, green: 0.98, blue: 1.0, alpha: 0.85), alpha: 1)
        }
    }

    // MARK: - Plague Broodmother (toxic green / spore theme)

    private static func registerPlagueAnimations() {
        registerAttackAnimation(key: toxicSpray, frameCount: 5) { frame, total in
            makeToxicSpray(frame: frame, total: total)
        }
        registerAttackAnimation(key: sporeBomb, frameCount: 5) { frame, total in
            makeSporeBomb(frame: frame, total: total)
        }
        registerAttackAnimation(key: swarmMinion, frameCount: 4) { frame, total in
            makeSwarmMinion(frame: frame, total: total)
        }
        registerAttackAnimation(key: infectedEgg, frameCount: 5) { frame, total in
            makeInfectedEgg(frame: frame, total: total)
        }
    }

    private static func makeToxicSpray(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        return render(CGSize(width: 66, height: 66)) { w, h in
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: w, height: h))
                .fill(with: SKColor(red: 0.32, green: 0.92, blue: 0.18, alpha: 0.22), alpha: 1)
            let blob = UIBezierPath(ovalIn: CGRect(x: w * 0.10, y: h * 0.14, width: w * 0.80, height: h * 0.72))
            SKColor(red: 0.32, green: 0.92, blue: 0.18, alpha: 1).setFill()
            blob.fill()
            for index in 0..<3 {
                let t = (phase + CGFloat(index) * 0.3).truncatingRemainder(dividingBy: 1)
                let dropX = w * (0.28 + CGFloat(index) * 0.22)
                let dropY = h * (0.22 + t * 0.55)
                UIBezierPath(ovalIn: CGRect(x: dropX, y: dropY, width: w * 0.14, height: h * 0.12))
                    .fill(with: SKColor(red: 0.72, green: 1.0, blue: 0.42, alpha: 0.9), alpha: 1)
            }
            UIBezierPath(ovalIn: CGRect(x: w * 0.20, y: h * 0.20, width: w * 0.30, height: h * 0.24))
                .fill(with: SKColor(red: 0.72, green: 1.0, blue: 0.42, alpha: 0.85), alpha: 1)
        }
    }

    private static func makeSporeBomb(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        let puff = 0.88 + sin(phase * .pi * 2) * 0.12
        return render(CGSize(width: 108, height: 108)) { w, h in
            let cx = w * 0.5
            let cy = h * 0.5
            let cloud = w * 0.5 * puff
            UIBezierPath(ovalIn: CGRect(x: cx - cloud, y: cy - cloud, width: cloud * 2, height: cloud * 2))
                .fill(with: SKColor(red: 0.22, green: 0.78, blue: 0.08, alpha: 0.28), alpha: 1)
            UIBezierPath(ovalIn: CGRect(x: w * 0.18, y: h * 0.20, width: w * 0.64, height: h * 0.60))
                .fill(with: SKColor(red: 0.22, green: 0.78, blue: 0.08, alpha: 1), alpha: 1)
            for vein in 0..<5 {
                let angle = CGFloat(vein) * (.pi * 2 / 5) + phase * 0.4
                let veinPath = UIBezierPath()
                veinPath.move(to: CGPoint(x: cx, y: cy))
                veinPath.addLine(to: CGPoint(
                    x: cx + cos(angle) * w * (0.28 + phase * 0.08),
                    y: cy + sin(angle) * h * (0.28 + phase * 0.08)
                ))
                SKColor(red: 0.55, green: 0.98, blue: 0.22, alpha: 0.8).setStroke()
                veinPath.lineWidth = 3
                veinPath.lineCapStyle = .round
                veinPath.stroke()
            }
            UIBezierPath(ovalIn: CGRect(x: w * 0.38, y: h * 0.38, width: w * 0.24, height: h * 0.24))
                .fill(with: SKColor(red: 0.85, green: 1.0, blue: 0.45, alpha: 1), alpha: 1)
        }
    }

    private static func makeSwarmMinion(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        let wing = sin(phase * .pi * 2) * 0.12
        return render(CGSize(width: 48, height: 48)) { w, h in
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: w, height: h))
                .fill(with: SKColor(red: 0.72, green: 1.0, blue: 0.35, alpha: 0.2), alpha: 1)
            let body = UIBezierPath(ovalIn: CGRect(x: w * 0.30, y: h * 0.34, width: w * 0.40, height: h * 0.38))
            SKColor(red: 0.28, green: 0.72, blue: 0.12, alpha: 1).setFill()
            body.fill()
            let leftWing = UIBezierPath()
            leftWing.move(to: CGPoint(x: w * 0.34, y: h * 0.48))
            leftWing.addQuadCurve(
                to: CGPoint(x: w * 0.06, y: h * (0.42 + wing)),
                controlPoint: CGPoint(x: w * 0.12, y: h * (0.18 - wing))
            )
            leftWing.addQuadCurve(
                to: CGPoint(x: w * 0.34, y: h * 0.48),
                controlPoint: CGPoint(x: w * 0.18, y: h * 0.62)
            )
            leftWing.close()
            SKColor(red: 0.42, green: 0.88, blue: 0.18, alpha: 0.85).setFill()
            leftWing.fill()
            let rightWing = UIBezierPath()
            rightWing.move(to: CGPoint(x: w * 0.66, y: h * 0.48))
            rightWing.addQuadCurve(
                to: CGPoint(x: w * 0.94, y: h * (0.42 - wing)),
                controlPoint: CGPoint(x: w * 0.88, y: h * (0.18 + wing))
            )
            rightWing.addQuadCurve(
                to: CGPoint(x: w * 0.66, y: h * 0.48),
                controlPoint: CGPoint(x: w * 0.82, y: h * 0.62)
            )
            rightWing.close()
            SKColor(red: 0.42, green: 0.88, blue: 0.18, alpha: 0.85).setFill()
            rightWing.fill()
            UIBezierPath(ovalIn: CGRect(x: w * 0.40, y: h * 0.28, width: w * 0.10, height: h * 0.10))
                .fill(with: SKColor(red: 0.95, green: 1.0, blue: 0.55, alpha: 1), alpha: 1)
        }
    }

    private static func makeInfectedEgg(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        let crack = phase * 0.65
        return render(CGSize(width: 58, height: 58)) { w, h in
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: w, height: h))
                .fill(with: SKColor(red: 0.55, green: 0.95, blue: 0.22, alpha: 0.2), alpha: 1)
            UIBezierPath(ovalIn: CGRect(x: w * 0.14, y: h * 0.10, width: w * 0.72, height: h * 0.80))
                .fill(with: SKColor(red: 0.18, green: 0.48, blue: 0.08, alpha: 1), alpha: 1)
            let crackPath = UIBezierPath()
            crackPath.move(to: CGPoint(x: w * 0.48, y: h * 0.22))
            crackPath.addLine(to: CGPoint(x: w * (0.42 - crack * 0.08), y: h * (0.48 + crack * 0.12)))
            crackPath.addLine(to: CGPoint(x: w * (0.54 + crack * 0.06), y: h * (0.68 + crack * 0.08)))
            SKColor(red: 0.85, green: 1.0, blue: 0.45, alpha: 0.95).setStroke()
            crackPath.lineWidth = 2 + crack * 2
            crackPath.lineCapStyle = .round
            crackPath.stroke()
            if crack > 0.35 {
                UIBezierPath(ovalIn: CGRect(x: w * 0.40, y: h * 0.44, width: w * 0.18, height: h * 0.16))
                    .fill(with: SKColor(red: 0.72, green: 1.0, blue: 0.35, alpha: 0.85), alpha: 1)
            }
        }
    }

    // MARK: - Registration

    private static func registerAttackAnimation(
        key: String,
        frameCount: Int,
        make: (_ frame: Int, _ total: Int) -> SKTexture
    ) {
        var frames: [SKTexture] = []
        for index in 0..<frameCount {
            let texture = make(index, frameCount)
            TextureCache.store("\(key)_f\(index)", texture: texture)
            frames.append(texture)
        }
        TextureCache.store(key, texture: frames[0])
        attackAnimationFrames[key] = frames
    }

    private static func render(_ size: CGSize, draw: (CGFloat, CGFloat) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            draw(size.width, size.height)
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = true
        return texture
    }
}

private extension UIBezierPath {
    func fill(with color: SKColor, alpha: CGFloat) {
        color.withAlphaComponent(alpha).setFill()
        fill()
    }
}
