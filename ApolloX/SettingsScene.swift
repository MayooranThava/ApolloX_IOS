//
//  SettingsScene.swift
//  ApolloX
//
//  Sound / music / haptics toggles, volume sliders, how-to-play, and App Store legal links.
//

import SpriteKit
import UIKit

/// Vertical placement for Settings. All controls share one column so How to Play /
/// Privacy / Support cannot land on Haptics (they used to be pinned to `midY`).
enum SettingsLayout {
    static let rowSpacing: CGFloat = 124
    /// Extra space after Haptics before the legal / how-to buttons.
    static let sectionSpacing: CGFloat = 40
    static let linkSpacing: CGFloat = 112
    /// Minimum center-to-center gap between consecutive tappable rows.
    static let minimumControlGap: CGFloat = 100

    struct Positions: Equatable {
        let title: CGFloat
        let sound: CGFloat
        let sfxVolume: CGFloat
        let music: CGFloat
        let musicVolume: CGFloat
        let haptics: CGFloat
        let howToPlay: CGFloat
        let privacy: CGFloat
        let support: CGFloat
        let back: CGFloat
        let version: CGFloat

        var controlCenters: [CGFloat] {
            [sound, sfxVolume, music, musicVolume, haptics, howToPlay, privacy, support, back]
        }
    }

    static func positions(in safe: CGRect) -> Positions {
        let title = safe.maxY - 88
        let version = safe.minY + 26
        let back = safe.minY + 98

        let stackSpan = 4 * rowSpacing + sectionSpacing + 3 * linkSpacing
        let topLimit = title - 120
        let bottomLimit = back + 100
        let slack = (topLimit - bottomLimit) - stackSpan
        var sound = topLimit - max(0, slack) * 0.18
        if sound - stackSpan < bottomLimit {
            sound = bottomLimit + stackSpan
        }

        let sfxVolume = sound - rowSpacing
        let music = sfxVolume - rowSpacing
        let musicVolume = music - rowSpacing
        let haptics = musicVolume - rowSpacing
        let howToPlay = haptics - sectionSpacing - linkSpacing
        let privacy = howToPlay - linkSpacing
        let support = privacy - linkSpacing

        return Positions(
            title: title,
            sound: sound,
            sfxVolume: sfxVolume,
            music: music,
            musicVolume: musicVolume,
            haptics: haptics,
            howToPlay: howToPlay,
            privacy: privacy,
            support: support,
            back: back,
            version: version
        )
    }
}

final class SettingsScene: SKScene {

    private let titleLabel = SKLabelNode()
    private var soundToggle: SettingsToggleNode?
    private var musicToggle: SettingsToggleNode?
    private var sfxVolumeRow: SettingsVolumeRow?
    private var musicVolumeRow: SettingsVolumeRow?
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

        let sfxVol = SettingsVolumeRow(title: "SFX Volume", volume: AppSettings.sfxVolume) { value in
            AppSettings.sfxVolume = value
        }
        sfxVolumeRow = sfxVol
        addChild(sfxVol)

        let music = SettingsToggleNode(title: "Music", isOn: AppSettings.musicEnabled)
        musicToggle = music
        addChild(music)

        let musicVol = SettingsVolumeRow(title: "Music Volume", volume: AppSettings.musicVolume) { value in
            AppSettings.musicVolume = value
            AudioManager.refreshMusicVolume()
        }
        musicVolumeRow = musicVol
        addChild(musicVol)

        let haptics = SettingsToggleNode(title: "Haptics", isOn: AppSettings.hapticsEnabled)
        hapticsToggle = haptics
        addChild(haptics)

        let howTo = MenuButtonNode(title: "How to Play", width: 480, height: 88, fontSize: 36, emphasized: false)
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
        versionLabel.text = "\(GameConstants.displayName)  \(version) (\(build))"
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
        let rowWidth = min(safe.width - 80, 920)

        let place = SettingsLayout.positions(in: safe)
        titleLabel.position = CGPoint(x: safe.midX, y: place.title)
        soundToggle?.position = CGPoint(x: safe.midX, y: place.sound)
        soundToggle?.layout(width: rowWidth)
        sfxVolumeRow?.position = CGPoint(x: safe.midX, y: place.sfxVolume)
        sfxVolumeRow?.layout(width: rowWidth)
        musicToggle?.position = CGPoint(x: safe.midX, y: place.music)
        musicToggle?.layout(width: rowWidth)
        musicVolumeRow?.position = CGPoint(x: safe.midX, y: place.musicVolume)
        musicVolumeRow?.layout(width: rowWidth)
        hapticsToggle?.position = CGPoint(x: safe.midX, y: place.haptics)
        hapticsToggle?.layout(width: rowWidth)
        howToPlayButton?.position = CGPoint(x: safe.midX, y: place.howToPlay)
        privacyButton?.position = CGPoint(x: safe.midX, y: place.privacy)
        supportButton?.position = CGPoint(x: safe.midX, y: place.support)
        backButton?.position = CGPoint(x: safe.midX, y: place.back)
        versionLabel.position = CGPoint(x: safe.midX, y: place.version)
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

        if let musicToggle, musicToggle.containsTouch(point) {
            AppSettings.musicEnabled.toggle()
            musicToggle.setOn(AppSettings.musicEnabled)
            AudioManager.refreshMusicVolume()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            return
        }

        if let sfxVolumeRow, sfxVolumeRow.containsTouch(point) {
            sfxVolumeRow.adjust(at: point)
            AudioManager.play(.uiTap)
            HapticManager.fire()
            return
        }

        if let musicVolumeRow, musicVolumeRow.containsTouch(point) {
            musicVolumeRow.adjust(at: point)
            AudioManager.refreshMusicVolume()
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
