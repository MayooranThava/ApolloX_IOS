//
//  PlayerProgress.swift
//  ApolloX
//
//  Persistent wallet and hangar unlocks. Uses the same injectable UserDefaults
//  suite as ScoreStore so tests never touch the device wallet.
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

enum PlayerProgress {
    private static let creditsKey = "apolloX.walletCredits"
    private static let ownedKey = "apolloX.ownedShipIds"
    private static let equippedKey = "apolloX.equippedShipId"

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

    private static func persistOwned(_ owned: Set<String>) {
        storage.set(Array(owned).sorted(), forKey: ownedKey)
    }
}
