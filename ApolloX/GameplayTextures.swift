//
//  GameplayTextures.swift
//  ApolloX
//
//  Procedural sprites for falling lane cannons and their warnings.
//

import SpriteKit
import UIKit

enum GameplayTextures {
    static let fallingRocketName = "fallingRocket"
    static let warningBadgeName = "rocketWarningBadge"
    static let yellowClearMineName = "yellowClearMine"

    /// Tall gunmetal cannon drawn muzzle-down (lane hazard after the ! warning).
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

            // Soft smoke puff at the breech (top) — particles add the live trail.
            cg.saveGState()
            cg.setFillColor(UIColor(white: 0.78, alpha: 0.35).cgColor)
            cg.fillEllipse(in: CGRect(x: w * 0.22, y: h * 0.01, width: w * 0.56, height: h * 0.14))
            cg.setFillColor(UIColor(white: 0.88, alpha: 0.28).cgColor)
            cg.fillEllipse(in: CGRect(x: w * 0.30, y: h * 0.00, width: w * 0.28, height: h * 0.09))
            cg.restoreGState()

            // Breech block (rear of cannon).
            let breech = UIBezierPath(
                roundedRect: CGRect(x: w * 0.22, y: h * 0.12, width: w * 0.56, height: h * 0.16),
                cornerRadius: w * 0.06
            )
            SKColor(red: 0.22, green: 0.24, blue: 0.28, alpha: 1).setFill()
            breech.fill()
            SKColor(white: 0.08, alpha: 0.7).setStroke()
            breech.lineWidth = 2.5
            breech.stroke()

            // Main barrel tube.
            let barrel = UIBezierPath(
                roundedRect: CGRect(x: w * 0.32, y: h * 0.24, width: w * 0.36, height: h * 0.52),
                cornerRadius: w * 0.04
            )
            SKColor(red: 0.38, green: 0.40, blue: 0.44, alpha: 1).setFill()
            barrel.fill()

            // Barrel highlight strip.
            let highlight = UIBezierPath(
                roundedRect: CGRect(x: w * 0.36, y: h * 0.28, width: w * 0.08, height: h * 0.42),
                cornerRadius: 3
            )
            SKColor(white: 1, alpha: 0.18).setFill()
            highlight.fill()

            // Reinforcing rings.
            SKColor(red: 0.18, green: 0.19, blue: 0.22, alpha: 1).setFill()
            for frac in [0.30, 0.46, 0.62] as [CGFloat] {
                let ring = UIBezierPath(
                    roundedRect: CGRect(x: w * 0.28, y: h * frac, width: w * 0.44, height: h * 0.045),
                    cornerRadius: 3
                )
                ring.fill()
            }

            // Trunnion / carriage knobs so it reads as a cannon, not a missile.
            func trunnion(left: Bool) {
                let cx = left ? w * 0.22 : w * 0.78
                let rect = CGRect(x: cx - w * 0.07, y: h * 0.40, width: w * 0.14, height: w * 0.14)
                SKColor(red: 0.28, green: 0.30, blue: 0.34, alpha: 1).setFill()
                UIBezierPath(ovalIn: rect).fill()
                SKColor(white: 0.1, alpha: 0.65).setStroke()
                let outline = UIBezierPath(ovalIn: rect)
                outline.lineWidth = 2
                outline.stroke()
            }
            trunnion(left: true)
            trunnion(left: false)

            // Hazard band near the muzzle.
            let hazard = UIBezierPath(
                roundedRect: CGRect(x: w * 0.30, y: h * 0.70, width: w * 0.40, height: h * 0.06),
                cornerRadius: 2
            )
            SKColor(red: 0.95, green: 0.72, blue: 0.08, alpha: 1).setFill()
            hazard.fill()
            SKColor(red: 0.12, green: 0.10, blue: 0.04, alpha: 1).setFill()
            for i in 0..<4 {
                let x = w * 0.32 + CGFloat(i) * w * 0.09
                UIBezierPath(rect: CGRect(x: x, y: h * 0.70, width: w * 0.045, height: h * 0.06)).fill()
            }

            // Muzzle flare / ring at the bottom.
            let muzzleOuter = UIBezierPath(
                roundedRect: CGRect(x: w * 0.26, y: h * 0.78, width: w * 0.48, height: h * 0.12),
                cornerRadius: w * 0.05
            )
            SKColor(red: 0.20, green: 0.21, blue: 0.24, alpha: 1).setFill()
            muzzleOuter.fill()

            // Dark bore opening.
            let bore = UIBezierPath(ovalIn: CGRect(x: w * 0.36, y: h * 0.86, width: w * 0.28, height: h * 0.10))
            SKColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1).setFill()
            bore.fill()
            SKColor(red: 0.55, green: 0.22, blue: 0.08, alpha: 0.75).setStroke()
            let boreGlow = UIBezierPath(ovalIn: CGRect(x: w * 0.38, y: h * 0.875, width: w * 0.24, height: h * 0.07))
            boreGlow.lineWidth = 2.5
            boreGlow.stroke()

            // Subtle outline for contrast on dark nebula backgrounds.
            let outline = UIBezierPath(
                roundedRect: CGRect(x: w * 0.20, y: h * 0.10, width: w * 0.60, height: h * 0.82),
                cornerRadius: 10
            )
            SKColor(white: 1, alpha: 0.22).setStroke()
            outline.lineWidth = 2
            outline.stroke()
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = true
        return texture
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
