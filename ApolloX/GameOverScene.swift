//
//  GameOverScene.swift
//  ApolloX
//

import SpriteKit
import UIKit

final class GameOverScene: SKScene {

    private let restartLabel = SKLabelNode()
    private let menuLabel = SKLabelNode()
    private var restartFrame = CGRect.zero
    private var menuFrame = CGRect.zero

    override func didMove(to view: SKView) {
        addScrollingBackground()

        let insets = safeAreaInsetsInScene
        let finalScore = ScoreStore.currentScore
        let best = ScoreStore.commitHighScoreIfNeeded()

        let gameOverLabel = makeGameLabel(text: "Game Over", fontSize: 120)
        gameOverLabel.position = CGPoint(x: size.width * 0.5, y: size.height * 0.68)
        addChild(gameOverLabel)

        let scoreLabel = makeGameLabel(text: "Score: \(finalScore)", fontSize: 72)
        scoreLabel.position = CGPoint(x: size.width * 0.5, y: size.height * 0.54)
        addChild(scoreLabel)

        let highScoreLabel = makeGameLabel(
            text: "Best: \(best)",
            fontSize: 64,
            color: SKColor(red: 1, green: 0.85, blue: 0.35, alpha: 1)
        )
        highScoreLabel.position = CGPoint(x: size.width * 0.5, y: size.height * 0.45)
        addChild(highScoreLabel)

        configureButton(restartLabel, text: "Restart", fontSize: 80)
        restartLabel.position = CGPoint(
            x: size.width * 0.5,
            y: max(insets.bottom, 40) + size.height * 0.26
        )
        addChild(restartLabel)
        restartFrame = restartLabel.frame.insetBy(dx: -70, dy: -36)

        configureButton(menuLabel, text: "Menu", fontSize: 56)
        menuLabel.fontColor = SKColor(white: 0.85, alpha: 1)
        menuLabel.position = CGPoint(
            x: size.width * 0.5,
            y: max(insets.bottom, 40) + size.height * 0.16
        )
        addChild(menuLabel)
        menuFrame = menuLabel.frame.insetBy(dx: -70, dy: -30)
    }

    private func configureButton(_ label: SKLabelNode, text: String, fontSize: CGFloat) {
        label.fontName = UIFont(name: GameConstants.fontName, size: fontSize) != nil
            ? GameConstants.fontName
            : GameConstants.fallbackFontName
        label.text = text
        label.fontSize = fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.zPosition = GameConstants.Z.hud
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if restartFrame.contains(point) || restartLabel.contains(point) {
            HapticManager.fire()
            presentScene(GameScene(size: size))
            return
        }

        if menuFrame.contains(point) || menuLabel.contains(point) {
            HapticManager.fire()
            presentScene(GameTitleScene(size: size))
        }
    }
}
