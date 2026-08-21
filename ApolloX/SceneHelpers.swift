//
//  SceneHelpers.swift
//  ApolloX
//

import SpriteKit
import UIKit

extension SKScene {
    func makeGameLabel(
        text: String,
        fontSize: CGFloat,
        color: SKColor = .white,
        alignment: SKLabelHorizontalAlignmentMode = .center
    ) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: GameFont.resolved(size: fontSize))
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        label.zPosition = GameConstants.Z.hud
        return label
    }

    /// Rolling space backdrop with drifting dust and tier-aware color grading in gameplay.
    @discardableResult
    func addProductionBackground(scrolling: Bool = true) -> ScrollingBackgroundNode? {
        let layout = playfield
        let texture = TextureCache.texture("background")

        childNode(withName: GameConstants.NodeName.scrollingBackground)?.removeFromParent()
        childNode(withName: GameConstants.NodeName.background)?.removeFromParent()
        childNode(withName: GameConstants.NodeName.starDust)?.removeFromParent()

        guard scrolling else {
            let backdrop = SKSpriteNode(texture: texture)
            backdrop.name = GameConstants.NodeName.background
            backdrop.size = layout.visibleRect.size
            backdrop.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            backdrop.zPosition = GameConstants.Z.background
            addChild(backdrop)
            addStarDust(tier: 0)
            applyPerformanceQuality()
            return nil
        }

        let scrollingBackground = ScrollingBackgroundNode()
        scrollingBackground.name = GameConstants.NodeName.scrollingBackground
        scrollingBackground.configure(in: layout.visibleRect, texture: texture)
        addChild(scrollingBackground)

        addStarDust(tier: 0)
        applyPerformanceQuality()
        return scrollingBackground
    }

    func scrollingBackgroundNode() -> ScrollingBackgroundNode? {
        childNode(withName: GameConstants.NodeName.scrollingBackground) as? ScrollingBackgroundNode
    }

    func relayoutProductionBackground() {
        let layout = playfield
        let texture = TextureCache.texture("background")
        if let scrolling = scrollingBackgroundNode() {
            scrolling.relayout(in: layout.visibleRect, texture: texture)
        } else if let backdrop = childNode(withName: GameConstants.NodeName.background) as? SKSpriteNode {
            backdrop.size = layout.visibleRect.size
            backdrop.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        }
        if let dust = childNode(withName: GameConstants.NodeName.starDust) as? SKEmitterNode {
            dust.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            dust.particlePositionRange = CGVector(dx: layout.visibleRect.width, dy: layout.visibleRect.height)
        }
    }

    func addStarDust(tier: Int) {
        childNode(withName: GameConstants.NodeName.starDust)?.removeFromParent()
        let dust = makeStarDustEmitter(tier: tier)
        dust.name = GameConstants.NodeName.starDust
        dust.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        dust.zPosition = GameConstants.Z.background + 1
        dust.targetNode = self
        addChild(dust)
    }

    func makeStarDustEmitter(tier: Int = 0) -> SKEmitterNode {
        let palette = resolvedDustPalette(for: tier)

        let emitter = SKEmitterNode()
        emitter.particleTexture = softDotTexture()
        emitter.particleBirthRate = FramePacing.scaledBirthRate(FramePacing.currentQuality.starDustBirthRate)
        emitter.numParticlesToEmit = 0
        emitter.particleLifetime = 5
        emitter.particleLifetimeRange = 1.5
        emitter.particlePositionRange = CGVector(dx: size.width, dy: size.height)
        emitter.particleSpeed = palette.speed
        emitter.particleSpeedRange = palette.speed * 0.75
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = 0.12
        emitter.particleAlpha = 0.28
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -0.03
        emitter.particleScale = 0.04
        emitter.particleScaleRange = 0.025
        emitter.particleColor = palette.color
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        return emitter
    }

    func updateBackgroundTier(_ tier: Int, animated: Bool) {
        scrollingBackgroundNode()?.setTier(tier, animated: animated)
        if let dust = childNode(withName: GameConstants.NodeName.starDust) as? SKEmitterNode {
            let palette = resolvedDustPalette(for: tier)
            dust.particleColor = palette.color
            dust.particleSpeed = palette.speed
            dust.particleSpeedRange = palette.speed * 0.75
        }
    }

    private func resolvedDustPalette(for tier: Int) -> (color: SKColor, speed: CGFloat) {
        if let palette = scrollingBackgroundNode()?.dustPalette(for: tier) {
            return palette
        }
        return (color: SKColor(white: 0.92, alpha: 1), speed: 18.0)
    }

    func makeEngineEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.name = GameConstants.NodeName.engine
        emitter.particleTexture = softDotTexture()
        emitter.particleBirthRate = FramePacing.scaledBirthRate(FramePacing.currentQuality.engineBirthRate)
        emitter.particleLifetime = 0.34
        emitter.particleLifetimeRange = 0.14
        emitter.particlePositionRange = CGVector(dx: 16, dy: 4)
        emitter.particleSpeed = 140
        emitter.particleSpeedRange = 55
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = 0.42
        emitter.particleAlpha = 0.95
        emitter.particleAlphaRange = 0.15
        emitter.particleAlphaSpeed = -2.6
        emitter.particleScale = 0.16
        emitter.particleScaleRange = 0.08
        emitter.particleScaleSpeed = -0.28
        emitter.particleColor = SKColor(red: 1.0, green: 0.62, blue: 0.25, alpha: 1)
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.particleRotationRange = 0.4
        emitter.targetNode = self
        return emitter
    }

    /// Soft grey smoke plume that trails behind falling lane cannons.
    func makeCannonSmokeEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = softDotTexture()
        let quality = FramePacing.currentQuality
        let baseRate: CGFloat
        switch quality {
        case .high: baseRate = 42
        case .balanced: baseRate = 24
        case .conservative: baseRate = 10
        }
        emitter.particleBirthRate = FramePacing.scaledBirthRate(baseRate)
        emitter.particleLifetime = 0.55
        emitter.particleLifetimeRange = 0.22
        emitter.particlePositionRange = CGVector(dx: 10, dy: 6)
        emitter.particleSpeed = 70
        emitter.particleSpeedRange = 35
        // Smoke drifts upward (opposite of the cannon's fall).
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = 0.55
        emitter.particleAlpha = 0.55
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -0.85
        emitter.particleScale = 0.28
        emitter.particleScaleRange = 0.14
        emitter.particleScaleSpeed = 0.35
        emitter.particleColor = SKColor(white: 0.72, alpha: 1)
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .alpha
        emitter.particleRotationRange = 1.2
        emitter.particleRotationSpeed = 0.8
        emitter.targetNode = self
        return emitter
    }

    /// Layered flame tongues that flicker under the ship for a readable rocket exhaust.
    func makeEngineFlameNode(tint: SKColor) -> SKNode {
        let root = SKNode()
        root.name = GameConstants.NodeName.engineFlame
        // Draw in front of the hull so thruster flames aren't buried under opaque pixels
        // when SKView.ignoresSiblingOrder is on.
        root.zPosition = 1
        let layers = max(3, FramePacing.currentQuality.engineFlameLayers)

        let outer = SKSpriteNode(texture: engineFlameTexture(kind: .outer))
        outer.name = "flameOuter"
        outer.size = CGSize(width: 72, height: 110)
        outer.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        outer.position = .zero
        outer.zPosition = 0
        outer.blendMode = .add
        // Hot orange core look; light ship-tint blend so hangar skins stay distinct.
        outer.color = tint
        outer.colorBlendFactor = 0.18
        root.addChild(outer)
        startFlameFlicker(on: outer, scaleXRange: 0.88...1.16, scaleYRange: 0.72...1.32, alphaRange: 0.75...1.0, period: 0.07)

        let mid = SKSpriteNode(texture: engineFlameTexture(kind: .mid))
        mid.name = "flameMid"
        mid.size = CGSize(width: 44, height: 88)
        mid.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        mid.position = CGPoint(x: 0, y: -2)
        mid.zPosition = 1
        mid.blendMode = .add
        mid.color = SKColor(red: 1.0, green: 0.82, blue: 0.25, alpha: 1)
        mid.colorBlendFactor = 0.12
        root.addChild(mid)
        startFlameFlicker(on: mid, scaleXRange: 0.90...1.12, scaleYRange: 0.78...1.28, alphaRange: 0.85...1.0, period: 0.055)

        let core = SKSpriteNode(texture: engineFlameTexture(kind: .core))
        core.name = "flameCore"
        core.size = CGSize(width: 24, height: 58)
        core.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        core.position = CGPoint(x: 0, y: -1)
        core.zPosition = 2
        core.blendMode = .add
        root.addChild(core)
        startFlameFlicker(on: core, scaleXRange: 0.92...1.10, scaleYRange: 0.82...1.22, alphaRange: 0.90...1.0, period: 0.045)

        if layers >= 5 {
            for side in [-1.0, 1.0] as [CGFloat] {
                let tip = SKSpriteNode(texture: engineFlameTexture(kind: .mid))
                tip.name = "flameTip"
                tip.size = CGSize(width: 26, height: 58)
                tip.anchorPoint = CGPoint(x: 0.5, y: 1.0)
                tip.position = CGPoint(x: side * 22, y: 2)
                tip.zPosition = 0.5
                tip.blendMode = .add
                tip.alpha = 0.9
                tip.color = SKColor(red: 1.0, green: 0.55, blue: 0.12, alpha: 1)
                tip.colorBlendFactor = 0.2
                root.addChild(tip)
                startFlameFlicker(
                    on: tip,
                    scaleXRange: 0.84...1.14,
                    scaleYRange: 0.70...1.26,
                    alphaRange: 0.70...1.0,
                    period: 0.065
                )
            }
        }

        root.run(.repeatForever(.sequence([
            .moveBy(x: 2.2, y: 0, duration: 0.10),
            .moveBy(x: -4.0, y: 0, duration: 0.12),
            .moveBy(x: 1.8, y: 0, duration: 0.10)
        ])), withKey: "flameSway")

        return root
    }

    /// One looping action graph — no per-beat allocation of nested scale/fade groups.
    private func startFlameFlicker(
        on node: SKNode,
        scaleXRange: ClosedRange<CGFloat>,
        scaleYRange: ClosedRange<CGFloat>,
        alphaRange: ClosedRange<CGFloat>,
        period: TimeInterval
    ) {
        let up = SKAction.group([
            .scaleX(to: scaleXRange.upperBound, duration: period),
            .scaleY(to: scaleYRange.upperBound, duration: period),
            .fadeAlpha(to: alphaRange.upperBound, duration: period)
        ])
        let down = SKAction.group([
            .scaleX(to: scaleXRange.lowerBound, duration: period * 1.12),
            .scaleY(to: scaleYRange.lowerBound, duration: period * 0.88),
            .fadeAlpha(to: alphaRange.lowerBound, duration: period * 1.05)
        ])
        let mid = SKAction.group([
            .scaleX(to: (scaleXRange.lowerBound + scaleXRange.upperBound) * 0.5, duration: period * 0.9),
            .scaleY(to: (scaleYRange.lowerBound + scaleYRange.upperBound) * 0.55, duration: period * 0.9),
            .fadeAlpha(to: (alphaRange.lowerBound + alphaRange.upperBound) * 0.5, duration: period * 0.9)
        ])
        node.run(.repeatForever(.sequence([up, down, mid])), withKey: "flameFlicker")
    }

    private enum EngineFlameKind {
        case outer
        case mid
        case core
    }

    private func engineFlameTexture(kind: EngineFlameKind) -> SKTexture {
        let key: String
        switch kind {
        case .outer: key = "__engine_flame_outer"
        case .mid: key = "__engine_flame_mid"
        case .core: key = "__engine_flame_core"
        }
        if let cached = TextureCache.optional(key) {
            return cached
        }

        let size = CGSize(width: 64, height: 96)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            let w = size.width
            let h = size.height
            let path = UIBezierPath()
            // Tip points down (negative Y in scene once anchored at top).
            path.move(to: CGPoint(x: w * 0.5, y: h * 0.98))
            switch kind {
            case .outer:
                path.addCurve(
                    to: CGPoint(x: w * 0.08, y: h * 0.08),
                    controlPoint1: CGPoint(x: w * 0.22, y: h * 0.72),
                    controlPoint2: CGPoint(x: w * 0.02, y: h * 0.32)
                )
                path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.08))
                path.addCurve(
                    to: CGPoint(x: w * 0.5, y: h * 0.98),
                    controlPoint1: CGPoint(x: w * 0.98, y: h * 0.32),
                    controlPoint2: CGPoint(x: w * 0.78, y: h * 0.72)
                )
                UIColor(red: 1.0, green: 0.42, blue: 0.08, alpha: 0.95).setFill()
            case .mid:
                path.addCurve(
                    to: CGPoint(x: w * 0.18, y: h * 0.10),
                    controlPoint1: CGPoint(x: w * 0.28, y: h * 0.68),
                    controlPoint2: CGPoint(x: w * 0.12, y: h * 0.30)
                )
                path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.10))
                path.addCurve(
                    to: CGPoint(x: w * 0.5, y: h * 0.98),
                    controlPoint1: CGPoint(x: w * 0.88, y: h * 0.30),
                    controlPoint2: CGPoint(x: w * 0.72, y: h * 0.68)
                )
                UIColor(red: 1.0, green: 0.72, blue: 0.18, alpha: 0.95).setFill()
            case .core:
                path.addCurve(
                    to: CGPoint(x: w * 0.28, y: h * 0.12),
                    controlPoint1: CGPoint(x: w * 0.34, y: h * 0.62),
                    controlPoint2: CGPoint(x: w * 0.24, y: h * 0.28)
                )
                path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.12))
                path.addCurve(
                    to: CGPoint(x: w * 0.5, y: h * 0.98),
                    controlPoint1: CGPoint(x: w * 0.76, y: h * 0.28),
                    controlPoint2: CGPoint(x: w * 0.66, y: h * 0.62)
                )
                UIColor(red: 1.0, green: 0.96, blue: 0.78, alpha: 1).setFill()
            }
            path.close()
            path.fill()
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = true
        TextureCache.store(key, texture: texture)
        return texture
    }

    func applyPerformanceQuality(starDustRate: CGFloat? = nil) {
        let quality = FramePacing.currentQuality
        let dust = starDustRate ?? FramePacing.scaledBirthRate(quality.starDustBirthRate)
        enumerateChildNodes(withName: GameConstants.NodeName.starDust) { node, _ in
            (node as? SKEmitterNode)?.particleBirthRate = dust
        }
    }

    private func softDotTexture() -> SKTexture {
        let key = "__soft_dot"
        if let cached = TextureCache.optional(key) {
            return cached
        }
        let side = 32
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            let cg = context.cgContext
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
            cg.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: side / 2, y: side / 2),
                startRadius: 0,
                endCenter: CGPoint(x: side / 2, y: side / 2),
                endRadius: CGFloat(side) / 2,
                options: []
            )
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = true
        TextureCache.store(key, texture: texture)
        return texture
    }

    func presentScene(_ scene: SKScene, duration: TimeInterval = 0.4) {
        scene.scaleMode = scaleMode
        view?.presentScene(scene, transition: .fade(withDuration: duration))
    }

    /// Safe-area insets are often still zero on the first `didMove`; refresh after layout.
    func whenSafeAreaReady(_ body: @escaping () -> Void) {
        body()
        DispatchQueue.main.async { [weak self] in
            guard self?.view != nil else { return }
            body()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard self?.view != nil else { return }
                body()
            }
        }
    }
}
