//
//  AudioManager.swift
//  ApolloX
//

import SpriteKit
import AVFoundation

enum AudioManager {
    static let laser = SKAction.playSoundFileNamed("laserSound.wav", waitForCompletion: false)
    static let explosion = SKAction.playSoundFileNamed("explosionShort.wav", waitForCompletion: false)
    static let star = SKAction.playSoundFileNamed("starCollect.wav", waitForCompletion: false)
    static let boost = SKAction.playSoundFileNamed("boostActivate.wav", waitForCompletion: false)
    static let lifeLost = SKAction.playSoundFileNamed("lifeLost.wav", waitForCompletion: false)
    static let mine = SKAction.playSoundFileNamed("minePulse.wav", waitForCompletion: false)
    static let uiTap = SKAction.playSoundFileNamed("uiTap.wav", waitForCompletion: false)

    static func play(_ action: SKAction, on node: SKNode) {
        node.run(action)
    }
}
