//
//  AppDelegate.swift
//  ApolloX
//

import UIKit
import SpriteKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // GameScene manages its own pause/resume lifecycle.
        if activeSKView()?.scene is GameScene { return }
        activeSKView()?.isPaused = true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        if activeSKView()?.scene is GameScene { return }
        activeSKView()?.isPaused = true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        FramePacing.apply()
        // Flush any score that failed while offline once Game Center is reachable again.
        GameCenterService.flushPendingScoreIfPossible()
        // GameScene resumes itself when appropriate; menus can always run.
        if activeSKView()?.scene is GameScene {
            return
        }
        activeSKView()?.isPaused = false
    }

    private func activeSKView() -> SKView? {
        if let skView = window?.rootViewController?.view as? SKView {
            return skView
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .view as? SKView
    }
}
