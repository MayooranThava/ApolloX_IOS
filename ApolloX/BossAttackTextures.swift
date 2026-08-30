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

    static func registerTextures() {
        guard TextureCache.optional(voidPulse) == nil else { return }

        TextureCache.store(voidPulse, texture: makeFireball(
            size: 80,
            outer: SKColor(red: 0.52, green: 0.14, blue: 0.98, alpha: 1),
            mid: SKColor(red: 0.78, green: 0.40, blue: 1.0, alpha: 1),
            core: SKColor(red: 0.98, green: 0.88, blue: 1.0, alpha: 1)
        ))
        TextureCache.store(tentacleOrb, texture: makeGlowOrb(
            size: 68,
            fill: SKColor(red: 0.28, green: 0.04, blue: 0.48, alpha: 1),
            core: SKColor(red: 0.92, green: 0.42, blue: 1.0, alpha: 1)
        ))
        TextureCache.store(gravityWell, texture: makeRingOrb(
            size: 96,
            outer: SKColor(red: 0.55, green: 0.18, blue: 0.95, alpha: 0.55),
            ring: SKColor(red: 0.82, green: 0.48, blue: 1.0, alpha: 1),
            core: SKColor(red: 0.18, green: 0.02, blue: 0.32, alpha: 1)
        ))
        TextureCache.store(voidMinion, texture: makeMinion(
            size: 56,
            body: SKColor(red: 0.42, green: 0.12, blue: 0.78, alpha: 1),
            glow: SKColor(red: 0.88, green: 0.45, blue: 1.0, alpha: 1)
        ))

        TextureCache.store(solarFlare, texture: makeFireball(
            size: 78,
            outer: SKColor(red: 0.95, green: 0.32, blue: 0.05, alpha: 1),
            mid: SKColor(red: 1.0, green: 0.62, blue: 0.12, alpha: 1),
            core: SKColor(red: 1.0, green: 0.92, blue: 0.55, alpha: 1)
        ))
        TextureCache.store(orbitalSpark, texture: makeGlowOrb(
            size: 64,
            fill: SKColor(red: 0.85, green: 0.28, blue: 0.05, alpha: 1),
            core: SKColor(red: 1.0, green: 0.82, blue: 0.28, alpha: 1)
        ))
        TextureCache.store(coreLaser, texture: makeShard(
            size: CGSize(width: 36, height: 110),
            fill: SKColor(red: 1.0, green: 0.72, blue: 0.18, alpha: 1),
            edge: SKColor(red: 1.0, green: 0.92, blue: 0.55, alpha: 1)
        ))
        TextureCache.store(meteor, texture: makeFireball(
            size: 92,
            outer: SKColor(red: 0.72, green: 0.18, blue: 0.04, alpha: 1),
            mid: SKColor(red: 0.98, green: 0.48, blue: 0.08, alpha: 1),
            core: SKColor(red: 1.0, green: 0.88, blue: 0.35, alpha: 1)
        ))

        TextureCache.store(realityShard, texture: makeShard(
            size: CGSize(width: 48, height: 100),
            fill: SKColor(red: 0.35, green: 0.88, blue: 1.0, alpha: 1),
            edge: SKColor(red: 0.85, green: 0.98, blue: 1.0, alpha: 1)
        ))
        TextureCache.store(dimensionSlash, texture: makeShard(
            size: CGSize(width: 42, height: 108),
            fill: SKColor(red: 0.22, green: 0.72, blue: 0.98, alpha: 1),
            edge: SKColor(red: 0.70, green: 0.95, blue: 1.0, alpha: 1)
        ))
        TextureCache.store(timeWarpOrb, texture: makeRingOrb(
            size: 88,
            outer: SKColor(red: 0.25, green: 0.75, blue: 0.95, alpha: 0.45),
            ring: SKColor(red: 0.55, green: 0.95, blue: 1.0, alpha: 1),
            core: SKColor(red: 0.08, green: 0.28, blue: 0.42, alpha: 1)
        ))
        TextureCache.store(portalMinion, texture: makeMinion(
            size: 54,
            body: SKColor(red: 0.18, green: 0.62, blue: 0.88, alpha: 1),
            glow: SKColor(red: 0.65, green: 0.95, blue: 1.0, alpha: 1)
        ))

        TextureCache.store(toxicSpray, texture: makeSlimeBlob(
            size: 66,
            fill: SKColor(red: 0.32, green: 0.92, blue: 0.18, alpha: 1),
            highlight: SKColor(red: 0.72, green: 1.0, blue: 0.42, alpha: 0.9)
        ))
        TextureCache.store(sporeBomb, texture: makeSlimeBlob(
            size: 108,
            fill: SKColor(red: 0.22, green: 0.78, blue: 0.08, alpha: 1),
            highlight: SKColor(red: 0.55, green: 0.98, blue: 0.22, alpha: 0.9)
        ))
        TextureCache.store(swarmMinion, texture: makeMinion(
            size: 48,
            body: SKColor(red: 0.28, green: 0.72, blue: 0.12, alpha: 1),
            glow: SKColor(red: 0.72, green: 1.0, blue: 0.35, alpha: 1)
        ))
        TextureCache.store(infectedEgg, texture: makeGlowOrb(
            size: 58,
            fill: SKColor(red: 0.18, green: 0.48, blue: 0.08, alpha: 1),
            core: SKColor(red: 0.55, green: 0.95, blue: 0.22, alpha: 1)
        ))
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
