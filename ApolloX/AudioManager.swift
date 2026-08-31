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
    case rocketWarning = "rocketWarning"
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
    private static var musicPlayer: AVAudioPlayer?

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
        preloadMusicIfNeeded()
    }

    private static func preloadMusicIfNeeded() {
        guard musicPlayer == nil else { return }
        guard let url = Bundle.main.url(forResource: "backgroundMusicLoop", withExtension: "wav") else {
            return
        }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.prepareToPlay()
        musicPlayer = player
        applyMusicVolume()
    }

    static func startBackgroundMusicIfNeeded() {
        preloadMusicIfNeeded()
        guard AppSettings.musicEnabled else {
            musicPlayer?.stop()
            return
        }
        applyMusicVolume()
        guard let player = musicPlayer, !player.isPlaying else { return }
        player.currentTime = 0
        player.play()
    }

    static func stopBackgroundMusic() {
        musicPlayer?.stop()
    }

    static func refreshMusicVolume() {
        applyMusicVolume()
        if AppSettings.musicEnabled {
            startBackgroundMusicIfNeeded()
        } else {
            musicPlayer?.stop()
        }
    }

    private static func applyMusicVolume() {
        let volume = AppSettings.musicEnabled ? AppSettings.musicVolume : 0
        musicPlayer?.volume = volume
    }

    private static var effectiveSFXVolume: Float {
        AppSettings.soundEnabled ? AppSettings.sfxVolume : 0
    }

    static func play(_ cue: AudioCue, on node: SKNode? = nil) {
        guard effectiveSFXVolume > 0 else { return }

        if let players = pools[cue], !players.isEmpty {
            let volume = effectiveSFXVolume
            let start = nextIndex[cue] ?? 0
            if let idle = players.first(where: { !$0.isPlaying }) {
                idle.volume = volume
                idle.currentTime = 0
                idle.play()
                return
            }
            let player = players[start % players.count]
            nextIndex[cue] = start + 1
            player.volume = volume
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
