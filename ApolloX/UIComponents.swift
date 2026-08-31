//
//  UIComponents.swift
//  ApolloX
//

import SpriteKit
import UIKit

enum GameTheme {
    static let title = SKColor.white
    static let secondary = SKColor(white: 0.82, alpha: 1)
    /// Gold accent used for BEST, shields, secondary button labels.
    static let accent = SKColor(red: 1.0, green: 0.84, blue: 0.38, alpha: 1)
    static let panel = SKColor(red: 0.04, green: 0.07, blue: 0.14, alpha: 0.72)
    /// Primary HUD-slab fill (cockpit navy).
    static let buttonFill = SKColor(red: 0.10, green: 0.22, blue: 0.42, alpha: 0.98)
    static let buttonFillTop = SKColor(red: 0.16, green: 0.32, blue: 0.58, alpha: 1)
    static let buttonStroke = SKColor(red: 1.0, green: 0.84, blue: 0.38, alpha: 0.85)
    /// Secondary muted fill — solid dark navy (never a translucent white wash).
    static let buttonMuted = SKColor(red: 0.07, green: 0.11, blue: 0.20, alpha: 0.96)
    static let buttonMutedStroke = SKColor(red: 1.0, green: 0.84, blue: 0.38, alpha: 0.55)
    static let buttonText = SKColor.white
    static let buttonTextShadow = SKColor(white: 0, alpha: 0.55)
    static let credit = SKColor(red: 0.42, green: 0.94, blue: 0.72, alpha: 1)
    /// Techno HUD cyan for HP blocks / labels (reference-style cockpit UI).
    static let hudCyan = SKColor(red: 0.55, green: 0.82, blue: 1.0, alpha: 1)
    static let hudCyanDim = SKColor(red: 0.55, green: 0.82, blue: 1.0, alpha: 0.22)
    static let shieldGold = SKColor(red: 1.0, green: 0.84, blue: 0.38, alpha: 1)
    static let shieldGoldDim = SKColor(red: 1.0, green: 0.84, blue: 0.38, alpha: 0.22)
}

enum GameFont {
    private static var cachedName: String?

    static func resolved(size: CGFloat) -> String {
        if let cachedName { return cachedName }
        let name = UIFont(name: GameConstants.fontName, size: size) != nil
            ? GameConstants.fontName
            : GameConstants.fallbackFontName
        cachedName = name
        return name
    }
}

/// Cached rounded-rect textures so HUD/buttons batch as sprites instead of `SKShapeNode` tessellation.
enum ShapeTexture {
    private static var cache: [String: SKTexture] = [:]

    static func roundedRect(
        size: CGSize,
        cornerRadius: CGFloat,
        fill: SKColor,
        stroke: SKColor,
        lineWidth: CGFloat
    ) -> SKTexture {
        let key = String(
            format: "%.0fx%.0f-r%.0f-lw%.0f-%@-%@",
            size.width, size.height, cornerRadius, lineWidth,
            fill.debugDescription, stroke.debugDescription
        )
        if let cached = cache[key] {
            return cached
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            let inset = lineWidth * 0.5
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: max(0, cornerRadius - inset))
            fill.setFill()
            path.fill()
            if lineWidth > 0 {
                stroke.setStroke()
                path.lineWidth = lineWidth
                path.stroke()
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = true
        cache[key] = texture
        return texture
    }

    /// Cockpit slab: soft chamfered rect, solid fill, gold rim — no top bar (that caused grey bands).
    static func hudSlab(
        size: CGSize,
        cornerRadius: CGFloat,
        fill: SKColor,
        topHighlight: SKColor,
        stroke: SKColor,
        lineWidth: CGFloat
    ) -> SKTexture {
        // `topHighlight` kept for call-site compatibility; bevel is a thin inner top edge only.
        let key = String(
            format: "slab2-%.0fx%.0f-r%.0f-lw%.0f-%@-%@-%@",
            size.width, size.height, cornerRadius, lineWidth,
            fill.debugDescription, topHighlight.debugDescription, stroke.debugDescription
        )
        if let cached = cache[key] {
            return cached
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            let inset = lineWidth * 0.5
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            // Slight chamfer (cut corners) like the reference pause buttons.
            let cut = max(8, min(cornerRadius, min(rect.width, rect.height) * 0.18))
            let path = UIBezierPath()
            path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
            path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
            path.close()

            fill.setFill()
            path.fill()

            // Hairline inner highlight along the top edge only (not a filled band).
            let edge = UIBezierPath()
            edge.move(to: CGPoint(x: rect.minX + cut + 2, y: rect.minY + lineWidth + 1))
            edge.addLine(to: CGPoint(x: rect.maxX - cut - 2, y: rect.minY + lineWidth + 1))
            topHighlight.withAlphaComponent(0.22).setStroke()
            edge.lineWidth = 1.5
            edge.stroke()

            if lineWidth > 0 {
                stroke.setStroke()
                path.lineWidth = lineWidth
                path.stroke()
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = true
        cache[key] = texture
        return texture
    }

    /// Slanted parallelogram block for HP / shield meters.
    static func parallelogramBlock(
        size: CGSize,
        fill: SKColor,
        stroke: SKColor,
        lineWidth: CGFloat = 1.5,
        skew: CGFloat = 10
    ) -> SKTexture {
        let key = String(
            format: "para-%.0fx%.0f-s%.0f-lw%.0f-%@-%@",
            size.width, size.height, skew, lineWidth,
            fill.debugDescription, stroke.debugDescription
        )
        if let cached = cache[key] {
            return cached
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            let inset = lineWidth * 0.5 + 0.5
            let path = UIBezierPath()
            // Bottom-left → bottom-right → top-right → top-left, skewed like the reference HUD.
            path.move(to: CGPoint(x: inset + skew, y: size.height - inset))
            path.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset))
            path.addLine(to: CGPoint(x: size.width - inset - skew, y: inset))
            path.addLine(to: CGPoint(x: inset, y: inset))
            path.close()
            fill.setFill()
            path.fill()
            if lineWidth > 0 {
                stroke.setStroke()
                path.lineWidth = lineWidth
                path.stroke()
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = true
        cache[key] = texture
        return texture
    }
}

final class HUDBarNode: SKNode {
    private let panel = SKSpriteNode()
    private let scoreCaption = SKLabelNode()
    private let scoreValue = SKLabelNode()
    private let comboCaption = SKLabelNode()
    private let comboValue = SKLabelNode()
    private let highScoreLabel = SKLabelNode()
    private let hpCaption = SKLabelNode()
    private let shieldCaption = SKLabelNode()
    private let statusLabel = SKLabelNode()
    private let pauseButton = SKSpriteNode()
    private let pauseGlyph = SKLabelNode()
    private let hpMeter = SKNode()
    private let shieldMeter = SKNode()
    private var hpBlocks: [SKSpriteNode] = []
    private var shieldBlocks: [SKSpriteNode] = []
    /// Large enough to read at a glance during combat.
    private var blockSize = CGSize(width: 52, height: 34)

    /// Scene-space hit rect for the pause control (updated in `layout`).
    private(set) var pauseHitRect = CGRect.zero

    override init() {
        super.init()
        zPosition = GameConstants.Z.hud

        panel.color = GameTheme.panel
        addChild(panel)

        style(scoreCaption, alignment: .left, color: GameTheme.hudCyan)
        style(scoreValue, alignment: .left, color: GameTheme.shieldGold)
        style(comboCaption, alignment: .left, color: GameTheme.hudCyan)
        style(comboValue, alignment: .left, color: GameTheme.hudCyan)
        style(highScoreLabel, alignment: .left, color: SKColor(white: 1, alpha: 0.42))
        style(hpCaption, alignment: .left, color: GameTheme.hudCyan)
        style(shieldCaption, alignment: .left, color: GameTheme.shieldGold)
        style(statusLabel, alignment: .center, color: GameTheme.accent)
        scoreCaption.text = "SCORE"
        comboCaption.text = "COMBO"
        hpCaption.text = "HP"
        shieldCaption.text = "SHIELD"
        addChild(scoreCaption)
        addChild(scoreValue)
        addChild(comboCaption)
        addChild(comboValue)
        addChild(highScoreLabel)
        addChild(hpCaption)
        addChild(shieldCaption)
        addChild(statusLabel)

        hpMeter.zPosition = 1
        shieldMeter.zPosition = 1
        addChild(hpMeter)
        addChild(shieldMeter)
        rebuildMeters()

        pauseButton.color = GameTheme.buttonMuted
        pauseButton.name = GameConstants.NodeName.pauseButton
        addChild(pauseButton)

        pauseGlyph.fontName = GameFont.resolved(size: 28)
        pauseGlyph.text = "II"
        pauseGlyph.fontSize = 26
        pauseGlyph.fontColor = GameTheme.hudCyan
        pauseGlyph.verticalAlignmentMode = .center
        pauseGlyph.horizontalAlignmentMode = .center
        pauseGlyph.name = GameConstants.NodeName.pauseButton
        pauseButton.addChild(pauseGlyph)

        setScore(0)
        setCombo(0)
        setHighScore(0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(in safeRect: CGRect) {
        let height: CGFloat = 148
        let width = safeRect.width
        panel.size = CGSize(width: width, height: height)
        panel.texture = ShapeTexture.roundedRect(
            size: panel.size,
            cornerRadius: 24,
            fill: GameTheme.panel,
            stroke: SKColor(white: 1, alpha: 0.12),
            lineWidth: 2
        )

        position = CGPoint(x: safeRect.midX, y: safeRect.maxY - height * 0.5 - 6)

        let sidePad: CGFloat = 32
        let leftX = -width * 0.5 + sidePad

        scoreCaption.fontSize = 18
        scoreValue.fontSize = 40
        comboCaption.fontSize = 18
        comboValue.fontSize = 28
        highScoreLabel.fontSize = 18
        hpCaption.fontSize = 22
        shieldCaption.fontSize = 22
        statusLabel.fontSize = 22

        // Left stack — SCORE / value / COMBO / BEST (reference cockpit layout).
        scoreCaption.position = CGPoint(x: leftX, y: 48)
        scoreValue.position = CGPoint(x: leftX, y: 18)
        comboCaption.position = CGPoint(x: leftX, y: -10)
        comboValue.position = CGPoint(x: leftX + 96, y: -10)
        highScoreLabel.position = CGPoint(x: leftX, y: -40)
        statusLabel.position = CGPoint(x: 0, y: -58)

        let pauseSize: CGFloat = 56
        pauseButton.size = CGSize(width: pauseSize, height: pauseSize)
        pauseButton.texture = ShapeTexture.hudSlab(
            size: pauseButton.size,
            cornerRadius: 14,
            fill: GameTheme.buttonMuted,
            topHighlight: GameTheme.hudCyan,
            stroke: GameTheme.hudCyan.withAlphaComponent(0.75),
            lineWidth: 2
        )
        pauseButton.position = CGPoint(x: width * 0.5 - sidePad - 4, y: 18)

        let pauseCenterInScene = convert(pauseButton.position, to: parent ?? self)
        let hitPad: CGFloat = 28
        pauseHitRect = CGRect(
            x: pauseCenterInScene.x - pauseSize * 0.5 - hitPad,
            y: pauseCenterInScene.y - pauseSize * 0.5 - hitPad,
            width: pauseSize + hitPad * 2,
            height: pauseSize + hitPad * 2
        )

        let meterRight = pauseButton.position.x - pauseSize * 0.5 - 22
        layoutMeterRow(
            caption: hpCaption,
            meter: hpMeter,
            blocks: hpBlocks,
            rightX: meterRight,
            y: 36
        )
        layoutMeterRow(
            caption: shieldCaption,
            meter: shieldMeter,
            blocks: shieldBlocks,
            rightX: meterRight,
            y: -6
        )
    }

    func setScore(_ value: Int) {
        scoreValue.text = Self.formattedScore(value)
    }

    func setCombo(_ value: Int) {
        comboValue.text = "x \(max(0, value))"
    }

    func setHighScore(_ value: Int) {
        highScoreLabel.text = "BEST  \(value)"
    }

    /// Maps total lives → HP blocks (up to base) + shield blocks (overflow).
    func setLives(_ value: Int) {
        let split = GameRules.hullAndShield(fromLives: value)
        for (index, block) in hpBlocks.enumerated() {
            let filled = index < split.hull
            block.texture = ShapeTexture.parallelogramBlock(
                size: blockSize,
                fill: filled ? GameTheme.hudCyan : GameTheme.hudCyanDim,
                stroke: filled ? GameTheme.hudCyan : GameTheme.hudCyan.withAlphaComponent(0.35),
                skew: 12
            )
            block.alpha = 1
        }
        for (index, block) in shieldBlocks.enumerated() {
            let filled = index < split.shield
            block.texture = ShapeTexture.parallelogramBlock(
                size: blockSize,
                fill: filled ? GameTheme.shieldGold : GameTheme.shieldGoldDim,
                stroke: filled ? GameTheme.shieldGold : GameTheme.shieldGold.withAlphaComponent(0.35),
                skew: 12
            )
            block.alpha = 1
        }
        isAccessibilityElement = true
        accessibilityLabel = "Score and vitals. Hull \(split.hull) of \(GameRules.baseHullCapacity), shield \(split.shield)"
    }

    func setStatus(_ text: String) {
        statusLabel.text = text.uppercased()
    }

    func containsPauseTouch(_ pointInScene: CGPoint) -> Bool {
        pauseHitRect.contains(pointInScene)
    }

    func pulseStatus() {
        statusLabel.removeAction(forKey: "pulseStatus")
        statusLabel.setScale(1)
        statusLabel.run(.sequence([
            .scale(to: 1.18, duration: 0.12),
            .scale(to: 1.0, duration: 0.16)
        ]), withKey: "pulseStatus")
    }

    func pulseLives() {
        let pulse = SKAction.sequence([
            .scale(to: 1.12, duration: 0.1),
            .scale(to: 1.0, duration: 0.12)
        ])
        hpMeter.run(pulse)
        shieldMeter.run(pulse)
    }

    func pulseCombo() {
        comboValue.removeAction(forKey: "pulseCombo")
        comboValue.setScale(1)
        comboValue.run(.sequence([
            .scale(to: 1.2, duration: 0.08),
            .scale(to: 1.0, duration: 0.12)
        ]), withKey: "pulseCombo")
    }

    private func rebuildMeters() {
        hpBlocks.forEach { $0.removeFromParent() }
        shieldBlocks.forEach { $0.removeFromParent() }
        hpBlocks = (0..<GameRules.baseHullCapacity).map { _ in makeBlock() }
        shieldBlocks = (0..<GameRules.maxShieldCapacity).map { _ in makeBlock() }
        hpBlocks.forEach { hpMeter.addChild($0) }
        shieldBlocks.forEach { shieldMeter.addChild($0) }
        setLives(GameRules.startingLives)
    }

    private func makeBlock() -> SKSpriteNode {
        let node = SKSpriteNode(color: .white, size: blockSize)
        node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return node
    }

    private func layoutMeterRow(
        caption: SKLabelNode,
        meter: SKNode,
        blocks: [SKSpriteNode],
        rightX: CGFloat,
        y: CGFloat
    ) {
        let spacing: CGFloat = 8
        let totalWidth = CGFloat(blocks.count) * blockSize.width + CGFloat(max(0, blocks.count - 1)) * spacing
        meter.position = CGPoint(x: rightX - totalWidth * 0.5, y: y)
        for (index, block) in blocks.enumerated() {
            block.size = blockSize
            let x = -totalWidth * 0.5 + blockSize.width * 0.5 + CGFloat(index) * (blockSize.width + spacing)
            block.position = CGPoint(x: x, y: 0)
        }
        caption.horizontalAlignmentMode = .right
        caption.position = CGPoint(x: rightX - totalWidth - 16, y: y)
    }

    private func style(_ label: SKLabelNode, alignment: SKLabelHorizontalAlignmentMode, color: SKColor) {
        label.fontName = GameFont.resolved(size: 38)
        label.fontColor = color
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
    }

    /// Reference-style padded score: `002 350`.
    static func formattedScore(_ value: Int) -> String {
        let clamped = max(0, min(value, 999_999))
        let raw = String(format: "%06d", clamped)
        let index = raw.index(raw.startIndex, offsetBy: 3)
        return "\(raw[..<index]) \(raw[index...])"
    }
}

/// Boss HP bar shown below the main HUD during the space-monster fight.
final class BossHealthBarNode: SKNode {
    private let panel = SKSpriteNode()
    private let track = SKSpriteNode()
    private let fill = SKSpriteNode()
    private let glow = SKSpriteNode()
    private let title = SKLabelNode()
    private let hpLabel = SKLabelNode()

    private var barWidth: CGFloat = 420
    private var fillColor = SKColor(red: 0.95, green: 0.38, blue: 0.22, alpha: 1)
    private var lastRatio: CGFloat = 1

    override init() {
        super.init()
        zPosition = GameConstants.Z.hud + 1
        isHidden = true

        glow.color = SKColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 0.18)
        glow.zPosition = -1
        addChild(glow)

        panel.color = GameTheme.panel
        addChild(panel)

        track.color = SKColor(white: 1, alpha: 0.12)
        addChild(track)

        fill.color = fillColor
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        addChild(fill)

        title.fontName = GameFont.resolved(size: 18)
        title.fontSize = 18
        title.fontColor = GameTheme.accent
        title.text = "SPACE MONSTER"
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .center
        title.zPosition = 2
        addChild(title)

        hpLabel.fontName = GameFont.resolved(size: 13)
        hpLabel.fontSize = 13
        hpLabel.fontColor = SKColor(white: 1, alpha: 0.72)
        hpLabel.text = ""
        hpLabel.verticalAlignmentMode = .center
        hpLabel.horizontalAlignmentMode = .right
        hpLabel.zPosition = 2
        addChild(hpLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(in safeRect: CGRect, below hudHeight: CGFloat) {
        let width = min(safeRect.width - 64, 540)
        let height: CGFloat = 78
        barWidth = width - 40

        panel.size = CGSize(width: width, height: height)
        panel.texture = ShapeTexture.roundedRect(
            size: panel.size,
            cornerRadius: 16,
            fill: SKColor(red: 0.06, green: 0.10, blue: 0.20, alpha: 0.92),
            stroke: SKColor(red: 0.92, green: 0.78, blue: 0.32, alpha: 0.55),
            lineWidth: 2.5
        )

        glow.size = CGSize(width: width + 18, height: height + 14)
        glow.texture = ShapeTexture.roundedRect(
            size: glow.size,
            cornerRadius: 20,
            fill: SKColor(red: 0.35, green: 0.70, blue: 1.0, alpha: 0.14),
            stroke: .clear,
            lineWidth: 0
        )

        // Sit clearly under the HUD status row so FIRE BOOST never overlaps the name.
        position = CGPoint(x: safeRect.midX, y: safeRect.maxY - hudHeight - height * 0.5 - 36)

        title.position = CGPoint(x: 0, y: 20)
        hpLabel.horizontalAlignmentMode = .right
        hpLabel.position = CGPoint(x: barWidth * 0.5 - 2, y: -30)

        track.size = CGSize(width: barWidth, height: 18)
        track.texture = ShapeTexture.roundedRect(
            size: track.size,
            cornerRadius: 9,
            fill: SKColor(white: 1, alpha: 0.10),
            stroke: SKColor(white: 1, alpha: 0.10),
            lineWidth: 1
        )
        track.position = CGPoint(x: 0, y: -8)

        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: -barWidth * 0.5, y: -8)
        applyFill(ratio: lastRatio)
    }

    func show(maxHP: Int, title: String = "SPACE MONSTER", accent: SKColor? = nil) {
        isHidden = false
        self.title.text = title.uppercased()
        if let accent {
            fillColor = accent
            fill.color = accent
        }
        setHP(current: maxHP, maximum: maxHP)
        glow.removeAllActions()
        glow.alpha = 1
        glow.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.55, duration: 0.7),
            .fadeAlpha(to: 1.0, duration: 0.7)
        ])))
    }

    func hideBar() {
        isHidden = true
        glow.removeAllActions()
    }

    func setHP(current: Int, maximum: Int) {
        let ratio = maximum > 0 ? CGFloat(current) / CGFloat(maximum) : 0
        lastRatio = max(0, min(1, ratio))
        applyFill(ratio: lastRatio)
        hpLabel.text = "\(max(0, current))/\(max(0, maximum))"
    }

    func pulseDamage() {
        fill.run(.sequence([
            .colorize(with: .white, colorBlendFactor: 0.45, duration: 0.05),
            .run { [weak self] in
                guard let self else { return }
                self.fill.colorBlendFactor = 0
                self.fill.color = .white
            }
        ]))
    }

    /// Resize the fill sprite directly — Texture + xScale was rendering as an empty track on device.
    private func applyFill(ratio: CGFloat) {
        let width = max(barWidth * ratio, 0)
        let height: CGFloat = 18
        fill.xScale = 1
        fill.yScale = 1
        fill.alpha = ratio > 0.001 ? 1 : 0
        guard width > 0.5 else {
            fill.size = CGSize(width: 0.01, height: height)
            return
        }
        fill.size = CGSize(width: width, height: height)
        fill.texture = ShapeTexture.roundedRect(
            size: CGSize(width: width, height: height),
            cornerRadius: 9,
            fill: fillColor,
            stroke: SKColor(white: 1, alpha: 0.18),
            lineWidth: 1
        )
        fill.color = .white
        fill.colorBlendFactor = 0
    }
}

final class MenuButtonNode: SKNode {
    private let background = SKSpriteNode()
    private let shadowLabel = SKLabelNode()
    private let label = SKLabelNode()
    private var emphasized: Bool
    private let buttonSize: CGSize
    private(set) var hitSize = CGSize.zero

    init(title: String, width: CGFloat, height: CGFloat, fontSize: CGFloat, emphasized: Bool = true) {
        self.emphasized = emphasized
        self.buttonSize = CGSize(width: width, height: height)
        super.init()
        zPosition = GameConstants.Z.hud

        background.size = buttonSize
        background.zPosition = 0
        addChild(background)

        for textNode in [shadowLabel, label] {
            textNode.fontName = GameFont.resolved(size: fontSize)
            textNode.text = title
            textNode.fontSize = fontSize
            textNode.verticalAlignmentMode = .center
            textNode.horizontalAlignmentMode = .center
            textNode.zPosition = 2
        }
        shadowLabel.fontColor = GameTheme.buttonTextShadow
        shadowLabel.position = CGPoint(x: 0, y: -2)
        shadowLabel.zPosition = 1
        addChild(shadowLabel)
        addChild(label)

        hitSize = CGSize(width: width + 48, height: height + 40)
        applyChrome(title: title, emphasized: emphasized)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func containsTouch(_ point: CGPoint) -> Bool {
        let rect = CGRect(
            x: position.x - hitSize.width * 0.5,
            y: position.y - hitSize.height * 0.5,
            width: hitSize.width,
            height: hitSize.height
        )
        return rect.contains(point)
    }

    func setTitle(_ title: String, emphasized: Bool? = nil) {
        applyChrome(title: title, emphasized: emphasized ?? self.emphasized)
    }

    func pulse() {
        run(.sequence([
            .scale(to: 0.96, duration: 0.06),
            .scale(to: 1.0, duration: 0.1)
        ]))
    }

    private func applyChrome(title: String, emphasized: Bool) {
        self.emphasized = emphasized
        // HUD slab: soft rectangle (not a full pill) with gold rim + top bevel.
        let corner = buttonSize.height * 0.22
        if emphasized {
            background.texture = ShapeTexture.hudSlab(
                size: buttonSize,
                cornerRadius: corner,
                fill: GameTheme.buttonFill,
                topHighlight: GameTheme.buttonFillTop,
                stroke: GameTheme.buttonStroke,
                lineWidth: 2.5
            )
            label.fontColor = GameTheme.buttonText
        } else {
            background.texture = ShapeTexture.hudSlab(
                size: buttonSize,
                cornerRadius: corner,
                fill: GameTheme.buttonMuted,
                topHighlight: GameTheme.buttonFillTop,
                stroke: GameTheme.buttonMutedStroke,
                lineWidth: 2
            )
            label.fontColor = GameTheme.accent
        }
        label.text = title
        shadowLabel.text = title
        name = title
        accessibilityLabel = title
        accessibilityTraits = .button
        isAccessibilityElement = true
    }
}

/// Settings row with an ON/OFF pill — used for Sound and Haptics.
final class SettingsToggleNode: SKNode {
    private let panel = SKSpriteNode()
    private let titleLabel = SKLabelNode()
    private let valueLabel = SKLabelNode()
    private var isOn: Bool
    private var rowWidth: CGFloat = 900
    private let rowHeight: CGFloat = 100
    private(set) var hitSize = CGSize.zero

    init(title: String, isOn: Bool) {
        self.isOn = isOn
        super.init()
        zPosition = GameConstants.Z.hud

        addChild(panel)

        titleLabel.fontName = GameFont.resolved(size: 40)
        titleLabel.text = title
        titleLabel.fontSize = 40
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.zPosition = 1
        addChild(titleLabel)

        valueLabel.fontName = GameFont.resolved(size: 34)
        valueLabel.fontSize = 34
        valueLabel.verticalAlignmentMode = .center
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.zPosition = 1
        addChild(valueLabel)

        isAccessibilityElement = true
        accessibilityTraits = .button
        applyValue()
        layout(width: rowWidth)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(width: CGFloat) {
        rowWidth = width
        hitSize = CGSize(width: width + 40, height: rowHeight + 28)
        panel.size = CGSize(width: width, height: rowHeight)
        panel.texture = ShapeTexture.roundedRect(
            size: panel.size,
            cornerRadius: 28,
            fill: GameTheme.panel,
            stroke: SKColor(white: 1, alpha: 0.14),
            lineWidth: 2
        )
        titleLabel.position = CGPoint(x: -width * 0.5 + 36, y: 0)
        valueLabel.position = CGPoint(x: width * 0.5 - 36, y: 0)
    }

    func setOn(_ on: Bool) {
        isOn = on
        applyValue()
    }

    func containsTouch(_ point: CGPoint) -> Bool {
        let rect = CGRect(
            x: position.x - hitSize.width * 0.5,
            y: position.y - hitSize.height * 0.5,
            width: hitSize.width,
            height: hitSize.height
        )
        return rect.contains(point)
    }

    private func applyValue() {
        valueLabel.text = isOn ? "ON" : "OFF"
        valueLabel.fontColor = isOn ? GameTheme.credit : SKColor(white: 0.55, alpha: 1)
        accessibilityLabel = "\(titleLabel.text ?? "Setting"), \(isOn ? "on" : "off")"
        name = titleLabel.text
    }
}

/// Settings row with a tap-to-adjust volume bar (0…100%).
final class SettingsVolumeRow: SKNode {
    private let panel = SKSpriteNode()
    private let titleLabel = SKLabelNode()
    private let valueLabel = SKLabelNode()
    private let fill = SKSpriteNode()
    private let track = SKSpriteNode()
    private var volume: Float
    private var rowWidth: CGFloat = 900
    private let rowHeight: CGFloat = 100
    private(set) var hitSize = CGSize.zero
    private let onChange: (Float) -> Void

    init(title: String, volume: Float, onChange: @escaping (Float) -> Void) {
        self.volume = min(1, max(0, volume))
        self.onChange = onChange
        super.init()
        zPosition = GameConstants.Z.hud

        addChild(panel)
        track.color = SKColor(white: 1, alpha: 0.12)
        track.zPosition = 1
        addChild(track)
        fill.color = GameTheme.accent
        fill.zPosition = 2
        addChild(fill)

        titleLabel.fontName = GameFont.resolved(size: 40)
        titleLabel.text = title
        titleLabel.fontSize = 40
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.zPosition = 3
        addChild(titleLabel)

        valueLabel.fontName = GameFont.resolved(size: 30)
        valueLabel.fontSize = 30
        valueLabel.fontColor = GameTheme.secondary
        valueLabel.verticalAlignmentMode = .center
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.zPosition = 3
        addChild(valueLabel)

        isAccessibilityElement = true
        accessibilityTraits = .adjustable
        layout(width: rowWidth)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(width: CGFloat) {
        rowWidth = width
        hitSize = CGSize(width: width + 40, height: rowHeight + 28)
        panel.size = CGSize(width: width, height: rowHeight)
        panel.texture = ShapeTexture.roundedRect(
            size: panel.size,
            cornerRadius: 28,
            fill: GameTheme.panel,
            stroke: SKColor(white: 1, alpha: 0.14),
            lineWidth: 2
        )
        titleLabel.position = CGPoint(x: -width * 0.5 + 36, y: 14)
        valueLabel.position = CGPoint(x: width * 0.5 - 36, y: 14)

        let trackWidth = width - 72
        let trackHeight: CGFloat = 14
        track.size = CGSize(width: trackWidth, height: trackHeight)
        track.position = CGPoint(x: 0, y: -22)
        fill.size = CGSize(width: max(8, trackWidth * CGFloat(volume)), height: trackHeight - 2)
        fill.position = CGPoint(x: -trackWidth * 0.5 + fill.size.width * 0.5, y: track.position.y)
        accessibilityLabel = "\(titleLabel.text ?? "Volume"), \(Int(volume * 100)) percent"
    }

    func setVolume(_ value: Float) {
        volume = min(1, max(0, value))
        layout(width: rowWidth)
    }

    func containsTouch(_ point: CGPoint) -> Bool {
        let rect = CGRect(
            x: position.x - hitSize.width * 0.5,
            y: position.y - hitSize.height * 0.5,
            width: hitSize.width,
            height: hitSize.height
        )
        return rect.contains(point)
    }

    func adjust(at point: CGPoint) {
        let localX = point.x - position.x
        let trackWidth = rowWidth - 72
        let normalized = (localX + trackWidth * 0.5) / trackWidth
        volume = Float(min(1, max(0, normalized)))
        layout(width: rowWidth)
        onChange(volume)
    }
}

/// Thumb-side hardpoint trigger with cooldown fill.
final class SpecialWeaponButton: SKNode {
    private let plate = SKSpriteNode()
    private let icon = SKSpriteNode()
    private let cooldownOverlay = SKSpriteNode()
    private let label = SKLabelNode()
    private(set) var hitRect = CGRect.zero
    private var buttonSize = CGSize(width: 108, height: 108)

    override init() {
        super.init()
        zPosition = GameConstants.Z.hud
        name = GameConstants.NodeName.specialButton

        plate.zPosition = 0
        addChild(plate)
        icon.zPosition = 1
        icon.setScale(0.55)
        addChild(icon)
        cooldownOverlay.color = SKColor(white: 0, alpha: 0.55)
        cooldownOverlay.zPosition = 2
        cooldownOverlay.anchorPoint = CGPoint(x: 0.5, y: 0)
        addChild(cooldownOverlay)
        label.fontName = GameFont.resolved(size: 18)
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 3
        addChild(label)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(weapon: WeaponItem) {
        icon.texture = TextureCache.texture(weapon.textureName)
        if let size = icon.texture?.size(), size.width > 0 {
            icon.size = size
        }
        icon.setScale(0.52)
        plate.texture = ShapeTexture.hudSlab(
            size: buttonSize,
            cornerRadius: 22,
            fill: GameTheme.buttonMuted,
            topHighlight: weapon.accent,
            stroke: weapon.accent.withAlphaComponent(0.8),
            lineWidth: 2
        )
        plate.size = buttonSize
        label.text = weapon.name.uppercased()
        label.fontSize = 16
    }

    func layout(in safeRect: CGRect) {
        position = CGPoint(x: safeRect.maxX - 78, y: safeRect.minY + 110)
        label.position = CGPoint(x: 0, y: -buttonSize.height * 0.5 - 18)
        cooldownOverlay.size = CGSize(width: buttonSize.width - 8, height: buttonSize.height - 8)
        cooldownOverlay.position = CGPoint(x: 0, y: -(buttonSize.height - 8) * 0.5)
        let pad: CGFloat = 18
        hitRect = CGRect(
            x: position.x - buttonSize.width * 0.5 - pad,
            y: position.y - buttonSize.height * 0.5 - pad,
            width: buttonSize.width + pad * 2,
            height: buttonSize.height + pad * 2 + 28
        )
    }

    /// `progress` 0 = ready, 1 = full cooldown remaining.
    func setCooldownProgress(_ progress: CGFloat) {
        let clamped = min(1, max(0, progress))
        cooldownOverlay.yScale = clamped
        cooldownOverlay.isHidden = clamped <= 0.001
        alpha = clamped > 0.001 ? 0.85 : 1
    }

    func containsTouch(_ pointInScene: CGPoint) -> Bool {
        hitRect.contains(pointInScene)
    }

    func pulse() {
        removeAction(forKey: "specialPulse")
        setScale(1)
        run(.sequence([
            .scale(to: 1.12, duration: 0.08),
            .scale(to: 1.0, duration: 0.1)
        ]), withKey: "specialPulse")
    }
}
