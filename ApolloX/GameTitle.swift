//
//  GameTitle.swift
//  ApolloX
//

import SpriteKit
import UIKit

final class GameTitleScene: SKScene {

    private var playButton: MenuButtonNode?
    private var ranksButton: MenuButtonNode?
    private var storeButton: MenuButtonNode?
    private let titleLabel = SKLabelNode()
    private let subtitleLabel = SKLabelNode()
    private let bestLabel = SKLabelNode()
    private let creditsLabel = SKLabelNode()
    private var instructionLabels: [SKLabelNode] = []
    private var lastBackgroundTick: TimeInterval = 0

    override func didMove(to view: SKView) {
        view.accessibilityIdentifier = GameConstants.Accessibility.titleScene
        view.accessibilityLabel = "ApolloX"
        HapticManager.prepare()
        GameCenterService.authenticateAtLaunch()
        addProductionBackground()

        titleLabel.fontName = GameFont.resolved(size: 120)
        titleLabel.text = "ApolloX"
        titleLabel.fontSize = 120
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = GameConstants.Z.hud
        titleLabel.isAccessibilityElement = true
        titleLabel.accessibilityLabel = "ApolloX"
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
            "Blast asteroids and mines",
            "Six bosses — 30 seconds between each defeat",
            "Mines take two hits — stay clear",
            "Star boosts are rare — make them count",
            "Shoot the green + for an extra life"
        ]
        for line in instructions {
            let label = makeGameLabel(text: line, fontSize: 28, color: SKColor(white: 0.78, alpha: 1))
            instructionLabels.append(label)
            addChild(label)
        }

        bestLabel.fontName = GameFont.resolved(size: 36)
        bestLabel.text = "BEST  \(ScoreStore.highScore)"
        bestLabel.fontSize = 36
        bestLabel.fontColor = GameTheme.accent
        bestLabel.verticalAlignmentMode = .center
        bestLabel.zPosition = GameConstants.Z.hud
        addChild(bestLabel)

        creditsLabel.fontName = GameFont.resolved(size: 36)
        creditsLabel.text = "CREDITS  \(PlayerProgress.credits)"
        creditsLabel.fontSize = 36
        creditsLabel.fontColor = GameTheme.credit
        creditsLabel.verticalAlignmentMode = .center
        creditsLabel.zPosition = GameConstants.Z.hud
        addChild(creditsLabel)

        let button = MenuButtonNode(title: "Play", width: 420, height: 110, fontSize: 56, emphasized: true)
        playButton = button
        addChild(button)

        let ranks = MenuButtonNode(title: "Ranks", width: 420, height: 88, fontSize: 40, emphasized: false)
        ranksButton = ranks
        addChild(ranks)

        let store = MenuButtonNode(title: "Store", width: 420, height: 88, fontSize: 40, emphasized: false)
        storeButton = store
        addChild(store)

        titleLabel.alpha = 0
        subtitleLabel.alpha = 0
        bestLabel.alpha = 0
        creditsLabel.alpha = 0
        button.alpha = 0
        ranks.alpha = 0
        store.alpha = 0
        titleLabel.run(.fadeIn(withDuration: 0.45))
        subtitleLabel.run(.sequence([.wait(forDuration: 0.08), .fadeIn(withDuration: 0.4)]))
        bestLabel.run(.sequence([.wait(forDuration: 0.16), .fadeIn(withDuration: 0.4)]))
        creditsLabel.run(.sequence([.wait(forDuration: 0.18), .fadeIn(withDuration: 0.4)]))
        button.run(.sequence([.wait(forDuration: 0.22), .fadeIn(withDuration: 0.4)]))
        ranks.run(.sequence([.wait(forDuration: 0.26), .fadeIn(withDuration: 0.4)]))
        store.run(.sequence([.wait(forDuration: 0.30), .fadeIn(withDuration: 0.4)]))

        whenSafeAreaReady { [weak self] in
            self?.relayout()
        }
    }

    override func update(_ currentTime: TimeInterval) {
        if lastBackgroundTick > 0 {
            scrollingBackgroundNode()?.tick(deltaTime: currentTime - lastBackgroundTick)
        }
        lastBackgroundTick = currentTime
    }

    private func relayout() {
        relayoutProductionBackground()
        let safe = playfield.safeRect

        titleLabel.position = CGPoint(x: safe.midX, y: safe.maxY - 120)
        subtitleLabel.position = CGPoint(x: safe.midX, y: titleLabel.position.y - 84)

        var lineY = safe.midY + 150
        for label in instructionLabels {
            label.position = CGPoint(x: safe.midX, y: lineY)
            lineY -= 40
        }

        bestLabel.position = CGPoint(x: safe.midX, y: safe.minY + 430)
        creditsLabel.position = CGPoint(x: safe.midX, y: safe.minY + 382)
        playButton?.position = CGPoint(x: safe.midX, y: safe.minY + 268)
        ranksButton?.position = CGPoint(x: safe.midX, y: safe.minY + 168)
        storeButton?.position = CGPoint(x: safe.midX, y: safe.minY + 72)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        relayoutProductionBackground()
        relayout()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        if let playButton, playButton.containsTouch(point) {
            playButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            presentScene(GameScene(size: size))
            return
        }
        if let ranksButton, ranksButton.containsTouch(point) {
            ranksButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            presentScene(LeaderboardScene(size: size))
            return
        }
        if let storeButton, storeButton.containsTouch(point) {
            storeButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            presentScene(StoreScene(size: size))
        }
    }
}
