//
//  GameTitle.swift
//  ApolloX
//

import SpriteKit
import UIKit

final class GameTitleScene: SKScene {

    private var playButton: MenuButtonNode?
    private let titleLabel = SKLabelNode()
    private let subtitleLabel = SKLabelNode()
    private let bestLabel = SKLabelNode()
    private var instructionLabels: [SKLabelNode] = []

    override func didMove(to view: SKView) {
        HapticManager.prepare()
        addProductionBackground()

        titleLabel.fontName = GameFont.resolved(size: 120)
        titleLabel.text = "ApolloX"
        titleLabel.fontSize = 120
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = GameConstants.Z.hud
        addChild(titleLabel)

        subtitleLabel.fontName = GameFont.resolved(size: 36)
        subtitleLabel.text = "Dodge  •  Shoot  •  Survive"
        subtitleLabel.fontSize = 36
        subtitleLabel.fontColor = GameTheme.secondary
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.zPosition = GameConstants.Z.hud
        addChild(subtitleLabel)

        let instructions = [
            "Drag to steer your rocket",
            "Auto-fire destroys threats for points",
            "Shoot stars to charge a fire-rate boost",
            "Last as long as you can"
        ]
        for line in instructions {
            let label = makeGameLabel(text: line, fontSize: 32, color: SKColor(white: 0.78, alpha: 1))
            instructionLabels.append(label)
            addChild(label)
        }

        bestLabel.fontName = GameFont.resolved(size: 40)
        bestLabel.text = "BEST  \(ScoreStore.highScore)"
        bestLabel.fontSize = 40
        bestLabel.fontColor = GameTheme.accent
        bestLabel.verticalAlignmentMode = .center
        bestLabel.zPosition = GameConstants.Z.hud
        addChild(bestLabel)

        let button = MenuButtonNode(title: "Play", width: 420, height: 110, fontSize: 56, emphasized: true)
        playButton = button
        addChild(button)

        titleLabel.alpha = 0
        subtitleLabel.alpha = 0
        bestLabel.alpha = 0
        button.alpha = 0
        titleLabel.run(.fadeIn(withDuration: 0.45))
        subtitleLabel.run(.sequence([.wait(forDuration: 0.08), .fadeIn(withDuration: 0.4)]))
        bestLabel.run(.sequence([.wait(forDuration: 0.16), .fadeIn(withDuration: 0.4)]))
        button.run(.sequence([.wait(forDuration: 0.22), .fadeIn(withDuration: 0.4)]))

        whenSafeAreaReady { [weak self] in
            self?.relayout()
        }
    }

    private func relayout() {
        let safe = playfield.safeRect

        titleLabel.position = CGPoint(x: safe.midX, y: safe.maxY - 130)
        subtitleLabel.position = CGPoint(x: safe.midX, y: titleLabel.position.y - 90)

        var lineY = safe.midY + 90
        for label in instructionLabels {
            label.position = CGPoint(x: safe.midX, y: lineY)
            lineY -= 52
        }

        bestLabel.position = CGPoint(x: safe.midX, y: safe.minY + 260)
        playButton?.position = CGPoint(x: safe.midX, y: safe.minY + 130)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        relayout()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let playButton else { return }
        let point = touch.location(in: self)
        if playButton.containsTouch(point) {
            playButton.pulse()
            HapticManager.fire()
            presentScene(GameScene(size: size))
        }
    }
}
