//
//  BossAttackTextures.swift
//  ApolloX
//
//  Procedural boss projectile sprites — dodgeable fireballs / shards / blobs
//  with one visual identity per monster.
//

import SpriteKit
import UIKit

enum BossAttackTextures {
    static let cosmicBolt = "bossProj_cosmic"
    static let nebulaFlame = "bossProj_nebulaFlame"
    static let clawShard = "bossProj_claw"
    static let acidBall = "bossProj_acidBall"
    static let acidDrip = "bossProj_acidDrip"
    static let acidSplat = "bossProj_acidSplat"
    static let iceShard = "bossProj_ice"
    static let magmaBoulder = "bossProj_magma"
    static let voidOrb = "bossProj_void"

    static func registerTextures() {
        guard TextureCache.optional(cosmicBolt) == nil else { return }
        TextureCache.store(cosmicBolt, texture: makeFireball(
            size: 80,
            outer: SKColor(red: 0.55, green: 0.18, blue: 0.98, alpha: 1),
            mid: SKColor(red: 0.78, green: 0.42, blue: 1.0, alpha: 1),
            core: SKColor(red: 0.98, green: 0.88, blue: 1.0, alpha: 1)
        ))
        TextureCache.store(nebulaFlame, texture: makeFireball(
            size: 72,
            outer: SKColor(red: 0.72, green: 0.22, blue: 1.0, alpha: 1),
            mid: SKColor(red: 0.95, green: 0.45, blue: 0.85, alpha: 1),
            core: SKColor(red: 1.0, green: 0.92, blue: 0.75, alpha: 1)
        ))
        TextureCache.store(clawShard, texture: makeShard(
            size: CGSize(width: 56, height: 96),
            fill: SKColor(red: 0.95, green: 0.12, blue: 0.14, alpha: 1),
            edge: SKColor(red: 1.0, green: 0.55, blue: 0.35, alpha: 1)
        ))
        TextureCache.store(acidBall, texture: makeSlimeBlob(
            size: 68,
            fill: SKColor(red: 0.35, green: 0.92, blue: 0.18, alpha: 1),
            highlight: SKColor(red: 0.72, green: 1.0, blue: 0.42, alpha: 0.9)
        ))
        TextureCache.store(acidDrip, texture: makeSlimeBlob(
            size: 40,
            fill: SKColor(red: 0.28, green: 0.82, blue: 0.12, alpha: 1),
            highlight: SKColor(red: 0.62, green: 1.0, blue: 0.35, alpha: 0.85)
        ))
        TextureCache.store(acidSplat, texture: makeSlimeBlob(
            size: 118,
            fill: SKColor(red: 0.22, green: 0.78, blue: 0.08, alpha: 1),
            highlight: SKColor(red: 0.55, green: 0.98, blue: 0.22, alpha: 0.9)
        ))
        TextureCache.store(iceShard, texture: makeShard(
            size: CGSize(width: 50, height: 102),
            fill: SKColor(red: 0.55, green: 0.88, blue: 1.0, alpha: 1),
            edge: SKColor(red: 0.92, green: 0.98, blue: 1.0, alpha: 1)
        ))
        TextureCache.store(magmaBoulder, texture: makeFireball(
            size: 100,
            outer: SKColor(red: 0.72, green: 0.12, blue: 0.02, alpha: 1),
            mid: SKColor(red: 0.98, green: 0.42, blue: 0.06, alpha: 1),
            core: SKColor(red: 1.0, green: 0.88, blue: 0.28, alpha: 1)
        ))
        TextureCache.store(voidOrb, texture: makeGlowOrb(
            size: 72,
            fill: SKColor(red: 0.14, green: 0.02, blue: 0.32, alpha: 1),
            core: SKColor(red: 0.72, green: 0.22, blue: 1.0, alpha: 1)
        ))
    }

    /// Classic dodgeable fireball: bright core, hot mid shell, soft outer glow.
    private static func makeFireball(size: CGFloat, outer: SKColor, mid: SKColor, core: SKColor) -> SKTexture {
        let canvas = CGSize(width: size, height: size)
        return render(canvas) { w, h in
            let center = CGPoint(x: w * 0.5, y: h * 0.5)
            let ctx = UIGraphicsGetCurrentContext()

            // Soft outer glow
            ctx?.setFillColor(outer.withAlphaComponent(0.35).cgColor)
            ctx?.fillEllipse(in: CGRect(x: 0, y: 0, width: w, height: h))

            // Flame petal tips
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
            let outer = CGRect(x: w * 0.06, y: h * 0.06, width: w * 0.88, height: h * 0.88)
            UIBezierPath(ovalIn: outer).fill(with: fill, alpha: 1)
            let inner = CGRect(x: w * 0.22, y: h * 0.22, width: w * 0.56, height: h * 0.56)
            UIBezierPath(ovalIn: inner).fill(with: core, alpha: 1)
            let ctx = UIGraphicsGetCurrentContext()
            ctx?.setStrokeColor(UIColor(white: 1, alpha: 0.35).cgColor)
            ctx?.setLineWidth(2)
            ctx?.strokeEllipse(in: outer.insetBy(dx: 1, dy: 1))
            ctx?.setFillColor(UIColor.white.withAlphaComponent(0.45).cgColor)
            ctx?.fillEllipse(in: CGRect(x: center.x - w * 0.08, y: center.y + h * 0.12, width: w * 0.14, height: h * 0.14))
        }
    }

    private static func makeSlimeBlob(size: CGFloat, fill: SKColor, highlight: SKColor) -> SKTexture {
        let canvas = CGSize(width: size, height: size)
        return render(canvas) { w, h in
            let blob = UIBezierPath(ovalIn: CGRect(x: w * 0.08, y: h * 0.12, width: w * 0.84, height: h * 0.76))
            fill.setFill()
            blob.fill()
            SKColor(white: 0.1, alpha: 0.35).setStroke()
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
            edge.withAlphaComponent(0.85).setStroke()
            path.lineWidth = 2.5
            path.stroke()
            let gloss = UIBezierPath()
            gloss.move(to: CGPoint(x: w * 0.48, y: h * 0.18))
            gloss.addLine(to: CGPoint(x: w * 0.58, y: h * 0.62))
            gloss.addLine(to: CGPoint(x: w * 0.46, y: h * 0.62))
            gloss.close()
            SKColor(white: 1, alpha: 0.35).setFill()
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
