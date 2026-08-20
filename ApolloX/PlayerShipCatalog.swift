//
//  PlayerShipCatalog.swift
//  ApolloX
//
//  Hangar roster plus cached procedural skins. The starter rocket uses the
//  existing `playerShip` asset; paid skins are drawn once and stored in TextureCache.
//

import SpriteKit
import UIKit

struct PlayerShip {
    let id: String
    let name: String
    let blurb: String
    let price: Int
    let textureName: String
    let engineColor: SKColor
    let silhouette: PlayerShipCatalog.Silhouette

    var isFree: Bool { price <= 0 }
}

enum PlayerShipCatalog {
    enum Silhouette {
        case stock
        case lance
        case viper
        case phantom
    }

    static let defaultShip = PlayerShip(
        id: "scout",
        name: "Apollo Scout",
        blurb: "Your starting interceptor",
        price: 0,
        textureName: "playerShip",
        engineColor: SKColor(red: 1.0, green: 0.62, blue: 0.25, alpha: 1),
        silhouette: .stock
    )

    static let auroraLance = PlayerShip(
        id: "auroraLance",
        name: "Aurora Lance",
        blurb: "Twin-nacelle cyan striker",
        price: 500,
        textureName: "shipAuroraLance",
        engineColor: SKColor(red: 0.35, green: 0.92, blue: 1.0, alpha: 1),
        silhouette: .lance
    )

    static let emberViper = PlayerShip(
        id: "emberViper",
        name: "Ember Viper",
        blurb: "Crimson warbird with gold trim",
        price: 1000,
        textureName: "shipEmberViper",
        engineColor: SKColor(red: 1.0, green: 0.38, blue: 0.12, alpha: 1),
        silhouette: .viper
    )

    static let voidPhantom = PlayerShip(
        id: "voidPhantom",
        name: "Void Phantom",
        blurb: "Stealth dreadnought — rarest hull",
        price: 1500,
        textureName: "shipVoidPhantom",
        engineColor: SKColor(red: 0.78, green: 0.42, blue: 1.0, alpha: 1),
        silhouette: .phantom
    )

    static let all: [PlayerShip] = [
        defaultShip,
        auroraLance,
        emberViper,
        voidPhantom
    ]

    static func ship(id: String) -> PlayerShip? {
        all.first { $0.id == id }
    }

    static func registerTextures() {
        for ship in all where ship.silhouette != .stock {
            if TextureCache.optional(ship.textureName) == nil {
                TextureCache.store(ship.textureName, texture: makeTexture(for: ship))
            }
        }
    }

    private static let canvasSize = CGSize(width: 168, height: 220)

    private static func makeTexture(for ship: PlayerShip) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            switch ship.silhouette {
            case .lance:
                drawLance(in: cg, size: canvasSize)
            case .viper:
                drawViper(in: cg, size: canvasSize)
            case .phantom:
                drawPhantom(in: cg, size: canvasSize)
            case .stock:
                break
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = true
        return texture
    }

    /// Slim dart with twin cyan nacelles.
    private static func drawLance(in cg: CGContext, size: CGSize) {
        let w = size.width
        let h = size.height

        drawExhaust(in: cg, x: w * 0.34, y: h * 0.78, width: w * 0.14, height: h * 0.18,
                    outer: UIColor(red: 0.2, green: 0.85, blue: 1, alpha: 0.95),
                    inner: UIColor(red: 0.85, green: 1, blue: 1, alpha: 1))
        drawExhaust(in: cg, x: w * 0.52, y: h * 0.78, width: w * 0.14, height: h * 0.18,
                    outer: UIColor(red: 0.2, green: 0.85, blue: 1, alpha: 0.95),
                    inner: UIColor(red: 0.85, green: 1, blue: 1, alpha: 1))

        let leftNacelle = UIBezierPath(roundedRect: CGRect(x: w * 0.16, y: h * 0.38, width: w * 0.18, height: h * 0.42), cornerRadius: 8)
        let rightNacelle = UIBezierPath(roundedRect: CGRect(x: w * 0.66, y: h * 0.38, width: w * 0.18, height: h * 0.42), cornerRadius: 8)
        UIColor(red: 0.18, green: 0.42, blue: 0.62, alpha: 1).setFill()
        leftNacelle.fill()
        rightNacelle.fill()
        UIColor(red: 0.45, green: 0.92, blue: 1.0, alpha: 1).setStroke()
        leftNacelle.lineWidth = 2
        rightNacelle.lineWidth = 2
        leftNacelle.stroke()
        rightNacelle.stroke()

        let body = UIBezierPath()
        body.move(to: CGPoint(x: w * 0.5, y: h * 0.06))
        body.addLine(to: CGPoint(x: w * 0.62, y: h * 0.28))
        body.addLine(to: CGPoint(x: w * 0.60, y: h * 0.78))
        body.addLine(to: CGPoint(x: w * 0.40, y: h * 0.78))
        body.addLine(to: CGPoint(x: w * 0.38, y: h * 0.28))
        body.close()
        UIColor(red: 0.82, green: 0.93, blue: 1.0, alpha: 1).setFill()
        body.fill()
        UIColor(red: 0.20, green: 0.55, blue: 0.85, alpha: 1).setStroke()
        body.lineWidth = 2.5
        body.stroke()

        let canopy = UIBezierPath(ovalIn: CGRect(x: w * 0.42, y: h * 0.22, width: w * 0.16, height: h * 0.16))
        UIColor(red: 0.25, green: 0.78, blue: 1.0, alpha: 0.95).setFill()
        canopy.fill()

        let stripe = UIBezierPath(rect: CGRect(x: w * 0.48, y: h * 0.40, width: w * 0.04, height: h * 0.28))
        UIColor(red: 0.15, green: 0.85, blue: 1.0, alpha: 1).setFill()
        stripe.fill()
    }

    /// Aggressive crimson delta-wing fighter.
    private static func drawViper(in cg: CGContext, size: CGSize) {
        let w = size.width
        let h = size.height

        drawExhaust(in: cg, x: w * 0.38, y: h * 0.76, width: w * 0.24, height: h * 0.22,
                    outer: UIColor(red: 1, green: 0.42, blue: 0.08, alpha: 0.95),
                    inner: UIColor(red: 1, green: 0.88, blue: 0.25, alpha: 1))

        let wings = UIBezierPath()
        wings.move(to: CGPoint(x: w * 0.5, y: h * 0.32))
        wings.addLine(to: CGPoint(x: w * 0.04, y: h * 0.78))
        wings.addLine(to: CGPoint(x: w * 0.22, y: h * 0.70))
        wings.addLine(to: CGPoint(x: w * 0.50, y: h * 0.62))
        wings.addLine(to: CGPoint(x: w * 0.78, y: h * 0.70))
        wings.addLine(to: CGPoint(x: w * 0.96, y: h * 0.78))
        wings.close()
        UIColor(red: 0.72, green: 0.12, blue: 0.10, alpha: 1).setFill()
        wings.fill()
        UIColor(red: 1.0, green: 0.78, blue: 0.22, alpha: 1).setStroke()
        wings.lineWidth = 2.5
        wings.stroke()

        let body = UIBezierPath()
        body.move(to: CGPoint(x: w * 0.5, y: h * 0.05))
        body.addLine(to: CGPoint(x: w * 0.64, y: h * 0.30))
        body.addLine(to: CGPoint(x: w * 0.60, y: h * 0.80))
        body.addLine(to: CGPoint(x: w * 0.40, y: h * 0.80))
        body.addLine(to: CGPoint(x: w * 0.36, y: h * 0.30))
        body.close()
        UIColor(red: 0.92, green: 0.22, blue: 0.16, alpha: 1).setFill()
        body.fill()
        UIColor(red: 1.0, green: 0.84, blue: 0.32, alpha: 1).setStroke()
        body.lineWidth = 2.5
        body.stroke()

        let canopy = UIBezierPath(ovalIn: CGRect(x: w * 0.41, y: h * 0.18, width: w * 0.18, height: h * 0.14))
        UIColor(red: 1.0, green: 0.90, blue: 0.45, alpha: 0.95).setFill()
        canopy.fill()

        let chevron = UIBezierPath()
        chevron.move(to: CGPoint(x: w * 0.5, y: h * 0.40))
        chevron.addLine(to: CGPoint(x: w * 0.42, y: h * 0.52))
        chevron.addLine(to: CGPoint(x: w * 0.58, y: h * 0.52))
        chevron.close()
        UIColor(red: 1.0, green: 0.82, blue: 0.20, alpha: 1).setFill()
        chevron.fill()
    }

    /// Angular stealth hull with purple glow and gold visor.
    private static func drawPhantom(in cg: CGContext, size: CGSize) {
        let w = size.width
        let h = size.height

        drawExhaust(in: cg, x: w * 0.22, y: h * 0.74, width: w * 0.18, height: h * 0.20,
                    outer: UIColor(red: 0.62, green: 0.22, blue: 1.0, alpha: 0.92),
                    inner: UIColor(red: 0.95, green: 0.75, blue: 1.0, alpha: 1))
        drawExhaust(in: cg, x: w * 0.60, y: h * 0.74, width: w * 0.18, height: h * 0.20,
                    outer: UIColor(red: 0.62, green: 0.22, blue: 1.0, alpha: 0.92),
                    inner: UIColor(red: 0.95, green: 0.75, blue: 1.0, alpha: 1))

        let wings = UIBezierPath()
        wings.move(to: CGPoint(x: w * 0.5, y: h * 0.22))
        wings.addLine(to: CGPoint(x: w * 0.02, y: h * 0.58))
        wings.addLine(to: CGPoint(x: w * 0.18, y: h * 0.72))
        wings.addLine(to: CGPoint(x: w * 0.50, y: h * 0.64))
        wings.addLine(to: CGPoint(x: w * 0.82, y: h * 0.72))
        wings.addLine(to: CGPoint(x: w * 0.98, y: h * 0.58))
        wings.close()
        UIColor(red: 0.10, green: 0.07, blue: 0.18, alpha: 1).setFill()
        wings.fill()
        UIColor(red: 0.72, green: 0.42, blue: 1.0, alpha: 0.9).setStroke()
        wings.lineWidth = 2.4
        wings.stroke()

        let body = UIBezierPath()
        body.move(to: CGPoint(x: w * 0.5, y: h * 0.04))
        body.addLine(to: CGPoint(x: w * 0.68, y: h * 0.26))
        body.addLine(to: CGPoint(x: w * 0.62, y: h * 0.78))
        body.addLine(to: CGPoint(x: w * 0.38, y: h * 0.78))
        body.addLine(to: CGPoint(x: w * 0.32, y: h * 0.26))
        body.close()
        UIColor(red: 0.16, green: 0.12, blue: 0.28, alpha: 1).setFill()
        body.fill()
        UIColor(red: 0.95, green: 0.78, blue: 0.28, alpha: 1).setStroke()
        body.lineWidth = 2.6
        body.stroke()

        let visor = UIBezierPath()
        visor.move(to: CGPoint(x: w * 0.5, y: h * 0.16))
        visor.addLine(to: CGPoint(x: w * 0.62, y: h * 0.30))
        visor.addLine(to: CGPoint(x: w * 0.38, y: h * 0.30))
        visor.close()
        UIColor(red: 1.0, green: 0.84, blue: 0.28, alpha: 1).setFill()
        visor.fill()

        let ridge = UIBezierPath(rect: CGRect(x: w * 0.47, y: h * 0.34, width: w * 0.06, height: h * 0.32))
        UIColor(red: 0.78, green: 0.45, blue: 1.0, alpha: 0.95).setFill()
        ridge.fill()
    }

    private static func drawExhaust(
        in cg: CGContext,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        outer: UIColor,
        inner: UIColor
    ) {
        cg.saveGState()
        let flame = UIBezierPath()
        flame.move(to: CGPoint(x: x, y: y))
        flame.addLine(to: CGPoint(x: x + width, y: y))
        flame.addLine(to: CGPoint(x: x + width * 0.5, y: y + height))
        flame.close()
        outer.setFill()
        flame.fill()

        let core = UIBezierPath()
        core.move(to: CGPoint(x: x + width * 0.28, y: y))
        core.addLine(to: CGPoint(x: x + width * 0.72, y: y))
        core.addLine(to: CGPoint(x: x + width * 0.5, y: y + height * 0.62))
        core.close()
        inner.setFill()
        core.fill()
        cg.restoreGState()
    }
}
