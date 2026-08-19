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
        let palette = scrollingBackgroundNode()?.dustPalette(for: tier)
            ?? (SKColor(white: 0.92, alpha: 1), 18.0)

        let emitter = SKEmitterNode()
        emitter.particleTexture = softDotTexture()
        emitter.particleBirthRate = FramePacing.currentQuality.starDustBirthRate
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
            let palette = scrollingBackgroundNode()?.dustPalette(for: tier)
                ?? (SKColor(white: 0.92, alpha: 1), 18.0)
            dust.particleColor = palette.color
            dust.particleSpeed = palette.speed
            dust.particleSpeedRange = palette.speed * 0.75
        }
    }

    func makeEngineEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.name = GameConstants.NodeName.engine
        emitter.particleTexture = softDotTexture()
        emitter.particleBirthRate = FramePacing.currentQuality.engineBirthRate
        emitter.particleLifetime = 0.26
        emitter.particleLifetimeRange = 0.08
        emitter.particlePositionRange = CGVector(dx: 10, dy: 3)
        emitter.particleSpeed = 80
        emitter.particleSpeedRange = 35
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = 0.3
        emitter.particleAlpha = 0.8
        emitter.particleAlphaSpeed = -2.2
        emitter.particleScale = 0.11
        emitter.particleScaleRange = 0.05
        emitter.particleScaleSpeed = -0.22
        emitter.particleColor = SKColor(red: 1.0, green: 0.62, blue: 0.25, alpha: 1)
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.targetNode = self
        return emitter
    }

    func applyPerformanceQuality() {
        let quality = FramePacing.currentQuality
        enumerateChildNodes(withName: GameConstants.NodeName.starDust) { node, _ in
            (node as? SKEmitterNode)?.particleBirthRate = quality.starDustBirthRate
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
