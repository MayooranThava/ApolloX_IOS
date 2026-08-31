//
//  BossAttackTextures.swift
//  ApolloX
//
//  Procedural glowing boss projectiles — dodgeable fireballs / shards / orbs
//  with one visual identity per monster attack family.
//

import SpriteKit
import UIKit

enum BossAttackTextures {
    // Void Leviathan
    static let voidPulse = "bossProj_voidPulse"
    static let tentacleOrb = "bossProj_tentacle"
    static let gravityWell = "bossProj_gravityWell"
    static let voidMinion = "bossProj_voidMinion"

    // Solar Conclave — procedural animated lava (composite PNG sheets are skipped)
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


    static func lavaFrames(for name: String) -> [SKTexture]? {
        lavaAnimationFrames[name]
    }

    private static var catalogNames: [String] {
        [
            voidPulse, tentacleOrb, gravityWell, voidMinion,
            realityShard, dimensionSlash, timeWarpOrb, portalMinion,
            toxicSpray, sporeBomb, swarmMinion, infectedEgg
        ]
    }

    static func registerTextures() {
        guard TextureCache.optional(voidPulse) == nil else { return }

        for name in catalogNames {
            if let image = UIImage(named: name), image.size.width > 1 {
                let texture = SKTexture(image: image)
                texture.filteringMode = .linear
                texture.usesMipmaps = true
                TextureCache.store(name, texture: texture)
            }
        }

        registerVoidFallbacks()
        registerSolarLavaTextures()
        registerNexusFallbacks()
        registerPlagueFallbacks()
    }

    private static func registerVoidFallbacks() {
        ensure(voidPulse) {
            makeFireball(
                size: 80,
                outer: SKColor(red: 0.52, green: 0.14, blue: 0.98, alpha: 1),
                mid: SKColor(red: 0.78, green: 0.40, blue: 1.0, alpha: 1),
                core: SKColor(red: 0.98, green: 0.88, blue: 1.0, alpha: 1)
            )
        }
        ensure(tentacleOrb) {
            makeGlowOrb(
                size: 68,
                fill: SKColor(red: 0.28, green: 0.04, blue: 0.48, alpha: 1),
                core: SKColor(red: 0.92, green: 0.42, blue: 1.0, alpha: 1)
            )
        }
        ensure(gravityWell) {
            makeRingOrb(
                size: 96,
                outer: SKColor(red: 0.55, green: 0.18, blue: 0.95, alpha: 0.55),
                ring: SKColor(red: 0.82, green: 0.48, blue: 1.0, alpha: 1),
                core: SKColor(red: 0.18, green: 0.02, blue: 0.32, alpha: 1)
            )
        }
        ensure(voidMinion) {
            makeMinion(
                size: 56,
                body: SKColor(red: 0.42, green: 0.12, blue: 0.78, alpha: 1),
                glow: SKColor(red: 0.88, green: 0.45, blue: 1.0, alpha: 1)
            )
        }
    }

    private static func registerSolarLavaTextures() {
        registerLavaAnimation(key: solarFlare, frameCount: 5) { frame, total in
            makeLavaSpit(frame: frame, total: total)
        }
        registerLavaAnimation(key: orbitalSpark, frameCount: 4) { frame, total in
            makeLavaOrb(frame: frame, total: total, size: 68)
        }
        registerLavaAnimation(key: coreLaser, frameCount: 6) { frame, total in
            makeLavaStream(frame: frame, total: total)
        }
        registerLavaAnimation(key: meteor, frameCount: 5) { frame, total in
            makeMagmaChunk(frame: frame, total: total)
        }
    }

    private static func registerNexusFallbacks() {
        ensure(realityShard) {
            makeShard(
                size: CGSize(width: 48, height: 100),
                fill: SKColor(red: 0.35, green: 0.88, blue: 1.0, alpha: 1),
                edge: SKColor(red: 0.85, green: 0.98, blue: 1.0, alpha: 1)
            )
        }
        ensure(dimensionSlash) {
            makeShard(
                size: CGSize(width: 42, height: 108),
                fill: SKColor(red: 0.22, green: 0.72, blue: 0.98, alpha: 1),
                edge: SKColor(red: 0.70, green: 0.95, blue: 1.0, alpha: 1)
            )
        }
        ensure(timeWarpOrb) {
            makeRingOrb(
                size: 88,
                outer: SKColor(red: 0.25, green: 0.75, blue: 0.95, alpha: 0.45),
                ring: SKColor(red: 0.55, green: 0.95, blue: 1.0, alpha: 1),
                core: SKColor(red: 0.08, green: 0.28, blue: 0.42, alpha: 1)
            )
        }
        ensure(portalMinion) {
            makeMinion(
                size: 54,
                body: SKColor(red: 0.18, green: 0.62, blue: 0.88, alpha: 1),
                glow: SKColor(red: 0.65, green: 0.95, blue: 1.0, alpha: 1)
            )
        }
    }

    private static func registerPlagueFallbacks() {
        ensure(toxicSpray) {
            makeSlimeBlob(
                size: 66,
                fill: SKColor(red: 0.32, green: 0.92, blue: 0.18, alpha: 1),
                highlight: SKColor(red: 0.72, green: 1.0, blue: 0.42, alpha: 0.9)
            )
        }
        ensure(sporeBomb) {
            makeSlimeBlob(
                size: 108,
                fill: SKColor(red: 0.22, green: 0.78, blue: 0.08, alpha: 1),
                highlight: SKColor(red: 0.55, green: 0.98, blue: 0.22, alpha: 0.9)
            )
        }
        ensure(swarmMinion) {
            makeMinion(
                size: 48,
                body: SKColor(red: 0.28, green: 0.72, blue: 0.12, alpha: 1),
                glow: SKColor(red: 0.72, green: 1.0, blue: 0.35, alpha: 1)
            )
        }
        ensure(infectedEgg) {
            makeGlowOrb(
                size: 58,
                fill: SKColor(red: 0.18, green: 0.48, blue: 0.08, alpha: 1),
                core: SKColor(red: 0.55, green: 0.95, blue: 0.22, alpha: 1)
            )
        }
    }

    private static func registerLavaAnimation(
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
        lavaAnimationFrames[key] = frames
    }

    /// Arcing lava spit — molten droplet with a trailing spray tail.
    private static func makeLavaSpit(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        let wobble = sin(phase * .pi * 2) * 0.08
        return render(CGSize(width: 76, height: 76)) { w, h in
            let ctx = UIGraphicsGetCurrentContext()
            let center = CGPoint(x: w * (0.5 + wobble), y: h * 0.52)

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

    /// Pulsing molten orb for orbital ring attacks.
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

    /// Vertical lava fountain column with dripping animation.
    private static func makeLavaStream(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        return render(CGSize(width: 42, height: 128)) { w, h in
            let ctx = UIGraphicsGetCurrentContext()
            ctx?.setFillColor(SKColor(red: 0.82, green: 0.14, blue: 0.02, alpha: 0.22).cgColor)
            ctx?.fill(CGRect(x: 0, y: 0, width: w, height: h))

            let stream = UIBezierPath()
            let sway = sin(phase * .pi * 2) * w * 0.06
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
            UIBezierPath(ovalIn: CGRect(x: w * 0.42, y: dripY + h * 0.06, width: w * 0.16, height: h * 0.08))
                .fill(with: SKColor(red: 1.0, green: 0.92, blue: 0.45, alpha: 0.9), alpha: 1)

            for index in 0..<3 {
                let t = (phase + CGFloat(index) * 0.28).truncatingRemainder(dividingBy: 1)
                let dropY = h * (0.12 + t * 0.78)
                let dropX = w * (0.46 + sin(t * .pi * 4) * 0.08)
                UIBezierPath(ovalIn: CGRect(x: dropX, y: dropY, width: w * 0.10, height: h * 0.06))
                    .fill(with: SKColor(red: 1.0, green: 0.55, blue: 0.10, alpha: 0.85), alpha: 1)
            }
        }
    }

    /// Falling magma chunk with bubbling surface.
    private static func makeMagmaChunk(frame: Int, total: Int) -> SKTexture {
        let phase = CGFloat(frame) / CGFloat(max(1, total))
        return render(CGSize(width: 88, height: 88)) { w, h in
            let ctx = UIGraphicsGetCurrentContext()
            ctx?.setFillColor(SKColor(red: 0.72, green: 0.12, blue: 0.02, alpha: 0.25).cgColor)
            ctx?.fillEllipse(in: CGRect(x: 0, y: 0, width: w, height: h))

            let chunk = UIBezierPath()
            let bump = sin(phase * .pi * 2) * 0.06
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

    private static func ensure(_ name: String, make: () -> SKTexture) {
        if TextureCache.optional(name) != nil { return }
        TextureCache.store(name, texture: make())
    }

    /// Classic dodgeable fireball: bright core, hot mid shell, soft outer glow.
    private static func makeFireball(size: CGFloat, outer: SKColor, mid: SKColor, core: SKColor) -> SKTexture {
        let canvas = CGSize(width: size, height: size)
        return render(canvas) { w, h in
            let center = CGPoint(x: w * 0.5, y: h * 0.5)
            let ctx = UIGraphicsGetCurrentContext()

            ctx?.setFillColor(outer.withAlphaComponent(0.35).cgColor)
            ctx?.fillEllipse(in: CGRect(x: 0, y: 0, width: w, height: h))

            let petal = UIBezierPath()
            petal.move(to: CGPoint(x: w * 0.5, y: h * 0.02))
            petal.addCurve(
                to: CGPoint(x: w * 0.18, y: h * 0.55),
                controlPoint1: CGPoint(x: w * 0.28, y: h * 0.12),
                controlPoint2: CGPoint(x: w * 0.12, y: h * 0.35)
            )
            petal.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.92),
                controlPoint1: CGPoint(x: w * 0.22, y: h * 0.78),
                controlPoint2: CGPoint(x: w * 0.38, y: h * 0.90)
            )
            petal.addCurve(
                to: CGPoint(x: w * 0.82, y: h * 0.55),
                controlPoint1: CGPoint(x: w * 0.62, y: h * 0.90),
                controlPoint2: CGPoint(x: w * 0.78, y: h * 0.78)
            )
            petal.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.02),
                controlPoint1: CGPoint(x: w * 0.88, y: h * 0.35),
                controlPoint2: CGPoint(x: w * 0.72, y: h * 0.12)
            )
            petal.close()
            outer.setFill()
            petal.fill()

            UIBezierPath(ovalIn: CGRect(x: w * 0.16, y: h * 0.22, width: w * 0.68, height: h * 0.62))
                .fill(with: mid, alpha: 1)
            UIBezierPath(ovalIn: CGRect(x: w * 0.28, y: h * 0.34, width: w * 0.44, height: h * 0.40))
                .fill(with: core, alpha: 1)
            ctx?.setFillColor(UIColor.white.withAlphaComponent(0.55).cgColor)
            ctx?.fillEllipse(in: CGRect(
                x: center.x - w * 0.08,
                y: center.y + h * 0.02,
                width: w * 0.14,
                height: h * 0.14
            ))
        }
    }

    private static func makeGlowOrb(size: CGFloat, fill: SKColor, core: SKColor) -> SKTexture {
        let canvas = CGSize(width: size, height: size)
        return render(canvas) { w, h in
            let center = CGPoint(x: w * 0.5, y: h * 0.5)
            let glow = CGRect(x: 0, y: 0, width: w, height: h)
            UIBezierPath(ovalIn: glow).fill(with: core, alpha: 0.28)
            let outer = CGRect(x: w * 0.06, y: h * 0.06, width: w * 0.88, height: h * 0.88)
            UIBezierPath(ovalIn: outer).fill(with: fill, alpha: 1)
            let inner = CGRect(x: w * 0.22, y: h * 0.22, width: w * 0.56, height: h * 0.56)
            UIBezierPath(ovalIn: inner).fill(with: core, alpha: 1)
            let ctx = UIGraphicsGetCurrentContext()
            ctx?.setStrokeColor(UIColor(white: 1, alpha: 0.4).cgColor)
            ctx?.setLineWidth(2)
            ctx?.strokeEllipse(in: outer.insetBy(dx: 1, dy: 1))
            ctx?.setFillColor(UIColor.white.withAlphaComponent(0.5).cgColor)
            ctx?.fillEllipse(in: CGRect(x: center.x - w * 0.08, y: center.y + h * 0.12, width: w * 0.14, height: h * 0.14))
        }
    }

    private static func makeRingOrb(size: CGFloat, outer: SKColor, ring: SKColor, core: SKColor) -> SKTexture {
        let canvas = CGSize(width: size, height: size)
        return render(canvas) { w, h in
            let center = CGPoint(x: w * 0.5, y: h * 0.5)
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: w, height: h)).fill(with: outer, alpha: 1)
            let ringPath = UIBezierPath(ovalIn: CGRect(x: w * 0.12, y: h * 0.12, width: w * 0.76, height: h * 0.76))
            ring.setStroke()
            ringPath.lineWidth = max(3, w * 0.06)
            ringPath.stroke()
            UIBezierPath(ovalIn: CGRect(x: w * 0.30, y: h * 0.30, width: w * 0.40, height: h * 0.40))
                .fill(with: core, alpha: 1)
            let ctx = UIGraphicsGetCurrentContext()
            ctx?.setFillColor(UIColor.white.withAlphaComponent(0.45).cgColor)
            ctx?.fillEllipse(in: CGRect(x: center.x - w * 0.06, y: center.y + h * 0.04, width: w * 0.12, height: h * 0.12))
        }
    }

    private static func makeMinion(size: CGFloat, body: SKColor, glow: SKColor) -> SKTexture {
        let canvas = CGSize(width: size, height: size)
        return render(canvas) { w, h in
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: w, height: h)).fill(with: glow, alpha: 0.28)
            let hull = UIBezierPath()
            hull.move(to: CGPoint(x: w * 0.5, y: h * 0.08))
            hull.addLine(to: CGPoint(x: w * 0.86, y: h * 0.62))
            hull.addLine(to: CGPoint(x: w * 0.68, y: h * 0.90))
            hull.addLine(to: CGPoint(x: w * 0.32, y: h * 0.90))
            hull.addLine(to: CGPoint(x: w * 0.14, y: h * 0.62))
            hull.close()
            body.setFill()
            hull.fill()
            glow.withAlphaComponent(0.9).setStroke()
            hull.lineWidth = 2
            hull.stroke()
            UIBezierPath(ovalIn: CGRect(x: w * 0.36, y: h * 0.34, width: w * 0.28, height: h * 0.28))
                .fill(with: glow, alpha: 1)
            UIBezierPath(ovalIn: CGRect(x: w * 0.42, y: h * 0.40, width: w * 0.12, height: h * 0.12))
                .fill(with: SKColor.white, alpha: 0.7)
        }
    }

    private static func makeSlimeBlob(size: CGFloat, fill: SKColor, highlight: SKColor) -> SKTexture {
        let canvas = CGSize(width: size, height: size)
        return render(canvas) { w, h in
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: w, height: h)).fill(with: fill, alpha: 0.25)
            let blob = UIBezierPath(ovalIn: CGRect(x: w * 0.08, y: h * 0.12, width: w * 0.84, height: h * 0.76))
            fill.setFill()
            blob.fill()
            SKColor(white: 0.1, alpha: 0.28).setStroke()
            blob.lineWidth = 2
            blob.stroke()
            UIBezierPath(ovalIn: CGRect(x: w * 0.18, y: h * 0.22, width: w * 0.34, height: h * 0.28)).fill(with: highlight, alpha: 1)
            UIBezierPath(ovalIn: CGRect(x: w * 0.56, y: h * 0.48, width: w * 0.16, height: h * 0.14)).fill(with: highlight, alpha: 0.7)
            UIBezierPath(ovalIn: CGRect(x: w * 0.28, y: h * 0.58, width: w * 0.12, height: h * 0.10)).fill(with: highlight, alpha: 0.55)
        }
    }

    private static func makeShard(size: CGSize, fill: SKColor, edge: SKColor) -> SKTexture {
        render(size) { w, h in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: w * 0.5, y: h * 0.04))
            path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.72))
            path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.96))
            path.addLine(to: CGPoint(x: w * 0.38, y: h * 0.96))
            path.addLine(to: CGPoint(x: w * 0.12, y: h * 0.72))
            path.close()
            fill.setFill()
            path.fill()
            edge.withAlphaComponent(0.9).setStroke()
            path.lineWidth = 2.5
            path.stroke()
            let gloss = UIBezierPath()
            gloss.move(to: CGPoint(x: w * 0.48, y: h * 0.18))
            gloss.addLine(to: CGPoint(x: w * 0.58, y: h * 0.62))
            gloss.addLine(to: CGPoint(x: w * 0.46, y: h * 0.62))
            gloss.close()
            SKColor(white: 1, alpha: 0.4).setFill()
            gloss.fill()
        }
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
