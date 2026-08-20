//
//  BossAttackTextures.swift
//  ApolloX
//
//  Procedural boss projectile sprites — one visual identity per monster.
//

import SpriteKit
import UIKit

enum BossAttackTextures {
    static let cosmicBolt = "bossProj_cosmic"
    static let clawShard = "bossProj_claw"
    static let acidBall = "bossProj_acidBall"
    static let acidDrip = "bossProj_acidDrip"
    static let acidSplat = "bossProj_acidSplat"
    static let iceShard = "bossProj_ice"
    static let magmaBoulder = "bossProj_magma"
    static let voidOrb = "bossProj_void"

    static func registerTextures() {
        guard TextureCache.optional(cosmicBolt) == nil else { return }
        TextureCache.store(cosmicBolt, texture: makeGlowOrb(
            size: 72,
            fill: SKColor(red: 0.62, green: 0.22, blue: 0.98, alpha: 1),
            core: SKColor(red: 0.92, green: 0.72, blue: 1.0, alpha: 1)
        ))
        TextureCache.store(clawShard, texture: makeShard(
            size: CGSize(width: 56, height: 88),
            fill: SKColor(red: 0.95, green: 0.12, blue: 0.14, alpha: 1)
        ))
        TextureCache.store(acidBall, texture: makeSlimeBlob(
            size: 64,
            fill: SKColor(red: 0.35, green: 0.92, blue: 0.18, alpha: 1),
            highlight: SKColor(red: 0.72, green: 1.0, blue: 0.42, alpha: 0.9)
        ))
        TextureCache.store(acidDrip, texture: makeSlimeBlob(
            size: 36,
            fill: SKColor(red: 0.28, green: 0.82, blue: 0.12, alpha: 1),
            highlight: SKColor(red: 0.62, green: 1.0, blue: 0.35, alpha: 0.85)
        ))
        TextureCache.store(acidSplat, texture: makeSlimeBlob(
            size: 112,
            fill: SKColor(red: 0.22, green: 0.78, blue: 0.08, alpha: 1),
            highlight: SKColor(red: 0.55, green: 0.98, blue: 0.22, alpha: 0.9)
        ))
        TextureCache.store(iceShard, texture: makeShard(
            size: CGSize(width: 48, height: 96),
            fill: SKColor(red: 0.55, green: 0.88, blue: 1.0, alpha: 1)
        ))
        TextureCache.store(magmaBoulder, texture: makeGlowOrb(
            size: 96,
            fill: SKColor(red: 0.92, green: 0.28, blue: 0.05, alpha: 1),
            core: SKColor(red: 1.0, green: 0.72, blue: 0.12, alpha: 1)
        ))
        TextureCache.store(voidOrb, texture: makeGlowOrb(
            size: 68,
            fill: SKColor(red: 0.18, green: 0.04, blue: 0.38, alpha: 1),
            core: SKColor(red: 0.62, green: 0.18, blue: 0.95, alpha: 1)
        ))
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

    private static func makeShard(size: CGSize, fill: SKColor) -> SKTexture {
        render(size) { w, h in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: w * 0.5, y: h * 0.04))
            path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.92))
            path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.92))
            path.close()
            fill.setFill()
            path.fill()
            SKColor(white: 1, alpha: 0.45).setStroke()
            path.lineWidth = 2
            path.stroke()
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
