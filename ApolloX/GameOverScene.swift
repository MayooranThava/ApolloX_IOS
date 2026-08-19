//
//  GameOverScene.swift
//  ApolloX
//

import SpriteKit
import UIKit

final class GameOverScene: SKScene {

    private let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.45), size: .zero)
    private let card = SKSpriteNode()
    private let titleLabel = SKLabelNode()
    private let scoreLabel = SKLabelNode()
    private let bestLabel = SKLabelNode()
    private var restartButton: MenuButtonNode?
    private var menuButton: MenuButtonNode?

    override func didMove(to view: SKView) {
        addProductionBackground()

        let finalScore = ScoreStore.currentScore
        let best = ScoreStore.commitHighScoreIfNeeded()

        dim.zPosition = GameConstants.Z.hud - 2
        addChild(dim)

        card.color = GameTheme.panel
        card.zPosition = GameConstants.Z.hud - 1
        addChild(card)

        titleLabel.fontName = GameFont.resolved(size: 86)
        titleLabel.text = "Game Over"
        titleLabel.fontSize = 86
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = GameConstants.Z.hud
        addChild(titleLabel)

        scoreLabel.fontName = GameFont.resolved(size: 54)
        scoreLabel.text = "SCORE  \(finalScore)"
        scoreLabel.fontSize = 54
        scoreLabel.fontColor = .white
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.zPosition = GameConstants.Z.hud
        addChild(scoreLabel)

        bestLabel.fontName = GameFont.resolved(size: 44)
        bestLabel.text = "BEST  \(best)"
        bestLabel.fontSize = 44
        bestLabel.fontColor = GameTheme.accent
        bestLabel.verticalAlignmentMode = .center
        bestLabel.zPosition = GameConstants.Z.hud
        addChild(bestLabel)

        let restart = MenuButtonNode(title: "Restart", width: 480, height: 112, fontSize: 52, emphasized: true)
        let menu = MenuButtonNode(title: "Menu", width: 360, height: 92, fontSize: 40, emphasized: false)
        restartButton = restart
        menuButton = menu
        addChild(restart)
        addChild(menu)

        // Entrance
        card.alpha = 0
        titleLabel.alpha = 0
        scoreLabel.alpha = 0
        bestLabel.alpha = 0
        restart.alpha = 0
        menu.alpha = 0
        card.run(.fadeIn(withDuration: 0.3))
        titleLabel.run(.sequence([.wait(forDuration: 0.05), .fadeIn(withDuration: 0.3)]))
        scoreLabel.run(.sequence([.wait(forDuration: 0.1), .fadeIn(withDuration: 0.3)]))
        bestLabel.run(.sequence([.wait(forDuration: 0.14), .fadeIn(withDuration: 0.3)]))
        restart.run(.sequence([.wait(forDuration: 0.18), .fadeIn(withDuration: 0.3)]))
        menu.run(.sequence([.wait(forDuration: 0.22), .fadeIn(withDuration: 0.3)]))

        whenSafeAreaReady { [weak self] in
            self?.relayout()
        }
    }

    private func relayout() {
        let safe = playfield.safeRect
        dim.size = playfield.visibleRect.size
        dim.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)

        let cardWidth = min(safe.width, 980)
        let cardHeight: CGFloat = 760
        card.size = CGSize(width: cardWidth, height: cardHeight)
        card.texture = ShapeTexture.roundedRect(
            size: card.size,
            cornerRadius: 42,
            fill: GameTheme.panel,
            stroke: SKColor(white: 1, alpha: 0.14),
            lineWidth: 2
        )
        card.position = CGPoint(x: safe.midX, y: safe.midY + 20)

        titleLabel.position = CGPoint(x: safe.midX, y: card.position.y + 250)
        scoreLabel.position = CGPoint(x: safe.midX, y: card.position.y + 90)
        bestLabel.position = CGPoint(x: safe.midX, y: card.position.y - 10)
        restartButton?.position = CGPoint(x: safe.midX, y: card.position.y - 170)
        menuButton?.position = CGPoint(x: safe.midX, y: card.position.y - 300)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        relayout()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if let restartButton, restartButton.containsTouch(point) {
            restartButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            presentScene(GameScene(size: size))
            return
        }

        if let menuButton, menuButton.containsTouch(point) {
            menuButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            presentScene(GameTitleScene(size: size))
        }
    }
}
