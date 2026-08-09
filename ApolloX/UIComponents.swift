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
    static func resolved(size: CGFloat) -> String {
        UIFont(name: GameConstants.fontName, size: size) != nil
            ? GameConstants.fontName
            : GameConstants.fallbackFontName
    }
}

final class HUDBarNode: SKNode {
    private let panel = SKShapeNode()
    private let scoreLabel = SKLabelNode()
    private let livesLabel = SKLabelNode()
    private let statusLabel = SKLabelNode()

    override init() {
        super.init()
        zPosition = GameConstants.Z.hud

        panel.fillColor = GameTheme.panel
        panel.strokeColor = SKColor(white: 1, alpha: 0.12)
        panel.lineWidth = 2
        addChild(panel)

        style(scoreLabel, alignment: .left, color: .white)
        style(livesLabel, alignment: .right, color: .white)
        style(statusLabel, alignment: .center, color: GameTheme.accent)
        addChild(scoreLabel)
        addChild(livesLabel)
        addChild(statusLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(in safeRect: CGRect) {
        let height: CGFloat = 108
        let width = safeRect.width
        let rect = CGRect(x: -width * 0.5, y: -height * 0.5, width: width, height: height)
        panel.path = CGPath(roundedRect: rect, cornerWidth: 30, cornerHeight: 30, transform: nil)

        position = CGPoint(x: safeRect.midX, y: safeRect.maxY - height * 0.5 - 8)

        let sidePad: CGFloat = 40
        scoreLabel.fontSize = 38
        livesLabel.fontSize = 38
        statusLabel.fontSize = 28

        scoreLabel.position = CGPoint(x: -width * 0.5 + sidePad, y: 14)
        livesLabel.position = CGPoint(x: width * 0.5 - sidePad, y: 14)
        statusLabel.position = CGPoint(x: 0, y: -28)
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

    func pulseStatus() {
        statusLabel.run(.sequence([
            .scale(to: 1.1, duration: 0.1),
            .scale(to: 1.0, duration: 0.12)
        ]))
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

final class MenuButtonNode: SKNode {
    private let background = SKShapeNode()
    private let label = SKLabelNode()
    private(set) var hitSize = CGSize.zero

    init(title: String, width: CGFloat, height: CGFloat, fontSize: CGFloat, emphasized: Bool = true) {
        super.init()
        zPosition = GameConstants.Z.hud

        let rect = CGRect(x: -width * 0.5, y: -height * 0.5, width: width, height: height)
        background.path = CGPath(roundedRect: rect, cornerWidth: height * 0.5, cornerHeight: height * 0.5, transform: nil)
        background.fillColor = emphasized ? GameTheme.buttonFill : GameTheme.buttonMuted
        background.strokeColor = GameTheme.buttonStroke
        background.lineWidth = 2
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
