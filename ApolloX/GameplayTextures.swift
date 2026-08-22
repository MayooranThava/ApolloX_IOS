//
//  GameplayTextures.swift
//  ApolloX
//
//  Procedural sprites for falling nuclear rockets and their lane warnings.
//

import SpriteKit
import UIKit

enum GameplayTextures {
    static let fallingRocketName = "fallingRocket"
    static let warningBadgeName = "rocketWarningBadge"
    static let yellowClearMineName = "yellowClearMine"

    /// Tall flying rocket drawn nose-down (lane hazard after the ! warning).
    static let fallingRocketPixelSize = CGSize(width: 96, height: 240)
    static let yellowClearMinePixelSize = CGSize(width: 128, height: 128)

    static func registerProceduralTextures() {
        PlayerShipCatalog.registerTextures()
        guard TextureCache.optional(fallingRocketName) == nil else { return }
        TextureCache.store(fallingRocketName, texture: makeFallingRocket())
        TextureCache.store(warningBadgeName, texture: makeWarningBadge())
        TextureCache.store(yellowClearMineName, texture: makeYellowClearMine())
        BossAttackTextures.registerTextures()
    }

    private static func makeFallingRocket() -> SKTexture {
        let size = fallingRocketPixelSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let w = size.width
            let h = size.height

            // Soft baked exhaust glow at the tail (top) — live smoke particles trail behind.
            cg.saveGState()
            cg.setFillColor(UIColor(red: 1.0, green: 0.55, blue: 0.12, alpha: 0.35).cgColor)
            cg.fillEllipse(in: CGRect(x: w * 0.28, y: h * 0.00, width: w * 0.44, height: h * 0.12))
            cg.restoreGState()

            // Exhaust nozzle / tail ring (top — rocket falls nose-down).
            let nozzle = UIBezierPath(
                roundedRect: CGRect(x: w * 0.30, y: h * 0.10, width: w * 0.40, height: h * 0.10),
                cornerRadius: w * 0.04
            )
            SKColor(red: 0.22, green: 0.24, blue: 0.28, alpha: 1).setFill()
            nozzle.fill()
            SKColor(white: 0.08, alpha: 0.7).setStroke()
            nozzle.lineWidth = 2
            nozzle.stroke()

            // Main fuselage.
            let body = UIBezierPath(
                roundedRect: CGRect(x: w * 0.28, y: h * 0.18, width: w * 0.44, height: h * 0.52),
                cornerRadius: w * 0.06
            )
            SKColor(red: 0.72, green: 0.74, blue: 0.78, alpha: 1).setFill()
            body.fill()
            SKColor(white: 0.15, alpha: 0.55).setStroke()
            body.lineWidth = 2.5
            body.stroke()

            // Fuselage highlight.
            let highlight = UIBezierPath(
                roundedRect: CGRect(x: w * 0.34, y: h * 0.22, width: w * 0.08, height: h * 0.40),
                cornerRadius: 3
            )
            SKColor(white: 1, alpha: 0.22).setFill()
            highlight.fill()

            // Side fins near the tail.
            func fin(left: Bool) {
                let path = UIBezierPath()
                let cx = left ? w * 0.28 : w * 0.72
                path.move(to: CGPoint(x: cx, y: h * 0.22))
                path.addLine(to: CGPoint(x: left ? w * 0.06 : w * 0.94, y: h * 0.12))
                path.addLine(to: CGPoint(x: left ? w * 0.08 : w * 0.92, y: h * 0.28))
                path.addLine(to: CGPoint(x: cx, y: h * 0.34))
                path.close()
                SKColor(red: 0.85, green: 0.18, blue: 0.12, alpha: 1).setFill()
                path.fill()
                SKColor(white: 0.1, alpha: 0.5).setStroke()
                path.lineWidth = 1.5
                path.stroke()
            }
            fin(left: true)
            fin(left: false)

            // Nuclear radiation warning disc on the body.
            drawNuclearWarning(
                center: CGPoint(x: w * 0.5, y: h * 0.42),
                radius: w * 0.20,
                in: cg
            )

            // Red nose cone pointing down.
            let nose = UIBezierPath()
            nose.move(to: CGPoint(x: w * 0.5, y: h * 0.98))
            nose.addLine(to: CGPoint(x: w * 0.22, y: h * 0.70))
            nose.addLine(to: CGPoint(x: w * 0.78, y: h * 0.70))
            nose.close()
            SKColor(red: 0.90, green: 0.16, blue: 0.12, alpha: 1).setFill()
            nose.fill()
            SKColor(white: 1, alpha: 0.35).setStroke()
            nose.lineWidth = 2
            nose.stroke()

            // Nose tip highlight.
            let tip = UIBezierPath()
            tip.move(to: CGPoint(x: w * 0.5, y: h * 0.96))
            tip.addLine(to: CGPoint(x: w * 0.40, y: h * 0.82))
            tip.addLine(to: CGPoint(x: w * 0.60, y: h * 0.82))
            tip.close()
            SKColor(red: 1.0, green: 0.45, blue: 0.28, alpha: 0.55).setFill()
            tip.fill()

            // Subtle outline for contrast on dark nebula backgrounds.
            let outline = UIBezierPath(
                roundedRect: CGRect(x: w * 0.14, y: h * 0.08, width: w * 0.72, height: h * 0.86),
                cornerRadius: 12
            )
            SKColor(white: 1, alpha: 0.20).setStroke()
            outline.lineWidth = 2
            outline.stroke()
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = true
        return texture
    }

    /// Classic yellow radiation trefoil used on the falling nuclear rocket body.
    private static func drawNuclearWarning(center: CGPoint, radius: CGFloat, in cg: CGContext) {
        let disc = UIBezierPath(ovalIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        SKColor(red: 1.0, green: 0.86, blue: 0.05, alpha: 1).setFill()
        disc.fill()
        SKColor(white: 0.08, alpha: 0.85).setStroke()
        disc.lineWidth = max(2, radius * 0.08)
        disc.stroke()

        // Three black radiation blades around a center disc.
        SKColor(white: 0.08, alpha: 1).setFill()
        let bladeInner = radius * 0.22
        let bladeOuter = radius * 0.82
        for i in 0..<3 {
            let angle = CGFloat(i) * (2 * .pi / 3) - .pi / 2
            let path = UIBezierPath()
            path.addArc(
                withCenter: center,
                radius: bladeOuter,
                startAngle: angle - 0.42,
                endAngle: angle + 0.42,
                clockwise: true
            )
            path.addArc(
                withCenter: center,
                radius: bladeInner,
                startAngle: angle + 0.42,
                endAngle: angle - 0.42,
                clockwise: false
            )
            path.close()
            path.fill()
        }

        let core = UIBezierPath(ovalIn: CGRect(
            x: center.x - bladeInner * 0.85,
            y: center.y - bladeInner * 0.85,
            width: bladeInner * 1.7,
            height: bladeInner * 1.7
        ))
        SKColor(white: 0.08, alpha: 1).setFill()
        core.fill()

        // Silence unused-cg warning when only UIBezierPath is used above.
        _ = cg
    }

    /// Golden hazard mine with pulsing core — shoot it to chain-clear the screen.
    private static func makeYellowClearMine() -> SKTexture {
        let size = yellowClearMinePixelSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let w = size.width
            let h = size.height
            let center = CGPoint(x: w * 0.5, y: h * 0.5)
            let outerRadius = w * 0.42

            // Soft outer glow.
            cg.saveGState()
            let glowRect = CGRect(x: center.x - outerRadius * 1.35, y: center.y - outerRadius * 1.35,
                                  width: outerRadius * 2.7, height: outerRadius * 2.7)
            cg.setFillColor(UIColor(red: 1.0, green: 0.82, blue: 0.08, alpha: 0.22).cgColor)
            cg.fillEllipse(in: glowRect)
            cg.restoreGState()

            // Main spherical body.
            let bodyRect = CGRect(x: center.x - outerRadius, y: center.y - outerRadius,
                                  width: outerRadius * 2, height: outerRadius * 2)
            cg.saveGState()
            cg.addEllipse(in: bodyRect)
            cg.clip()
            let colors = [
                UIColor(red: 1.0, green: 0.95, blue: 0.45, alpha: 1).cgColor,
                UIColor(red: 1.0, green: 0.72, blue: 0.05, alpha: 1).cgColor,
                UIColor(red: 0.92, green: 0.48, blue: 0.02, alpha: 1).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.55, 1.0]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: center.x - outerRadius * 0.4, y: center.y + outerRadius * 0.5),
                    end: CGPoint(x: center.x + outerRadius * 0.6, y: center.y - outerRadius * 0.7),
                    options: []
                )
            }
            cg.restoreGState()

            // Hazard chevrons.
            SKColor(red: 0.15, green: 0.08, blue: 0.02, alpha: 0.85).setFill()
            for angle in stride(from: 0.0, to: 360.0, by: 60.0) {
                let rad = angle * .pi / 180
                let cx = center.x + cos(rad) * outerRadius * 0.55
                let cy = center.y + sin(rad) * outerRadius * 0.55
                let tri = UIBezierPath()
                tri.move(to: CGPoint(x: cx, y: cy + outerRadius * 0.14))
                tri.addLine(to: CGPoint(x: cx - outerRadius * 0.11, y: cy - outerRadius * 0.06))
                tri.addLine(to: CGPoint(x: cx + outerRadius * 0.11, y: cy - outerRadius * 0.06))
                tri.close()
                tri.fill()
            }

            // Bright core.
            let coreRect = CGRect(x: center.x - outerRadius * 0.22, y: center.y - outerRadius * 0.22,
                                  width: outerRadius * 0.44, height: outerRadius * 0.44)
            SKColor(red: 1.0, green: 0.98, blue: 0.75, alpha: 1).setFill()
            UIBezierPath(ovalIn: coreRect).fill()
            SKColor(red: 1.0, green: 0.55, blue: 0.05, alpha: 0.9).setStroke()
            UIBezierPath(ovalIn: coreRect.insetBy(dx: 2, dy: 2)).lineWidth = 2.5
            UIBezierPath(ovalIn: coreRect.insetBy(dx: 2, dy: 2)).stroke()

            // Specular highlight.
            let highlight = UIBezierPath(ovalIn: CGRect(x: center.x - outerRadius * 0.35, y: center.y + outerRadius * 0.05,
                                                        width: outerRadius * 0.35, height: outerRadius * 0.18))
            SKColor(white: 1, alpha: 0.55).setFill()
            highlight.fill()

            // Outline for contrast on dark backgrounds.
            SKColor(white: 1, alpha: 0.35).setStroke()
            UIBezierPath(ovalIn: bodyRect.insetBy(dx: 2, dy: 2)).lineWidth = 3
            UIBezierPath(ovalIn: bodyRect.insetBy(dx: 2, dy: 2)).stroke()
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = true
        return texture
    }

    /// Red warning triangle with a bold white exclamation mark.
    private static func makeWarningBadge() -> SKTexture {
        let size = CGSize(width: 128, height: 128)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            let w = size.width
            let h = size.height
            let triangle = UIBezierPath()
            triangle.move(to: CGPoint(x: w * 0.5, y: h * 0.06))
            triangle.addLine(to: CGPoint(x: w * 0.94, y: h * 0.92))
            triangle.addLine(to: CGPoint(x: w * 0.06, y: h * 0.92))
            triangle.close()
            SKColor(red: 0.98, green: 0.12, blue: 0.08, alpha: 1).setFill()
            triangle.fill()
            SKColor(white: 1, alpha: 0.95).setStroke()
            triangle.lineWidth = 6
            triangle.stroke()

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 62),
                .foregroundColor: UIColor.white
            ]
            let text = "!" as NSString
            let textSize = text.size(withAttributes: attrs)
            text.draw(
                at: CGPoint(x: (w - textSize.width) * 0.5, y: (h - textSize.height) * 0.5 + 4),
                withAttributes: attrs
            )
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = true
        return texture
    }
}

/// Jetpack Joyride–style lane warning: red danger column + edge badge.
final class RocketWarningNode: SKNode {
    private let stripe: SKSpriteNode
    private let badge: SKSpriteNode

    init(columnX: CGFloat, playArea: CGRect, badgeScale: CGFloat = 1.35) {
        stripe = SKSpriteNode(
            color: SKColor(red: 1.0, green: 0.08, blue: 0.06, alpha: 0.42),
            size: CGSize(width: GameRules.rocketWarningStripeWidth, height: playArea.height)
        )
        badge = SKSpriteNode(texture: TextureCache.texture(GameplayTextures.warningBadgeName))
        super.init()

        name = GameConstants.NodeName.rocketWarning
        zPosition = GameConstants.Z.overlay

        stripe.position = CGPoint(x: columnX, y: playArea.midY)
        stripe.zPosition = 0
        addChild(stripe)

        badge.setScale(badgeScale)
        badge.position = CGPoint(x: columnX, y: playArea.maxY - 118)
        badge.zPosition = 1
        addChild(badge)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func playFlash(duration: TimeInterval, interval: TimeInterval) {
        alpha = 1
        let pulseCount = max(4, Int(duration / (interval * 2)))
        badge.run(.repeat(.sequence([
            .fadeAlpha(to: 0.25, duration: interval),
            .fadeAlpha(to: 1.0, duration: interval)
        ]), count: pulseCount))
        stripe.run(.repeat(.sequence([
            .fadeAlpha(to: 0.18, duration: interval),
            .fadeAlpha(to: 0.55, duration: interval)
        ]), count: pulseCount))
        run(.sequence([
            .wait(forDuration: duration),
            .fadeOut(withDuration: interval),
            .removeFromParent()
        ]))
    }
}
