//
//  SceneHelpers.swift
//  ApolloX
//

import SpriteKit
import UIKit

extension SKScene {
    /// Converts the hosting view's safe-area insets into scene-space padding.
    var safeAreaInsetsInScene: UIEdgeInsets {
        guard let view else {
            return .zero
        }

        let insets = view.safeAreaInsets
        let scaleX = size.width / max(view.bounds.width, 1)
        let scaleY = size.height / max(view.bounds.height, 1)

        return UIEdgeInsets(
            top: insets.top * scaleY,
            left: insets.left * scaleX,
            bottom: insets.bottom * scaleY,
            right: insets.right * scaleX
        )
    }

    func makeGameLabel(
        text: String,
        fontSize: CGFloat,
        color: SKColor = .white,
        alignment: SKLabelHorizontalAlignmentMode = .center
    ) -> SKLabelNode {
        let resolvedFont = UIFont(name: GameConstants.fontName, size: fontSize) != nil
            ? GameConstants.fontName
            : GameConstants.fallbackFontName
        let label = SKLabelNode(fontNamed: resolvedFont)
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        label.zPosition = GameConstants.Z.hud
        return label
    }

    func addScrollingBackground() {
        let texture = SKTexture(imageNamed: "background")
        let height = size.height

        for index in 0..<2 {
            let background = SKSpriteNode(texture: texture)
            background.name = GameConstants.NodeName.background
            background.size = size
            background.anchorPoint = CGPoint(x: 0.5, y: 0)
            background.position = CGPoint(x: size.width / 2, y: CGFloat(index) * height)
            background.zPosition = GameConstants.Z.background
            addChild(background)

            let move = SKAction.moveBy(x: 0, y: -height, duration: 18)
            let reset = SKAction.moveBy(x: 0, y: height, duration: 0)
            background.run(.repeatForever(.sequence([move, reset])))
        }
    }

    func presentScene(_ scene: SKScene, duration: TimeInterval = 0.45) {
        scene.scaleMode = scaleMode
        view?.presentScene(scene, transition: .fade(withDuration: duration))
    }
}
