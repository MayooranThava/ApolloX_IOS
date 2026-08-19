//
//  AudioManager.swift
//  ApolloX
//

import AVFoundation
import SpriteKit

/// Preloaded `AVAudioPlayer` pools so combat SFX never decode WAV files on the render thread.
/// `SKAction.playSoundFileNamed` is convenient but hitches the first time each file is loaded,
/// which is very visible at 120 Hz.
enum AudioCue: String, CaseIterable {
    case laser = "laserSound"
    case explosion = "explosionShort"
    case star = "starCollect"
    case boost = "boostActivate"
    case lifeLost = "lifeLost"
    case mine = "minePulse"
    case uiTap = "uiTap"

    var overlappingVoices: Int {
        switch self {
        case .laser, .explosion: return 6
        default: return 2
        }
    }
}

enum AudioManager {
    private static var pools: [AudioCue: [AVAudioPlayer]] = [:]
    private static var nextIndex: [AudioCue: Int] = [:]

    static func preload() {
        guard pools.isEmpty else { return }
        for cue in AudioCue.allCases {
            guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav") else {
                continue
            }
            guard let data = try? Data(contentsOf: url) else { continue }
            var players: [AVAudioPlayer] = []
            players.reserveCapacity(cue.overlappingVoices)
            for _ in 0..<cue.overlappingVoices {
                guard let player = try? AVAudioPlayer(data: data) else { continue }
                player.prepareToPlay()
                players.append(player)
            }
            if !players.isEmpty {
                pools[cue] = players
                nextIndex[cue] = 0
            }
        }
    }

    static func play(_ cue: AudioCue, on node: SKNode? = nil) {
        if let players = pools[cue], !players.isEmpty {
            let start = nextIndex[cue] ?? 0
            if let idle = players.first(where: { !$0.isPlaying }) {
                idle.currentTime = 0
                idle.play()
                return
            }
            let player = players[start % players.count]
            nextIndex[cue] = start + 1
            player.currentTime = 0
            player.play()
            return
        }

        // Fallback if preload could not find the file (tests / missing bundle resources).
        if let node {
            node.run(.playSoundFileNamed("\(cue.rawValue).wav", waitForCompletion: false))
        }
    }
}
