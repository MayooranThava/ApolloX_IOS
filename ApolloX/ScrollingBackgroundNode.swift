//
//  ScrollingBackgroundNode.swift
//  ApolloX
//
//  Seamless vertical scroll with tier-based color grading for difficulty shifts.
//

import SpriteKit

/// Dual-plate parallax backdrop that scrolls downward and shifts palette by spawn tier.
final class ScrollingBackgroundNode: SKNode {
    private struct TierPalette {
        let tint: SKColor
        let overlayAlpha: CGFloat
        let scrollSpeed: CGFloat
        let dustColor: SKColor
        let dustSpeed: CGFloat
        let starSpeed: CGFloat
    }

    private var plates: [SKSpriteNode] = []
    private let tintOverlay = SKSpriteNode()
    private let vignette = SKSpriteNode()
    private var parallaxStars: [SKSpriteNode] = []
    private var visibleSize = CGSize.zero
    private var plateHeight: CGFloat = 0
    private var currentTier = 0
    private var cachedScrollSpeed: CGFloat = 24
    private var cachedStarSpeed: CGFloat = 46
    private var highestPlateY: CGFloat = 0

    override init() {
        super.init()
        zPosition = GameConstants.Z.background
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(in visibleRect: CGRect, texture: SKTexture) {
        visibleSize = visibleRect.size
        plateHeight = visibleRect.height
        position = CGPoint(x: visibleRect.midX, y: visibleRect.midY)

        removeAllChildren()
        plates.removeAll()
        parallaxStars.removeAll()

        let plateWidth = visibleSize.width * 1.06
        for index in 0..<2 {
            let plate = SKSpriteNode(texture: texture)
            plate.size = CGSize(width: plateWidth, height: plateHeight)
            plate.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            plate.position = CGPoint(x: 0, y: CGFloat(index) * plateHeight)
            plate.zPosition = 0
            addChild(plate)
            plates.append(plate)
        }
        highestPlateY = plates.map(\.position.y).max() ?? 0

        tintOverlay.texture = solidTexture()
        tintOverlay.size = CGSize(width: plateWidth, height: plateHeight * 2.05)
        tintOverlay.zPosition = 1
        tintOverlay.blendMode = .alpha
        addChild(tintOverlay)

        vignette.texture = solidTexture()
        vignette.size = tintOverlay.size
        vignette.color = SKColor(white: 0, alpha: 1)
        vignette.colorBlendFactor = 1
        vignette.alpha = 0.18
        vignette.zPosition = 2
        addChild(vignette)

        seedParallaxStars(count: FramePacing.currentQuality.parallaxStarCount)
        applyTier(0, animated: false)
    }

    func relayout(in visibleRect: CGRect, texture: SKTexture) {
        let savedTier = currentTier
        configure(in: visibleRect, texture: texture)
        applyTier(savedTier, animated: false)
    }

    func tick(deltaTime: TimeInterval) {
        guard deltaTime > 0, plateHeight > 0 else { return }
        let dy = cachedScrollSpeed * CGFloat(deltaTime)

        for plate in plates {
            plate.position.y -= dy
        }
        wrapPlates()

        guard !parallaxStars.isEmpty else { return }
        let starDy = cachedStarSpeed * CGFloat(deltaTime)
        for (index, star) in parallaxStars.enumerated() {
            star.position.y -= starDy
            if star.position.y < -plateHeight * 0.55 {
                star.position.y += plateHeight * 1.1
                star.position.x = pseudoRandomX(seed: index)
                star.alpha = CGFloat.random(in: 0.18...0.55)
            }
        }
    }

    func setTier(_ tier: Int, animated: Bool) {
        guard tier != currentTier else { return }
        currentTier = max(0, tier)
        applyTier(currentTier, animated: animated)
    }

    func applyEffectsQuality(_ quality: EffectsQuality) {
        let desired = quality.parallaxStarCount
        if parallaxStars.count == desired { return }
        for star in parallaxStars {
            star.removeFromParent()
        }
        parallaxStars.removeAll(keepingCapacity: true)
        seedParallaxStars(count: desired)
    }

    func dustPalette(for tier: Int) -> (color: SKColor, speed: CGFloat) {
        let palette = palette(for: max(0, tier))
        return (palette.dustColor, palette.dustSpeed)
    }

    // MARK: - Private

    private func wrapPlates() {
        for plate in plates where plate.position.y <= -plateHeight {
            plate.position.y = highestPlateY + plateHeight
            highestPlateY = plate.position.y
        }
    }

    private func seedParallaxStars(count: Int) {
        let dot = starDotTexture()
        for index in 0..<count {
            let star = SKSpriteNode(texture: dot)
            star.size = CGSize(width: 6, height: 6)
            star.zPosition = 1.5
            star.blendMode = .add
            star.position = CGPoint(
                x: pseudoRandomX(seed: index),
                y: CGFloat.random(in: -plateHeight * 0.5...plateHeight * 0.5)
            )
            star.alpha = CGFloat.random(in: 0.2...0.6)
            star.setScale(CGFloat.random(in: 0.6...1.4))
            addChild(star)
            parallaxStars.append(star)
        }
    }

    private func pseudoRandomX(seed: Int) -> CGFloat {
        let span = visibleSize.width * 0.92
        let unit = CGFloat((seed * 73) % 100) / 100
        return (unit - 0.5) * span
    }

    private func applyTier(_ tier: Int, animated: Bool) {
        let palette = palette(for: tier)
        cachedScrollSpeed = palette.scrollSpeed
        cachedStarSpeed = palette.starSpeed
        tintOverlay.removeAction(forKey: "tierTint")
        vignette.removeAction(forKey: "tierVignette")

        let tintAction = SKAction.group([
            SKAction.colorize(with: palette.tint, colorBlendFactor: 1, duration: animated ? 1.4 : 0),
            SKAction.fadeAlpha(to: palette.overlayAlpha, duration: animated ? 1.4 : 0)
        ])
        tintOverlay.run(tintAction, withKey: "tierTint")

        let vignetteAlpha = min(0.34, 0.16 + CGFloat(tier) * 0.04)
        vignette.run(.fadeAlpha(to: vignetteAlpha, duration: animated ? 1.4 : 0), withKey: "tierVignette")
    }

    private func palette(for tier: Int) -> TierPalette {
        switch tier {
        case 0:
            // Calm deep-space indigo — opening sector.
            return TierPalette(
                tint: SKColor(red: 0.10, green: 0.16, blue: 0.38, alpha: 1),
                overlayAlpha: 0.20,
                scrollSpeed: 24,
                dustColor: SKColor(white: 0.92, alpha: 1),
                dustSpeed: 18,
                starSpeed: 46
            )
        case 1:
            // Magenta nebula drift — first ramp at 30s.
            return TierPalette(
                tint: SKColor(red: 0.38, green: 0.10, blue: 0.34, alpha: 1),
                overlayAlpha: 0.28,
                scrollSpeed: 32,
                dustColor: SKColor(red: 1.0, green: 0.78, blue: 0.95, alpha: 1),
                dustSpeed: 24,
                starSpeed: 58
            )
        case 2:
            // Ember belt — mid-game heat at 60s.
            return TierPalette(
                tint: SKColor(red: 0.42, green: 0.14, blue: 0.08, alpha: 1),
                overlayAlpha: 0.32,
                scrollSpeed: 40,
                dustColor: SKColor(red: 1.0, green: 0.62, blue: 0.38, alpha: 1),
                dustSpeed: 30,
                starSpeed: 72
            )
        case 3:
            // Teal ion storm — high pressure at 90s.
            return TierPalette(
                tint: SKColor(red: 0.06, green: 0.24, blue: 0.34, alpha: 1),
                overlayAlpha: 0.34,
                scrollSpeed: 48,
                dustColor: SKColor(red: 0.55, green: 0.92, blue: 1.0, alpha: 1),
                dustSpeed: 36,
                starSpeed: 86
            )
        default:
            // Void surge — late endurance mode.
            let extra = CGFloat(min(tier - 4, 4))
            return TierPalette(
                tint: SKColor(red: 0.18, green: 0.06, blue: 0.28, alpha: 1),
                overlayAlpha: min(0.42, 0.36 + extra * 0.015),
                scrollSpeed: 54 + extra * 8,
                dustColor: SKColor(red: 0.85, green: 0.55, blue: 1.0, alpha: 1),
                dustSpeed: 40 + extra * 4,
                starSpeed: 96 + extra * 10
            )
        }
    }

    private func solidTexture() -> SKTexture {
        let key = "__solid_white"
        if let cached = TextureCache.optional(key) {
            return cached
        }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let texture = SKTexture(image: image)
        TextureCache.store(key, texture: texture)
        return texture
    }

    private func starDotTexture() -> SKTexture {
        let key = "__parallax_star"
        if let cached = TextureCache.optional(key) {
            return cached
        }
        let side = 16
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            let cg = context.cgContext
            let colors = [UIColor.white.cgColor, UIColor.clear.cgColor] as CFArray
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
        TextureCache.store(key, texture: texture)
        return texture
    }
}
