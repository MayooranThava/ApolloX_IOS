//
//  TextureCache.swift
//  ApolloX
//

import SpriteKit

enum TextureCache {
    private static var cache: [String: SKTexture] = [:]

    static func texture(_ name: String) -> SKTexture {
        if let existing = cache[name] {
            return existing
        }
        let texture = SKTexture(imageNamed: name)
        texture.filteringMode = .linear
        cache[name] = texture
        return texture
    }

    static func store(_ name: String, texture: SKTexture) {
        cache[name] = texture
    }

    static func optional(_ name: String) -> SKTexture? {
        cache[name]
    }

    static func preload() {
        let names = [
            "background",
            "playerShip",
            "enemyShip",
            "asteroid",
            "asteroid2",
            "spaceMine",
            "comet",
            "bullet",
            "powerbullet",
            "star_power",
            "health_plus",
            "explosion",
            "mini_explosion"
        ]
        SKTexture.preload(names.map(texture)) {}
    }
}
