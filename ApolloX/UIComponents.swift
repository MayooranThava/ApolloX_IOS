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
    static let buttonMuted = SKColor(red: 0.06, green: 0.10, blue: 0.18, alpha: 0.92)
    static let buttonMutedStroke = SKColor(red: 1.0, green: 0.84, blue: 0.38, alpha: 0.40)
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

    /// Soft-rect with a lighter top band so HUD slabs read as beveled cockpit panels.
    static func hudSlab(
        size: CGSize,
        cornerRadius: CGFloat,
        fill: SKColor,
        topHighlight: SKColor,
        stroke: SKColor,
        lineWidth: CGFloat
    ) -> SKTexture {
        let key = String(
            format: "slab-%.0fx%.0f-r%.0f-lw%.0f-%@-%@-%@",
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
            let path = UIBezierPath(roundedRect: rect, cornerRadius: max(0, cornerRadius - inset))
            fill.setFill()
            path.fill()

            // Top bevel — clipped to the same rounded rect.
            let highlightHeight = max(6, size.height * 0.38)
            let highlightRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: highlightHeight)
            path.addClip()
            topHighlight.withAlphaComponent(0.55).setFill()
            UIBezierPath(rect: highlightRect).fill()

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
    private let scoreLabel = SKLabelNode()
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
    private var blockSize = CGSize(width: 34, height: 22)

    /// Scene-space hit rect for the pause control (updated in `layout`).
    private(set) var pauseHitRect = CGRect.zero

    override init() {
        super.init()
        zPosition = GameConstants.Z.hud

        panel.color = GameTheme.panel
        addChild(panel)

        style(scoreLabel, alignment: .left, color: .white)
        style(highScoreLabel, alignment: .left, color: SKColor(white: 1, alpha: 0.38))
        style(hpCaption, alignment: .left, color: GameTheme.hudCyan)
        style(shieldCaption, alignment: .left, color: GameTheme.shieldGold)
        style(statusLabel, alignment: .center, color: GameTheme.accent)
        hpCaption.text = "HP"
        shieldCaption.text = "SHIELD"
        addChild(scoreLabel)
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
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(in safeRect: CGRect) {
        let height: CGFloat = 118
        let width = safeRect.width
        panel.size = CGSize(width: width, height: height)
        panel.texture = ShapeTexture.roundedRect(
            size: panel.size,
            cornerRadius: 26,
            fill: GameTheme.panel,
            stroke: SKColor(white: 1, alpha: 0.12),
            lineWidth: 2
        )

        position = CGPoint(x: safeRect.midX, y: safeRect.maxY - height * 0.5 - 8)

        let sidePad: CGFloat = 36
        scoreLabel.fontSize = 34
        highScoreLabel.fontSize = 20
        hpCaption.fontSize = 18
        shieldCaption.fontSize = 18
        statusLabel.fontSize = 24

        scoreLabel.position = CGPoint(x: -width * 0.5 + sidePad, y: 28)
        highScoreLabel.position = CGPoint(x: -width * 0.5 + sidePad, y: 2)
        statusLabel.position = CGPoint(x: 0, y: -40)

        let pauseSize: CGFloat = 52
        pauseButton.size = CGSize(width: pauseSize, height: pauseSize)
        pauseButton.texture = ShapeTexture.roundedRect(
            size: pauseButton.size,
            cornerRadius: 14,
            fill: GameTheme.buttonMuted,
            stroke: GameTheme.hudCyan.withAlphaComponent(0.7),
            lineWidth: 2
        )
        pauseButton.position = CGPoint(x: width * 0.5 - sidePad - 4, y: 10)

        let pauseCenterInScene = convert(pauseButton.position, to: parent ?? self)
        let hitPad: CGFloat = 28
        pauseHitRect = CGRect(
            x: pauseCenterInScene.x - pauseSize * 0.5 - hitPad,
            y: pauseCenterInScene.y - pauseSize * 0.5 - hitPad,
            width: pauseSize + hitPad * 2,
            height: pauseSize + hitPad * 2
        )

        // Right cluster: HP / SHIELD meters left of the pause control.
        let meterRight = pauseButton.position.x - pauseSize * 0.5 - 28
        layoutMeterRow(
            caption: hpCaption,
            meter: hpMeter,
            blocks: hpBlocks,
            rightX: meterRight,
            y: 28
        )
        layoutMeterRow(
            caption: shieldCaption,
            meter: shieldMeter,
            blocks: shieldBlocks,
            rightX: meterRight,
            y: 0
        )
    }

    func setScore(_ value: Int) {
        scoreLabel.text = "SCORE  \(value)"
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
                stroke: filled ? GameTheme.hudCyan : GameTheme.hudCyan.withAlphaComponent(0.35)
            )
            block.alpha = filled ? 1 : 0.85
        }
        for (index, block) in shieldBlocks.enumerated() {
            let filled = index < split.shield
            block.texture = ShapeTexture.parallelogramBlock(
                size: blockSize,
                fill: filled ? GameTheme.shieldGold : GameTheme.shieldGoldDim,
                stroke: filled ? GameTheme.shieldGold : GameTheme.shieldGold.withAlphaComponent(0.35)
            )
            block.alpha = filled ? 1 : 0.85
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
        let spacing: CGFloat = 6
        let totalWidth = CGFloat(blocks.count) * blockSize.width + CGFloat(max(0, blocks.count - 1)) * spacing
        meter.position = CGPoint(x: rightX - totalWidth * 0.5, y: y)
        for (index, block) in blocks.enumerated() {
            block.size = blockSize
            let x = -totalWidth * 0.5 + blockSize.width * 0.5 + CGFloat(index) * (blockSize.width + spacing)
            block.position = CGPoint(x: x, y: 0)
        }
        caption.position = CGPoint(x: rightX - totalWidth - 18, y: y)
        caption.horizontalAlignmentMode = .right
    }

    private func style(_ label: SKLabelNode, alignment: SKLabelHorizontalAlignmentMode, color: SKColor) {
        label.fontName = GameFont.resolved(size: 38)
        label.fontColor = color
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
    }
}

/// Boss HP bar shown below the main HUD during the space-monster fight.
final class BossHealthBarNode: SKNode {
    private let panel = SKSpriteNode()
    private let track = SKSpriteNode()
    private let fill = SKSpriteNode()
    private let title = SKLabelNode()

    private var barWidth: CGFloat = 420

    override init() {
        super.init()
        zPosition = GameConstants.Z.hud + 1
        isHidden = true

        panel.color = GameTheme.panel
        addChild(panel)

        track.color = SKColor(white: 1, alpha: 0.12)
        addChild(track)

        fill.color = SKColor(red: 0.95, green: 0.28, blue: 0.18, alpha: 1)
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        addChild(fill)

        title.fontName = GameFont.resolved(size: 22)
        title.fontSize = 22
        title.fontColor = GameTheme.accent
        title.text = "SPACE MONSTER"
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .center
        addChild(title)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(in safeRect: CGRect, below hudHeight: CGFloat) {
        let width = min(safeRect.width - 80, 520)
        let height: CGFloat = 44
        barWidth = width - 32

        panel.size = CGSize(width: width, height: height)
        panel.texture = ShapeTexture.roundedRect(
            size: panel.size,
            cornerRadius: 18,
            fill: GameTheme.panel,
            stroke: SKColor(white: 1, alpha: 0.14),
            lineWidth: 2
        )
        position = CGPoint(x: safeRect.midX, y: safeRect.maxY - hudHeight - height * 0.5 - 18)

        title.position = CGPoint(x: 0, y: height * 0.5 + 16)

        track.size = CGSize(width: barWidth, height: 14)
        track.texture = ShapeTexture.roundedRect(
            size: track.size,
            cornerRadius: 7,
            fill: SKColor(white: 1, alpha: 0.10),
            stroke: SKColor(white: 1, alpha: 0.08),
            lineWidth: 1
        )
        track.position = CGPoint(x: 0, y: 0)

        fill.size = track.size
        fill.position = CGPoint(x: -barWidth * 0.5, y: 0)
        fill.texture = ShapeTexture.roundedRect(
            size: fill.size,
            cornerRadius: 7,
            fill: fill.color,
            stroke: SKColor(white: 1, alpha: 0.06),
            lineWidth: 1
        )
    }

    func show(maxHP: Int, title: String = "SPACE MONSTER") {
        isHidden = false
        self.title.text = title.uppercased()
        setHP(current: maxHP, maximum: maxHP)
    }

    func hideBar() {
        isHidden = true
    }

    func setHP(current: Int, maximum: Int) {
        let ratio = maximum > 0 ? CGFloat(current) / CGFloat(maximum) : 0
        fill.xScale = max(0, min(1, ratio))
    }

    func pulseDamage() {
        fill.run(.sequence([
            .colorize(with: .white, colorBlendFactor: 0.45, duration: 0.05),
            .colorize(with: SKColor(red: 0.95, green: 0.28, blue: 0.18, alpha: 1), colorBlendFactor: 0, duration: 0.12)
        ]))
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
                topHighlight: SKColor(white: 1, alpha: 0.10),
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
