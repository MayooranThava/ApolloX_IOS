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

        guard let skView = view as? SKView else { return }

        let scene = GameTitleScene(size: GameConstants.sceneSize)
        scene.scaleMode = .aspectFill
        skView.presentScene(scene)

        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 120
        skView.isMultipleTouchEnabled = false

        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        #else
        skView.showsFPS = false
        skView.showsNodeCount = false
        #endif
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
