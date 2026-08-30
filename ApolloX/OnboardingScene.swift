//
//  OnboardingScene.swift
//  ApolloX
//
//  First-run teach: steer, shoot, mines, boost — then into the first run.
//

import SpriteKit
import UIKit

final class OnboardingScene: SKScene {

    private struct Step {
        let title: String
        let body: String
        let tip: String
    }

    private let steps: [Step] = [
        Step(
            title: "Steer",
            body: "Drag left and right to fly your rocket.",
            tip: "Stay near the bottom — you have room to dodge."
        ),
        Step(
            title: "Shoot",
            body: "You fire automatically. Blast asteroids for points.",
            tip: "Stars power a rapid boost — make them count."
        ),
        Step(
            title: "Survive",
            body: "Mines take two hits. Green + restores a life.",
            tip: "Four bosses appear every 30 seconds. Stay sharp."
        )
    ]

    private var stepIndex = 0
    private let titleLabel = SKLabelNode()
    private let bodyLabel = SKLabelNode()
    private let tipLabel = SKLabelNode()
    private let progressLabel = SKLabelNode()
    private var nextButton: MenuButtonNode?
    private var skipButton: MenuButtonNode?
    private var dots: [SKSpriteNode] = []
    private var lastBackgroundTick: TimeInterval = 0

    override func didMove(to view: SKView) {
        view.accessibilityIdentifier = GameConstants.Accessibility.onboardingScene
        view.accessibilityLabel = "How to Play"
        HapticManager.prepare()
        addProductionBackground()

        titleLabel.fontName = GameFont.resolved(size: 86)
        titleLabel.fontSize = 86
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = GameConstants.Z.hud
        addChild(titleLabel)

        bodyLabel.fontName = GameFont.resolved(size: 36)
        bodyLabel.fontSize = 36
        bodyLabel.fontColor = GameTheme.secondary
        bodyLabel.verticalAlignmentMode = .center
        bodyLabel.horizontalAlignmentMode = .center
        bodyLabel.numberOfLines = 3
        bodyLabel.preferredMaxLayoutWidth = 900
        bodyLabel.zPosition = GameConstants.Z.hud
        addChild(bodyLabel)

        tipLabel.fontName = GameFont.resolved(size: 28)
        tipLabel.fontSize = 28
        tipLabel.fontColor = GameTheme.accent
        tipLabel.verticalAlignmentMode = .center
        tipLabel.horizontalAlignmentMode = .center
        tipLabel.numberOfLines = 2
        tipLabel.preferredMaxLayoutWidth = 900
        tipLabel.zPosition = GameConstants.Z.hud
        addChild(tipLabel)

        progressLabel.fontName = GameFont.resolved(size: 26)
        progressLabel.fontSize = 26
        progressLabel.fontColor = SKColor(white: 0.65, alpha: 1)
        progressLabel.verticalAlignmentMode = .center
        progressLabel.zPosition = GameConstants.Z.hud
        addChild(progressLabel)

        for _ in steps {
            let dot = SKSpriteNode(color: .white, size: CGSize(width: 14, height: 14))
            dots.append(dot)
            addChild(dot)
        }

        let next = MenuButtonNode(title: "Next", width: 420, height: 110, fontSize: 48, emphasized: true)
        nextButton = next
        addChild(next)

        let skip = MenuButtonNode(title: "Skip", width: 240, height: 80, fontSize: 36, emphasized: false)
        skipButton = skip
        addChild(skip)

        showStep(animated: false)
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

    override func didChangeSize(_ oldSize: CGSize) {
        relayoutProductionBackground()
        relayout()
    }

    private func showStep(animated: Bool) {
        let step = steps[stepIndex]
        titleLabel.text = step.title
        bodyLabel.text = step.body
        tipLabel.text = step.tip
        progressLabel.text = "\(stepIndex + 1) / \(steps.count)"
        nextButton?.setTitle(stepIndex == steps.count - 1 ? "Play" : "Next", emphasized: true)

        for (index, dot) in dots.enumerated() {
            let active = index == stepIndex
            dot.alpha = active ? 1 : 0.28
            dot.setScale(active ? 1.15 : 1)
        }

        if animated {
            for node in [titleLabel, bodyLabel, tipLabel] as [SKNode] {
                node.alpha = 0
                node.run(.fadeIn(withDuration: 0.25))
            }
        }
        relayout()
    }

    private func relayout() {
        relayoutProductionBackground()
        let safe = playfield.safeRect

        titleLabel.position = CGPoint(x: safe.midX, y: safe.midY + 220)
        bodyLabel.preferredMaxLayoutWidth = min(safe.width - 80, 980)
        bodyLabel.position = CGPoint(x: safe.midX, y: safe.midY + 60)
        tipLabel.preferredMaxLayoutWidth = min(safe.width - 80, 980)
        tipLabel.position = CGPoint(x: safe.midX, y: safe.midY - 80)
        progressLabel.position = CGPoint(x: safe.midX, y: safe.midY - 170)

        let spacing: CGFloat = 28
        let totalWidth = CGFloat(dots.count - 1) * spacing
        for (index, dot) in dots.enumerated() {
            let size: CGFloat = index == stepIndex ? 16 : 12
            dot.size = CGSize(width: size, height: size)
            dot.texture = ShapeTexture.roundedRect(
                size: dot.size,
                cornerRadius: size * 0.5,
                fill: index == stepIndex ? GameTheme.accent : SKColor(white: 1, alpha: 0.35),
                stroke: .clear,
                lineWidth: 0
            )
            dot.position = CGPoint(
                x: safe.midX - totalWidth * 0.5 + CGFloat(index) * spacing,
                y: safe.minY + 250
            )
        }

        nextButton?.position = CGPoint(x: safe.midX, y: safe.minY + 150)
        skipButton?.position = CGPoint(x: safe.midX, y: safe.minY + 58)
    }

    private func finish(playNow: Bool) {
        let firstRun = !AppSettings.hasCompletedOnboarding
        AppSettings.hasCompletedOnboarding = true
        if firstRun {
            presentScene(playNow ? GameScene(size: size) : GameTitleScene(size: size))
        } else {
            // Replayed from Settings → How to Play
            presentScene(SettingsScene(size: size))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if let skipButton, skipButton.containsTouch(point) {
            skipButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            finish(playNow: true)
            return
        }

        if let nextButton, nextButton.containsTouch(point) {
            nextButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            if stepIndex >= steps.count - 1 {
                finish(playNow: true)
            } else {
                stepIndex += 1
                showStep(animated: true)
            }
        }
    }
}
