//
//  GameTitle.swift
//  ApolloX
//
//  Title composition: brand → hero ship → stats → Play → secondary actions.
//  Play triggers a launch streak of the equipped rocket across the screen.
//

import SpriteKit
import UIKit

final class GameTitleScene: SKScene {

    private var playButton: MenuButtonNode?
    private var ranksButton: MenuButtonNode?
    private var storeButton: MenuButtonNode?
    private var settingsButton: MenuButtonNode?
    private var howToPlayButton: MenuButtonNode?
    private let titleLabel = SKLabelNode()
    private let subtitleLabel = SKLabelNode()
    private let bestLabel = SKLabelNode()
    private let creditsLabel = SKLabelNode()
    private let heroRoot = SKNode()
    private let heroShip = SKSpriteNode()
    private var heroFlame: SKNode?
    private var isLaunching = false
    private var lastBackgroundTick: TimeInterval = 0

    override func didMove(to view: SKView) {
        view.accessibilityIdentifier = GameConstants.Accessibility.titleScene
        view.accessibilityLabel = "ApolloX"
        HapticManager.prepare()
        GameCenterService.authenticateAtLaunch()
        GameCenterService.loadLocalPlayerRank { _ in }
        AudioManager.startBackgroundMusicIfNeeded()
        addProductionBackground()

        titleLabel.fontName = GameFont.resolved(size: 128)
        titleLabel.text = "ApolloX"
        titleLabel.fontSize = 128
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = GameConstants.Z.hud
        titleLabel.isAccessibilityElement = true
        titleLabel.accessibilityLabel = "ApolloX"
        addChild(titleLabel)

        subtitleLabel.fontName = GameFont.resolved(size: 34)
        subtitleLabel.text = "Dodge  •  Shoot  •  Survive"
        subtitleLabel.fontSize = 34
        subtitleLabel.fontColor = GameTheme.secondary
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.zPosition = GameConstants.Z.hud
        addChild(subtitleLabel)

        configureHeroShip()
        addChild(heroRoot)

        bestLabel.fontName = GameFont.resolved(size: 34)
        bestLabel.text = "BEST  \(ScoreStore.highScore)"
        bestLabel.fontSize = 34
        bestLabel.fontColor = GameTheme.accent
        bestLabel.verticalAlignmentMode = .center
        bestLabel.zPosition = GameConstants.Z.hud
        addChild(bestLabel)

        creditsLabel.fontName = GameFont.resolved(size: 34)
        creditsLabel.text = "CREDITS  \(PlayerProgress.credits)"
        creditsLabel.fontSize = 34
        creditsLabel.fontColor = GameTheme.credit
        creditsLabel.verticalAlignmentMode = .center
        creditsLabel.zPosition = GameConstants.Z.hud
        addChild(creditsLabel)

        let button = MenuButtonNode(title: "Play", width: 480, height: 112, fontSize: 54, emphasized: true)
        playButton = button
        addChild(button)

        let ranks = MenuButtonNode(title: "Ranks", width: 220, height: 84, fontSize: 34, emphasized: false)
        ranksButton = ranks
        addChild(ranks)

        let store = MenuButtonNode(title: "Store", width: 220, height: 84, fontSize: 34, emphasized: false)
        storeButton = store
        addChild(store)

        let settings = MenuButtonNode(title: "Settings", width: 220, height: 84, fontSize: 34, emphasized: false)
        settingsButton = settings
        addChild(settings)

        let howTo = MenuButtonNode(title: "How to Play", width: 220, height: 84, fontSize: 30, emphasized: false)
        howToPlayButton = howTo
        addChild(howTo)

        runEntrance()

        whenSafeAreaReady { [weak self] in
            self?.relayout()
            self?.startHeroIdleMotion()
        }
    }

    private func configureHeroShip() {
        let ship = PlayerProgress.equippedShip()
        PlayerShipCatalog.registerTextures()
        heroShip.texture = TextureCache.texture(ship.textureName)
        heroShip.size = heroShip.texture?.size() ?? CGSize(width: 160, height: 220)
        heroShip.setScale(GameRules.playerScale * 1.55)
        heroShip.zPosition = GameConstants.Z.player
        heroShip.name = "TitleHeroShip"
        heroRoot.zPosition = GameConstants.Z.player
        heroRoot.addChild(heroShip)

        let flame = makeEngineFlameNode(tint: ship.engineColor)
        flame.setScale(1.15)
        flame.position = CGPoint(x: 0, y: -heroShip.size.height * heroShip.xScale * 0.42)
        heroFlame = flame
        heroRoot.addChild(flame)
    }

    private func runEntrance() {
        titleLabel.alpha = 0
        subtitleLabel.alpha = 0
        bestLabel.alpha = 0
        creditsLabel.alpha = 0
        playButton?.alpha = 0
        ranksButton?.alpha = 0
        storeButton?.alpha = 0
        settingsButton?.alpha = 0
        howToPlayButton?.alpha = 0
        heroRoot.alpha = 0
        heroRoot.setScale(0.82)

        titleLabel.run(.fadeIn(withDuration: 0.4))
        subtitleLabel.run(.sequence([.wait(forDuration: 0.08), .fadeIn(withDuration: 0.35)]))
        heroRoot.run(.sequence([
            .wait(forDuration: 0.12),
            .group([
                .fadeIn(withDuration: 0.45),
                .scale(to: 1.0, duration: 0.5)
            ])
        ]))
        bestLabel.run(.sequence([.wait(forDuration: 0.28), .fadeIn(withDuration: 0.35)]))
        creditsLabel.run(.sequence([.wait(forDuration: 0.32), .fadeIn(withDuration: 0.35)]))
        playButton?.run(.sequence([.wait(forDuration: 0.36), .fadeIn(withDuration: 0.35)]))
        ranksButton?.run(.sequence([.wait(forDuration: 0.42), .fadeIn(withDuration: 0.3)]))
        storeButton?.run(.sequence([.wait(forDuration: 0.42), .fadeIn(withDuration: 0.3)]))
        settingsButton?.run(.sequence([.wait(forDuration: 0.48), .fadeIn(withDuration: 0.3)]))
        howToPlayButton?.run(.sequence([.wait(forDuration: 0.48), .fadeIn(withDuration: 0.3)]))
    }

    private func startHeroIdleMotion() {
        heroRoot.removeAction(forKey: "heroIdle")
        let bob = SKAction.sequence([
            .moveBy(x: 0, y: 18, duration: 1.35),
            .moveBy(x: 0, y: -18, duration: 1.35)
        ])
        bob.timingMode = .easeInEaseOut
        heroRoot.run(.repeatForever(bob), withKey: "heroIdle")

        heroRoot.removeAction(forKey: "heroSway")
        let sway = SKAction.sequence([
            .rotate(toAngle: 0.04, duration: 1.8),
            .rotate(toAngle: -0.04, duration: 1.8)
        ])
        sway.timingMode = .easeInEaseOut
        heroRoot.run(.repeatForever(sway), withKey: "heroSway")
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

        titleLabel.position = CGPoint(x: safe.midX, y: safe.maxY - 110)
        subtitleLabel.position = CGPoint(x: safe.midX, y: titleLabel.position.y - 78)

        // Hero owns the middle of the composition.
        if !isLaunching {
            heroRoot.position = CGPoint(x: safe.midX, y: safe.midY + 70)
        }

        bestLabel.position = CGPoint(x: safe.midX, y: safe.minY + 470)
        creditsLabel.position = CGPoint(x: safe.midX, y: safe.minY + 424)
        playButton?.position = CGPoint(x: safe.midX, y: safe.minY + 310)

        let rowY1 = safe.minY + 188
        let rowY2 = safe.minY + 88
        let gap: CGFloat = 128
        ranksButton?.position = CGPoint(x: safe.midX - gap, y: rowY1)
        storeButton?.position = CGPoint(x: safe.midX + gap, y: rowY1)
        settingsButton?.position = CGPoint(x: safe.midX - gap, y: rowY2)
        howToPlayButton?.position = CGPoint(x: safe.midX + gap, y: rowY2)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        relayoutProductionBackground()
        relayout()
    }

    private func startPlay() {
        guard !isLaunching else { return }
        isLaunching = true
        playLaunchThenPresent()
    }

    private func playLaunchThenPresent() {
        heroRoot.removeAction(forKey: "heroIdle")
        heroRoot.removeAction(forKey: "heroSway")
        heroRoot.zRotation = 0

        let safe = playfield.safeRect
        let start = heroRoot.position
        let end = CGPoint(x: safe.midX + 40, y: size.height + 280)

        // Soft trail streak behind the rocket.
        let streak = SKSpriteNode(color: SKColor(red: 1.0, green: 0.78, blue: 0.35, alpha: 0.55), size: CGSize(width: 18, height: 220))
        streak.zPosition = GameConstants.Z.effect
        streak.alpha = 0
        streak.position = start
        streak.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        addChild(streak)
        streak.run(.sequence([
            .fadeAlpha(to: 0.7, duration: 0.12),
            .group([
                .move(to: end, duration: 0.72),
                .fadeOut(withDuration: 0.72),
                .scaleY(to: 2.4, duration: 0.72)
            ]),
            .removeFromParent()
        ]))

        // Fade chrome so the launch reads as the only motion.
        let fadeChrome: [SKNode?] = [
            titleLabel, subtitleLabel, bestLabel, creditsLabel,
            playButton, ranksButton, storeButton, settingsButton, howToPlayButton
        ]
        for node in fadeChrome {
            node?.run(.fadeOut(withDuration: 0.28))
        }

        AudioManager.play(.boost)
        HapticManager.upgrade()

        let launch = SKAction.sequence([
            .group([
                .move(to: end, duration: 0.78),
                .scale(to: 1.35, duration: 0.78),
                .sequence([
                    .wait(forDuration: 0.35),
                    .fadeOut(withDuration: 0.4)
                ])
            ]),
            .run { [weak self] in
                guard let self else { return }
                if AppSettings.hasCompletedOnboarding {
                    self.presentScene(GameScene(size: self.size))
                } else {
                    self.presentScene(OnboardingScene(size: self.size))
                }
            }
        ])
        launch.timingMode = .easeIn
        heroRoot.run(launch)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isLaunching, let touch = touches.first else { return }
        let point = touch.location(in: self)
        if let playButton, playButton.containsTouch(point) {
            playButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            startPlay()
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
            return
        }
        if let settingsButton, settingsButton.containsTouch(point) {
            settingsButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            presentScene(SettingsScene(size: size))
            return
        }
        if let howToPlayButton, howToPlayButton.containsTouch(point) {
            howToPlayButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            presentScene(OnboardingScene(size: size))
        }
    }
}
