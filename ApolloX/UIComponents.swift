//
//  UIComponents.swift
//  ApolloX
//

import SpriteKit
import UIKit

enum GameTheme {
    static let title = SKColor.white
    static let secondary = SKColor(white: 0.82, alpha: 1)
    static let accent = SKColor(red: 1.0, green: 0.84, blue: 0.38, alpha: 1)
    static let panel = SKColor(red: 0.04, green: 0.07, blue: 0.14, alpha: 0.62)
    static let buttonFill = SKColor(red: 0.14, green: 0.28, blue: 0.52, alpha: 0.95)
    static let buttonStroke = SKColor(white: 1, alpha: 0.22)
    static let buttonMuted = SKColor(white: 1, alpha: 0.10)
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
}

final class HUDBarNode: SKNode {
    private let panel = SKSpriteNode()
    private let scoreLabel = SKLabelNode()
    private let livesLabel = SKLabelNode()
    private let statusLabel = SKLabelNode()
    private let pauseButton = SKSpriteNode()
    private let pauseGlyph = SKLabelNode()

    /// Scene-space hit rect for the pause control (updated in `layout`).
    private(set) var pauseHitRect = CGRect.zero

    override init() {
        super.init()
        zPosition = GameConstants.Z.hud

        panel.color = GameTheme.panel
        addChild(panel)

        style(scoreLabel, alignment: .left, color: .white)
        style(livesLabel, alignment: .right, color: .white)
        style(statusLabel, alignment: .center, color: GameTheme.accent)
        addChild(scoreLabel)
        addChild(livesLabel)
        addChild(statusLabel)

        pauseButton.color = GameTheme.buttonMuted
        pauseButton.name = GameConstants.NodeName.pauseButton
        addChild(pauseButton)

        pauseGlyph.fontName = GameFont.resolved(size: 28)
        pauseGlyph.text = "II"
        pauseGlyph.fontSize = 26
        pauseGlyph.fontColor = .white
        pauseGlyph.verticalAlignmentMode = .center
        pauseGlyph.horizontalAlignmentMode = .center
        pauseGlyph.name = GameConstants.NodeName.pauseButton
        pauseButton.addChild(pauseGlyph)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(in safeRect: CGRect) {
        let height: CGFloat = 108
        let width = safeRect.width
        panel.size = CGSize(width: width, height: height)
        panel.texture = ShapeTexture.roundedRect(
            size: panel.size,
            cornerRadius: 30,
            fill: GameTheme.panel,
            stroke: SKColor(white: 1, alpha: 0.12),
            lineWidth: 2
        )

        position = CGPoint(x: safeRect.midX, y: safeRect.maxY - height * 0.5 - 8)

        let sidePad: CGFloat = 40
        scoreLabel.fontSize = 36
        livesLabel.fontSize = 36
        statusLabel.fontSize = 26

        scoreLabel.position = CGPoint(x: -width * 0.5 + sidePad, y: 14)
        livesLabel.position = CGPoint(x: width * 0.5 - sidePad - 70, y: 14)
        statusLabel.position = CGPoint(x: 0, y: -28)

        let pauseSize: CGFloat = 56
        pauseButton.size = CGSize(width: pauseSize, height: pauseSize)
        pauseButton.texture = ShapeTexture.roundedRect(
            size: pauseButton.size,
            cornerRadius: 16,
            fill: GameTheme.buttonMuted,
            stroke: GameTheme.buttonStroke,
            lineWidth: 2
        )
        pauseButton.position = CGPoint(x: width * 0.5 - sidePad - 8, y: 4)

        // Convert local pause button center to scene space for hit testing.
        let pauseCenterInScene = convert(pauseButton.position, to: parent ?? self)
        let hitPad: CGFloat = 28
        pauseHitRect = CGRect(
            x: pauseCenterInScene.x - pauseSize * 0.5 - hitPad,
            y: pauseCenterInScene.y - pauseSize * 0.5 - hitPad,
            width: pauseSize + hitPad * 2,
            height: pauseSize + hitPad * 2
        )
    }

    func setScore(_ value: Int) {
        scoreLabel.text = "SCORE  \(value)"
    }

    func setLives(_ value: Int) {
        livesLabel.text = "LIVES  \(value)"
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
        livesLabel.run(.sequence([
            .scale(to: 1.12, duration: 0.1),
            .scale(to: 1.0, duration: 0.12)
        ]))
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

    func show(maxHP: Int) {
        isHidden = false
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
    private let label = SKLabelNode()
    private(set) var hitSize = CGSize.zero

    init(title: String, width: CGFloat, height: CGFloat, fontSize: CGFloat, emphasized: Bool = true) {
        super.init()
        zPosition = GameConstants.Z.hud

        let fill = emphasized ? GameTheme.buttonFill : GameTheme.buttonMuted
        background.size = CGSize(width: width, height: height)
        background.texture = ShapeTexture.roundedRect(
            size: background.size,
            cornerRadius: height * 0.5,
            fill: fill,
            stroke: GameTheme.buttonStroke,
            lineWidth: 2
        )
        addChild(background)

        label.fontName = GameFont.resolved(size: fontSize)
        label.text = title
        label.fontSize = fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        addChild(label)

        hitSize = CGSize(width: width + 48, height: height + 40)
        name = title
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = .button
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

    func pulse() {
        run(.sequence([
            .scale(to: 0.96, duration: 0.06),
            .scale(to: 1.0, duration: 0.1)
        ]))
    }
}
