//
//  GameViewController.swift
//  ApolloX
//

import UIKit
import SpriteKit
import AVFoundation

final class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        configureAudioSession()
        HapticManager.prepare()
        // Apple: set the Game Center authenticate handler at launch. Do not gate play on it.
        GameCenterService.authenticateAtLaunch()

        guard let skView = view as? SKView else { return }

        skView.ignoresSiblingOrder = true
        skView.isMultipleTouchEnabled = false
        skView.shouldCullNonVisibleNodes = true
        skView.accessibilityIdentifier = GameConstants.Accessibility.titleScene
        skView.accessibilityLabel = GameConstants.displayName

        // Production default: hide SpriteKit debug overlays.
        // Pass -ApolloXShowStats as a launch argument when you need FPS/node counts.
        let showStats = ProcessInfo.processInfo.arguments.contains("-ApolloXShowStats")
        skView.showsFPS = showStats
        skView.showsNodeCount = showStats
        skView.showsPhysics = false
        skView.showsDrawCount = false

        FramePacing.start(on: skView)

        let scene = GameTitleScene(size: GameConstants.sceneSize)
        scene.scaleMode = .aspectFill
        skView.presentScene(scene)

        // Decode combat textures/audio after the first frame so launch is not watchdog-close
        // on older review devices.
        DispatchQueue.main.async {
            TextureCache.preload()
            AudioManager.preload()
            AudioManager.startBackgroundMusicIfNeeded()
            PlayerShipCatalog.registerTextures()
            WeaponCatalog.registerTextures()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        FramePacing.handleMemoryWarning()
    }

    deinit {
        FramePacing.stopMonitoring()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio is optional; keep gameplay running if the session fails.
        }
    }

    override var shouldAutorotate: Bool { false }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override var prefersStatusBarHidden: Bool { true }

    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
}
