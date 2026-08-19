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
        TextureCache.preload()
        AudioManager.preload()
        HapticManager.prepare()

        guard let skView = view as? SKView else { return }

        skView.ignoresSiblingOrder = true
        skView.isMultipleTouchEnabled = false
        skView.shouldCullNonVisibleNodes = true

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
