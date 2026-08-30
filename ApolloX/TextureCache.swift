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
        // Mipmaps help minified sprites (player/obstacles) on 3x Super Retina.
        // Background is magnified to fill the playfield, so skip the extra GPU memory.
        texture.usesMipmaps = (name != "background")
        cache[name] = texture
        return texture
    }

    static func store(_ name: String, texture: SKTexture) {
        cache[name] = texture
    }

    static func optional(_ name: String) -> SKTexture? {
        cache[name]
    }

    static func preload(completion: @escaping () -> Void = {}) {
        GameplayTextures.registerProceduralTextures()
        PlayerShipCatalog.registerTextures()
        let names = [
            GameplayTextures.fallingRocketName,
            GameplayTextures.warningBadgeName,
            "background",
            "playerShip",
            PlayerShipCatalog.auroraLance.textureName,
            PlayerShipCatalog.emberViper.textureName,
            PlayerShipCatalog.voidPhantom.textureName,
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
            "mini_explosion",
            "bossNebula",
            "bossCrimson",
            "bossFrost",
            "bossAcid"
        ]
        SKTexture.preload(names.map(texture), withCompletionHandler: completion)
    }
}
