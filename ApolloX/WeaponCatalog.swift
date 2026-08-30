//
//  WeaponCatalog.swift
//  ApolloX
//
//  Hangar hardpoints: one equipped primary (auto-fire) and one special (cooldown).
//

import SpriteKit
import UIKit

enum WeaponSlot: String {
    case primary
    case special
}

enum PrimaryWeaponID: String, CaseIterable {
    case pulseLaser
    case scatterBolts
    case railSpike
    case ionNeedle
}

enum SpecialWeaponID: String, CaseIterable {
    case plasmaGrenade
    case seekerPod
    case flakBurst
    case cooldownMine
}

struct WeaponItem: Equatable {
    let id: String
    let name: String
    let blurb: String
    let price: Int
    let slot: WeaponSlot
    let textureName: String
    let accent: SKColor

    var isFree: Bool { price <= 0 }

    var slotLabel: String {
        switch slot {
        case .primary: return "PRIMARY"
        case .special: return "SPECIAL"
        }
    }
}

enum WeaponCatalog {
    static let pulseLaser = WeaponItem(
        id: PrimaryWeaponID.pulseLaser.rawValue,
        name: "Pulse Laser",
        blurb: "Standard auto bolts — balanced",
        price: 0,
        slot: .primary,
        textureName: "weaponPulseLaser",
        accent: SKColor(red: 0.35, green: 0.92, blue: 1.0, alpha: 1)
    )

    static let scatterBolts = WeaponItem(
        id: PrimaryWeaponID.scatterBolts.rawValue,
        name: "Scatter Bolts",
        blurb: "Triple cone — clears swarms",
        price: 450,
        slot: .primary,
        textureName: "weaponScatterBolts",
        accent: SKColor(red: 1.0, green: 0.72, blue: 0.28, alpha: 1)
    )

    static let railSpike = WeaponItem(
        id: PrimaryWeaponID.railSpike.rawValue,
        name: "Rail Spike",
        blurb: "Piercing lance — punches through",
        price: 800,
        slot: .primary,
        textureName: "weaponRailSpike",
        accent: SKColor(red: 0.55, green: 0.85, blue: 1.0, alpha: 1)
    )

    static let ionNeedle = WeaponItem(
        id: PrimaryWeaponID.ionNeedle.rawValue,
        name: "Ion Needle",
        blurb: "Rapid stream — shreds bosses",
        price: 1100,
        slot: .primary,
        textureName: "weaponIonNeedle",
        accent: SKColor(red: 0.45, green: 1.0, blue: 0.72, alpha: 1)
    )

    static let plasmaGrenade = WeaponItem(
        id: SpecialWeaponID.plasmaGrenade.rawValue,
        name: "Plasma Grenade",
        blurb: "Lobbed AoE burst",
        price: 500,
        slot: .special,
        textureName: "weaponPlasmaGrenade",
        accent: SKColor(red: 0.55, green: 1.0, blue: 0.35, alpha: 1)
    )

    static let seekerPod = WeaponItem(
        id: SpecialWeaponID.seekerPod.rawValue,
        name: "Seeker Pod",
        blurb: "Homing strike — boss hunter",
        price: 750,
        slot: .special,
        textureName: "weaponSeekerPod",
        accent: SKColor(red: 1.0, green: 0.45, blue: 0.85, alpha: 1)
    )

    static let flakBurst = WeaponItem(
        id: SpecialWeaponID.flakBurst.rawValue,
        name: "Flak Burst",
        blurb: "Point-blank radial clear",
        price: 650,
        slot: .special,
        textureName: "weaponFlakBurst",
        accent: SKColor(red: 1.0, green: 0.55, blue: 0.22, alpha: 1)
    )

    static let cooldownMine = WeaponItem(
        id: SpecialWeaponID.cooldownMine.rawValue,
        name: "Cooldown Mine",
        blurb: "Drop a proximity charge",
        price: 900,
        slot: .special,
        textureName: "weaponCooldownMine",
        accent: SKColor(red: 1.0, green: 0.88, blue: 0.25, alpha: 1)
    )

    static let defaultPrimary = pulseLaser
    static let defaultSpecial = plasmaGrenade

    static let primaries: [WeaponItem] = [
        pulseLaser, scatterBolts, railSpike, ionNeedle
    ]

    static let specials: [WeaponItem] = [
        plasmaGrenade, seekerPod, flakBurst, cooldownMine
    ]

    /// Browse order in the Hangar Weapons tab.
    static let all: [WeaponItem] = primaries + specials

    static func weapon(id: String) -> WeaponItem? {
        all.first { $0.id == id }
    }

    static func primaryID(_ id: String) -> PrimaryWeaponID {
        PrimaryWeaponID(rawValue: id) ?? .pulseLaser
    }

    static func specialID(_ id: String) -> SpecialWeaponID {
        SpecialWeaponID(rawValue: id) ?? .plasmaGrenade
    }

    static func registerTextures() {
        for item in all {
            if TextureCache.optional(item.textureName) == nil {
                TextureCache.store(item.textureName, texture: makeIcon(for: item))
            }
        }
        WeaponTextures.registerCombatTextures()
    }

    private static let canvasSize = CGSize(width: 160, height: 160)

    private static func makeIcon(for item: WeaponItem) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let bounds = CGRect(origin: .zero, size: canvasSize)
            drawBackdrop(in: cg, bounds: bounds, accent: item.accent)

            switch item.id {
            case PrimaryWeaponID.pulseLaser.rawValue:
                drawPulseIcon(in: cg, bounds: bounds, accent: item.accent)
            case PrimaryWeaponID.scatterBolts.rawValue:
                drawScatterIcon(in: cg, bounds: bounds, accent: item.accent)
            case PrimaryWeaponID.railSpike.rawValue:
                drawRailIcon(in: cg, bounds: bounds, accent: item.accent)
            case PrimaryWeaponID.ionNeedle.rawValue:
                drawIonIcon(in: cg, bounds: bounds, accent: item.accent)
            case SpecialWeaponID.plasmaGrenade.rawValue:
                drawGrenadeIcon(in: cg, bounds: bounds, accent: item.accent)
            case SpecialWeaponID.seekerPod.rawValue:
                drawSeekerIcon(in: cg, bounds: bounds, accent: item.accent)
            case SpecialWeaponID.flakBurst.rawValue:
                drawFlakIcon(in: cg, bounds: bounds, accent: item.accent)
            case SpecialWeaponID.cooldownMine.rawValue:
                drawMineIcon(in: cg, bounds: bounds, accent: item.accent)
            default:
                break
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = true
        return texture
    }

    private static func drawBackdrop(in cg: CGContext, bounds: CGRect, accent: SKColor) {
        let plate = UIBezierPath(roundedRect: bounds.insetBy(dx: 8, dy: 8), cornerRadius: 28)
        UIColor(white: 0.08, alpha: 0.92).setFill()
        plate.fill()
        accent.withAlphaComponent(0.55).setStroke()
        plate.lineWidth = 3
        plate.stroke()
    }

    private static func drawPulseIcon(in cg: CGContext, bounds: CGRect, accent: SKColor) {
        let bolt = UIBezierPath(roundedRect: CGRect(x: bounds.midX - 14, y: bounds.minY + 28, width: 28, height: 96), cornerRadius: 10)
        accent.setFill()
        bolt.fill()
        UIColor.white.setFill()
        UIBezierPath(roundedRect: CGRect(x: bounds.midX - 6, y: bounds.minY + 40, width: 12, height: 64), cornerRadius: 5).fill()
    }

    private static func drawScatterIcon(in cg: CGContext, bounds: CGRect, accent: SKColor) {
        for offset in [-36, 0, 36] as [CGFloat] {
            let bolt = UIBezierPath()
            bolt.move(to: CGPoint(x: bounds.midX + offset * 0.25, y: bounds.maxY - 34))
            bolt.addLine(to: CGPoint(x: bounds.midX + offset, y: bounds.minY + 34))
            bolt.addLine(to: CGPoint(x: bounds.midX + offset + 10, y: bounds.minY + 34))
            bolt.addLine(to: CGPoint(x: bounds.midX + offset * 0.25 + 10, y: bounds.maxY - 34))
            bolt.close()
            accent.setFill()
            bolt.fill()
        }
    }

    private static func drawRailIcon(in cg: CGContext, bounds: CGRect, accent: SKColor) {
        let spike = UIBezierPath()
        spike.move(to: CGPoint(x: bounds.midX, y: bounds.minY + 22))
        spike.addLine(to: CGPoint(x: bounds.midX + 18, y: bounds.maxY - 30))
        spike.addLine(to: CGPoint(x: bounds.midX - 18, y: bounds.maxY - 30))
        spike.close()
        accent.setFill()
        spike.fill()
        UIColor.white.withAlphaComponent(0.9).setFill()
        UIBezierPath(rect: CGRect(x: bounds.midX - 4, y: bounds.minY + 36, width: 8, height: 78)).fill()
    }

    private static func drawIonIcon(in cg: CGContext, bounds: CGRect, accent: SKColor) {
        accent.setFill()
        for i in 0..<5 {
            let y = bounds.minY + 30 + CGFloat(i) * 18
            let w: CGFloat = 10 + CGFloat(i % 2) * 8
            UIBezierPath(roundedRect: CGRect(x: bounds.midX - w * 0.5, y: y, width: w, height: 10), cornerRadius: 4).fill()
        }
    }

    private static func drawGrenadeIcon(in cg: CGContext, bounds: CGRect, accent: SKColor) {
        let orb = UIBezierPath(ovalIn: CGRect(x: bounds.midX - 34, y: bounds.midY - 28, width: 68, height: 68))
        accent.setFill()
        orb.fill()
        UIColor.white.withAlphaComponent(0.35).setFill()
        UIBezierPath(ovalIn: CGRect(x: bounds.midX - 16, y: bounds.midY - 18, width: 24, height: 18)).fill()
        UIColor(white: 0.15, alpha: 1).setFill()
        UIBezierPath(roundedRect: CGRect(x: bounds.midX - 10, y: bounds.midY - 48, width: 20, height: 22), cornerRadius: 4).fill()
    }

    private static func drawSeekerIcon(in cg: CGContext, bounds: CGRect, accent: SKColor) {
        let body = UIBezierPath(ovalIn: CGRect(x: bounds.midX - 28, y: bounds.midY - 22, width: 56, height: 56))
        accent.setFill()
        body.fill()
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(x: bounds.midX - 10, y: bounds.midY - 4, width: 20, height: 20)).fill()
        for angle in [0, 2.1, 4.2] as [CGFloat] {
            let fin = UIBezierPath()
            let cx = bounds.midX + cos(angle) * 42
            let cy = bounds.midY + sin(angle) * 42
            fin.move(to: CGPoint(x: bounds.midX, y: bounds.midY))
            fin.addLine(to: CGPoint(x: cx - 8, y: cy))
            fin.addLine(to: CGPoint(x: cx + 8, y: cy))
            fin.close()
            accent.withAlphaComponent(0.85).setFill()
            fin.fill()
        }
    }

    private static func drawFlakIcon(in cg: CGContext, bounds: CGRect, accent: SKColor) {
        UIColor.white.withAlphaComponent(0.9).setFill()
        UIBezierPath(ovalIn: CGRect(x: bounds.midX - 10, y: bounds.midY - 10, width: 20, height: 20)).fill()
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            let path = UIBezierPath()
            path.move(to: CGPoint(x: bounds.midX + cos(angle) * 18, y: bounds.midY + sin(angle) * 18))
            path.addLine(to: CGPoint(x: bounds.midX + cos(angle) * 58, y: bounds.midY + sin(angle) * 58))
            accent.setStroke()
            path.lineWidth = 6
            path.lineCapStyle = .round
            path.stroke()
        }
    }

    private static func drawMineIcon(in cg: CGContext, bounds: CGRect, accent: SKColor) {
        let core = UIBezierPath(ovalIn: CGRect(x: bounds.midX - 32, y: bounds.midY - 32, width: 64, height: 64))
        accent.setFill()
        core.fill()
        UIColor(white: 0.12, alpha: 1).setFill()
        UIBezierPath(ovalIn: CGRect(x: bounds.midX - 14, y: bounds.midY - 14, width: 28, height: 28)).fill()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3
            let spike = UIBezierPath(ovalIn: CGRect(
                x: bounds.midX + cos(angle) * 40 - 7,
                y: bounds.midY + sin(angle) * 40 - 7,
                width: 14,
                height: 14
            ))
            accent.setFill()
            spike.fill()
        }
    }
}

/// Combat projectile textures for hardpoints (pooled, mipmapped).
enum WeaponTextures {
    static let scatterBolt = "hardpointScatterBolt"
    static let railSpike = "hardpointRailSpike"
    static let ionNeedle = "hardpointIonNeedle"
    static let plasmaGrenade = "hardpointPlasmaGrenade"
    static let seekerPod = "hardpointSeekerPod"
    static let cooldownMine = "hardpointCooldownMine"

    static func registerCombatTextures() {
        store(scatterBolt, drawScatterBolt)
        store(railSpike, drawRailSpike)
        store(ionNeedle, drawIonNeedle)
        store(plasmaGrenade, drawGrenade)
        store(seekerPod, drawSeeker)
        store(cooldownMine, drawMine)
    }

    private static func store(_ key: String, _ draw: (CGContext, CGSize) -> Void) {
        guard TextureCache.optional(key) == nil else { return }
        let size = CGSize(width: 64, height: 96)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in draw(ctx.cgContext, size) }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = true
        TextureCache.store(key, texture: texture)
    }

    private static func drawScatterBolt(in cg: CGContext, size: CGSize) {
        let bolt = UIBezierPath(roundedRect: CGRect(x: size.width * 0.32, y: 8, width: size.width * 0.36, height: size.height - 16), cornerRadius: 8)
        UIColor(red: 1, green: 0.72, blue: 0.25, alpha: 1).setFill()
        bolt.fill()
    }

    private static func drawRailSpike(in cg: CGContext, size: CGSize) {
        let spike = UIBezierPath()
        spike.move(to: CGPoint(x: size.width * 0.5, y: 4))
        spike.addLine(to: CGPoint(x: size.width * 0.72, y: size.height - 8))
        spike.addLine(to: CGPoint(x: size.width * 0.28, y: size.height - 8))
        spike.close()
        UIColor(red: 0.55, green: 0.9, blue: 1, alpha: 1).setFill()
        spike.fill()
        UIColor.white.setFill()
        UIBezierPath(rect: CGRect(x: size.width * 0.46, y: 12, width: size.width * 0.08, height: size.height * 0.7)).fill()
    }

    private static func drawIonNeedle(in cg: CGContext, size: CGSize) {
        let needle = UIBezierPath(roundedRect: CGRect(x: size.width * 0.42, y: 6, width: size.width * 0.16, height: size.height - 12), cornerRadius: 4)
        UIColor(red: 0.4, green: 1, blue: 0.7, alpha: 1).setFill()
        needle.fill()
    }

    private static func drawGrenade(in cg: CGContext, size: CGSize) {
        let orb = UIBezierPath(ovalIn: CGRect(x: size.width * 0.18, y: size.height * 0.22, width: size.width * 0.64, height: size.width * 0.64))
        UIColor(red: 0.45, green: 1, blue: 0.35, alpha: 1).setFill()
        orb.fill()
    }

    private static func drawSeeker(in cg: CGContext, size: CGSize) {
        let body = UIBezierPath(ovalIn: CGRect(x: size.width * 0.2, y: size.height * 0.28, width: size.width * 0.6, height: size.width * 0.6))
        UIColor(red: 1, green: 0.4, blue: 0.85, alpha: 1).setFill()
        body.fill()
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(x: size.width * 0.4, y: size.height * 0.42, width: size.width * 0.2, height: size.width * 0.2)).fill()
    }

    private static func drawMine(in cg: CGContext, size: CGSize) {
        let core = UIBezierPath(ovalIn: CGRect(x: size.width * 0.18, y: size.height * 0.22, width: size.width * 0.64, height: size.width * 0.64))
        UIColor(red: 1, green: 0.88, blue: 0.2, alpha: 1).setFill()
        core.fill()
        UIColor(white: 0.1, alpha: 1).setFill()
        UIBezierPath(ovalIn: CGRect(x: size.width * 0.38, y: size.height * 0.38, width: size.width * 0.24, height: size.width * 0.24)).fill()
    }
}
