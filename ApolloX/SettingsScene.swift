//
//  SettingsScene.swift
//  ApolloX
//
//  Sound / haptics toggles, how-to-play, and App Store legal links.
//

import SpriteKit
import UIKit

final class SettingsScene: SKScene {

    private let titleLabel = SKLabelNode()
    private var soundToggle: SettingsToggleNode?
    private var hapticsToggle: SettingsToggleNode?
    private var howToPlayButton: MenuButtonNode?
    private var privacyButton: MenuButtonNode?
    private var supportButton: MenuButtonNode?
    private var backButton: MenuButtonNode?
    private let versionLabel = SKLabelNode()
    private var lastBackgroundTick: TimeInterval = 0

    override func didMove(to view: SKView) {
        view.accessibilityIdentifier = GameConstants.Accessibility.settingsScene
        view.accessibilityLabel = "Settings"
        HapticManager.prepare()
        addProductionBackground()

        titleLabel.fontName = GameFont.resolved(size: 72)
        titleLabel.text = "Settings"
        titleLabel.fontSize = 72
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = GameConstants.Z.hud
        addChild(titleLabel)

        let sound = SettingsToggleNode(title: "Sound", isOn: AppSettings.soundEnabled)
        soundToggle = sound
        addChild(sound)

        let haptics = SettingsToggleNode(title: "Haptics", isOn: AppSettings.hapticsEnabled)
        hapticsToggle = haptics
        addChild(haptics)

        let howTo = MenuButtonNode(title: "How to Play", width: 480, height: 96, fontSize: 40, emphasized: false)
        howToPlayButton = howTo
        addChild(howTo)

        let privacy = MenuButtonNode(title: "Privacy Policy", width: 480, height: 88, fontSize: 36, emphasized: false)
        privacyButton = privacy
        addChild(privacy)

        let support = MenuButtonNode(title: "Support", width: 480, height: 88, fontSize: 36, emphasized: false)
        supportButton = support
        addChild(support)

        let back = MenuButtonNode(title: "Back", width: 240, height: 88, fontSize: 40, emphasized: false)
        backButton = back
        addChild(back)

        versionLabel.fontName = GameFont.resolved(size: 24)
        versionLabel.fontSize = 24
        versionLabel.fontColor = SKColor(white: 0.55, alpha: 1)
        versionLabel.verticalAlignmentMode = .center
        versionLabel.zPosition = GameConstants.Z.hud
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        versionLabel.text = "Void Runner  \(version) (\(build))"
        addChild(versionLabel)

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

    private func relayout() {
        relayoutProductionBackground()
        let safe = playfield.safeRect

        titleLabel.position = CGPoint(x: safe.midX, y: safe.maxY - 120)
        soundToggle?.position = CGPoint(x: safe.midX, y: safe.midY + 180)
        soundToggle?.layout(width: min(safe.width - 80, 920))
        hapticsToggle?.position = CGPoint(x: safe.midX, y: safe.midY + 60)
        hapticsToggle?.layout(width: min(safe.width - 80, 920))
        howToPlayButton?.position = CGPoint(x: safe.midX, y: safe.midY - 80)
        privacyButton?.position = CGPoint(x: safe.midX, y: safe.midY - 200)
        supportButton?.position = CGPoint(x: safe.midX, y: safe.midY - 310)
        backButton?.position = CGPoint(x: safe.midX, y: safe.minY + 88)
        versionLabel.position = CGPoint(x: safe.midX, y: safe.minY + 28)
    }

    private func openURL(_ url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if let soundToggle, soundToggle.containsTouch(point) {
            AppSettings.soundEnabled.toggle()
            soundToggle.setOn(AppSettings.soundEnabled)
            AudioManager.play(.uiTap)
            HapticManager.fire()
            return
        }

        if let hapticsToggle, hapticsToggle.containsTouch(point) {
            AppSettings.hapticsEnabled.toggle()
            hapticsToggle.setOn(AppSettings.hapticsEnabled)
            AudioManager.play(.uiTap)
            HapticManager.fire()
            return
        }

        if let howToPlayButton, howToPlayButton.containsTouch(point) {
            howToPlayButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            presentScene(OnboardingScene(size: size))
            return
        }

        if let privacyButton, privacyButton.containsTouch(point) {
            privacyButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            openURL(AppSettings.privacyPolicyURL)
            return
        }

        if let supportButton, supportButton.containsTouch(point) {
            supportButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            openURL(AppSettings.supportURL)
            return
        }

        if let backButton, backButton.containsTouch(point) {
            backButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            presentScene(GameTitleScene(size: size))
        }
    }
}
