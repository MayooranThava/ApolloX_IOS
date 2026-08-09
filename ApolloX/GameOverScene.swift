//
//  GameOverScene.swift
//  ApolloX
//

import SpriteKit
import UIKit

final class GameOverScene: SKScene {

    private let titleLabel = SKLabelNode()
    private let scoreLabel = SKLabelNode()
    private let bestLabel = SKLabelNode()
    private var restartButton: MenuButtonNode?
    private var menuButton: MenuButtonNode?

    override func didMove(to view: SKView) {
        addProductionBackground()

        let finalScore = ScoreStore.currentScore
        let best = ScoreStore.commitHighScoreIfNeeded()

        titleLabel.fontName = GameFont.resolved(size: 96)
        titleLabel.text = "Game Over"
        titleLabel.fontSize = 96
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = GameConstants.Z.hud
        addChild(titleLabel)

        scoreLabel.fontName = GameFont.resolved(size: 58)
        scoreLabel.text = "SCORE  \(finalScore)"
        scoreLabel.fontSize = 58
        scoreLabel.fontColor = .white
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.zPosition = GameConstants.Z.hud
        addChild(scoreLabel)

        bestLabel.fontName = GameFont.resolved(size: 48)
        bestLabel.text = "BEST  \(best)"
        bestLabel.fontSize = 48
        bestLabel.fontColor = GameTheme.accent
        bestLabel.verticalAlignmentMode = .center
        bestLabel.zPosition = GameConstants.Z.hud
        addChild(bestLabel)

        let restart = MenuButtonNode(title: "Restart", width: 460, height: 110, fontSize: 52, emphasized: true)
        let menu = MenuButtonNode(title: "Menu", width: 340, height: 88, fontSize: 40, emphasized: false)
        restartButton = restart
        menuButton = menu
        addChild(restart)
        addChild(menu)

        whenSafeAreaReady { [weak self] in
            self?.relayout()
        }
    }

    private func relayout() {
        let safe = playfield.safeRect

        titleLabel.position = CGPoint(x: safe.midX, y: safe.maxY - 180)
        scoreLabel.position = CGPoint(x: safe.midX, y: safe.midY + 80)
        bestLabel.position = CGPoint(x: safe.midX, y: scoreLabel.position.y - 90)
        restartButton?.position = CGPoint(x: safe.midX, y: safe.minY + 250)
        menuButton?.position = CGPoint(x: safe.midX, y: safe.minY + 120)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        relayout()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if let restartButton, restartButton.containsTouch(point) {
            restartButton.pulse()
            HapticManager.fire()
            presentScene(GameScene(size: size))
            return
        }

        if let menuButton, menuButton.containsTouch(point) {
            menuButton.pulse()
            HapticManager.fire()
            presentScene(GameTitleScene(size: size))
        }
    }
}
