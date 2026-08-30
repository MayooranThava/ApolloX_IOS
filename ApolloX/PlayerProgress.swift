//
//  PlayerProgress.swift
//  ApolloX
//
//  Persistent wallet, hangar unlocks, and hardpoint loadout. Uses the same
//  injectable UserDefaults suite as ScoreStore so tests never touch the device wallet.
//

import Foundation

enum PurchaseResult: Equatable {
    case purchased(remaining: Int)
    case alreadyOwned
    case cannotAfford(needed: Int)
    case unknownShip
}

enum EquipResult: Equatable {
    case equipped
    case notOwned
    case unknownShip
}

enum WeaponPurchaseResult: Equatable {
    case purchased(remaining: Int)
    case alreadyOwned
    case cannotAfford(needed: Int)
    case unknownWeapon
}

enum WeaponEquipResult: Equatable {
    case equipped
    case notOwned
    case unknownWeapon
    case wrongSlot
}

enum PlayerProgress {
    private static let creditsKey = "apolloX.walletCredits"
    private static let ownedKey = "apolloX.ownedShipIds"
    private static let equippedKey = "apolloX.equippedShipId"
    private static let ownedWeaponsKey = "apolloX.ownedWeaponIds"
    private static let equippedPrimaryKey = "apolloX.equippedPrimaryWeaponId"
    private static let equippedSpecialKey = "apolloX.equippedSpecialWeaponId"

    /// Same suite as `ScoreStore.storage` so high score, wallet, and hangar travel together.
    static var storage: UserDefaults {
        get { ScoreStore.storage }
        set { ScoreStore.storage = newValue }
    }

    static var credits: Int {
        max(0, storage.integer(forKey: creditsKey))
    }

    static var equippedShipId: String {
        let stored = storage.string(forKey: equippedKey) ?? PlayerShipCatalog.defaultShip.id
        return isOwned(stored) ? stored : PlayerShipCatalog.defaultShip.id
    }

    static var ownedShipIds: Set<String> {
        var owned = Set(storage.stringArray(forKey: ownedKey) ?? [])
        owned.insert(PlayerShipCatalog.defaultShip.id)
        return owned
    }

    static func isOwned(_ shipId: String) -> Bool {
        ownedShipIds.contains(shipId)
    }

    @discardableResult
    static func addCredits(_ amount: Int) -> Int {
        let next = max(0, credits + amount)
        storage.set(next, forKey: creditsKey)
        return next
    }

    @discardableResult
    static func purchase(_ shipId: String) -> PurchaseResult {
        guard let ship = PlayerShipCatalog.ship(id: shipId) else { return .unknownShip }
        if isOwned(shipId) { return .alreadyOwned }
        if credits < ship.price {
            return .cannotAfford(needed: ship.price - credits)
        }
        addCredits(-ship.price)
        var owned = ownedShipIds
        owned.insert(shipId)
        persistOwned(owned)
        _ = equip(shipId)
        return .purchased(remaining: credits)
    }

    @discardableResult
    static func equip(_ shipId: String) -> EquipResult {
        guard PlayerShipCatalog.ship(id: shipId) != nil else { return .unknownShip }
        guard isOwned(shipId) else { return .notOwned }
        storage.set(shipId, forKey: equippedKey)
        return .equipped
    }

    static func equippedShip() -> PlayerShip {
        PlayerShipCatalog.ship(id: equippedShipId) ?? PlayerShipCatalog.defaultShip
    }

    // MARK: - Hardpoints

    static var ownedWeaponIds: Set<String> {
        var owned = Set(storage.stringArray(forKey: ownedWeaponsKey) ?? [])
        owned.insert(WeaponCatalog.defaultPrimary.id)
        // Specials are locked until purchased — no free special owned by default,
        // but Pulse Laser is always available. Plasma Grenade is purchaseable;
        // players can still equip it only after buy. For first-run playability,
        // grant the default special as owned so the cooldown button always works.
        owned.insert(WeaponCatalog.defaultSpecial.id)
        return owned
    }

    static func isWeaponOwned(_ weaponId: String) -> Bool {
        ownedWeaponIds.contains(weaponId)
    }

    static var equippedPrimaryWeaponId: String {
        let stored = storage.string(forKey: equippedPrimaryKey) ?? WeaponCatalog.defaultPrimary.id
        guard let weapon = WeaponCatalog.weapon(id: stored), weapon.slot == .primary, isWeaponOwned(stored) else {
            return WeaponCatalog.defaultPrimary.id
        }
        return stored
    }

    static var equippedSpecialWeaponId: String {
        let stored = storage.string(forKey: equippedSpecialKey) ?? WeaponCatalog.defaultSpecial.id
        guard let weapon = WeaponCatalog.weapon(id: stored), weapon.slot == .special, isWeaponOwned(stored) else {
            return WeaponCatalog.defaultSpecial.id
        }
        return stored
    }

    static func equippedPrimary() -> WeaponItem {
        WeaponCatalog.weapon(id: equippedPrimaryWeaponId) ?? WeaponCatalog.defaultPrimary
    }

    static func equippedSpecial() -> WeaponItem {
        WeaponCatalog.weapon(id: equippedSpecialWeaponId) ?? WeaponCatalog.defaultSpecial
    }

    @discardableResult
    static func purchaseWeapon(_ weaponId: String) -> WeaponPurchaseResult {
        guard let weapon = WeaponCatalog.weapon(id: weaponId) else { return .unknownWeapon }
        if isWeaponOwned(weaponId) { return .alreadyOwned }
        if credits < weapon.price {
            return .cannotAfford(needed: weapon.price - credits)
        }
        addCredits(-weapon.price)
        var owned = ownedWeaponIds
        owned.insert(weaponId)
        persistOwnedWeapons(owned)
        _ = equipWeapon(weaponId)
        return .purchased(remaining: credits)
    }

    @discardableResult
    static func equipWeapon(_ weaponId: String) -> WeaponEquipResult {
        guard let weapon = WeaponCatalog.weapon(id: weaponId) else { return .unknownWeapon }
        guard isWeaponOwned(weaponId) else { return .notOwned }
        switch weapon.slot {
        case .primary:
            storage.set(weaponId, forKey: equippedPrimaryKey)
        case .special:
            storage.set(weaponId, forKey: equippedSpecialKey)
        }
        return .equipped
    }

    private static func persistOwned(_ owned: Set<String>) {
        storage.set(Array(owned).sorted(), forKey: ownedKey)
    }

    private static func persistOwnedWeapons(_ owned: Set<String>) {
        storage.set(Array(owned).sorted(), forKey: ownedWeaponsKey)
    }
}
