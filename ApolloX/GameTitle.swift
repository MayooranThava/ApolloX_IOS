//
//  GameTitle.swift
//  ApolloX
//

import SpriteKit
import UIKit

final class GameTitleScene: SKScene {

    private let playLabel = SKLabelNode()
    private var playButtonFrame = CGRect.zero

    override func didMove(to view: SKView) {
        HapticManager.prepare()
        addScrollingBackground()

        let insets = safeAreaInsetsInScene

        let title = makeGameLabel(text: "ApolloX", fontSize: 160)
        title.position = CGPoint(x: size.width * 0.5, y: size.height * 0.72)
        addChild(title)

        let subtitle = makeGameLabel(
            text: "Dodge • Shoot • Survive",
            fontSize: 44,
            color: SKColor(white: 0.9, alpha: 1)
        )
        subtitle.position = CGPoint(x: size.width * 0.5, y: size.height * 0.64)
        addChild(subtitle)

        let instructions = [
            "Drag to steer your rocket",
            "Auto-fire destroys asteroids for points",
            "Shoot stars to charge a fire-rate boost",
            "Last as long as you can"
        ]

        var lineY = size.height * 0.52
        for line in instructions {
            let label = makeGameLabel(text: line, fontSize: 36, color: SKColor(white: 0.85, alpha: 1))
            label.position = CGPoint(x: size.width * 0.5, y: lineY)
            addChild(label)
            lineY -= 56
        }

        let highScore = makeGameLabel(
            text: "Best: \(ScoreStore.highScore)",
            fontSize: 48,
            color: SKColor(red: 1, green: 0.85, blue: 0.35, alpha: 1)
        )
        highScore.position = CGPoint(
            x: size.width * 0.5,
            y: max(insets.bottom, 40) + size.height * 0.28
        )
        addChild(highScore)

        playLabel.fontName = UIFont(name: GameConstants.fontName, size: 90) != nil
            ? GameConstants.fontName
            : GameConstants.fallbackFontName
        playLabel.text = "Play"
        playLabel.fontSize = 90
        playLabel.fontColor = .white
        playLabel.verticalAlignmentMode = .center
        playLabel.zPosition = GameConstants.Z.hud
        playLabel.position = CGPoint(
            x: size.width * 0.5,
            y: max(insets.bottom, 40) + size.height * 0.14
        )
        addChild(playLabel)

        playButtonFrame = playLabel.frame.insetBy(dx: -80, dy: -40)

        playLabel.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.55, duration: 0.7),
            .fadeAlpha(to: 1.0, duration: 0.7)
        ])))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if playButtonFrame.contains(point) || playLabel.contains(point) {
            HapticManager.fire()
            presentScene(GameScene(size: size))
        }
    }
}
