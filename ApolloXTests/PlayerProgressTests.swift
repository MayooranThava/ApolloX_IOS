//
//  PlayerProgressTests.swift
//  ApolloXTests
//

import XCTest
@testable import ApolloX

final class PlayerProgressTests: XCTestCase {
    private var suiteName = ""

    override func setUp() {
        super.setUp()
        suiteName = "ApolloXTests.PlayerProgress.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("could not create isolated UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        ScoreStore.storage = defaults
        ScoreStore.resetCurrentScore()
        ScoreStore.highScoreReporter = { _ in }
    }

    override func tearDown() {
        ScoreStore.highScoreReporter = { GameCenterService.reportScore($0) }
        ScoreStore.storage.removePersistentDomain(forName: suiteName)
        ScoreStore.storage = .standard
        ScoreStore.resetCurrentScore()
        super.tearDown()
    }

    func testDefaultShipIsOwnedAndEquipped() {
        XCTAssertTrue(PlayerProgress.isOwned(PlayerShipCatalog.defaultShip.id))
        XCTAssertEqual(PlayerProgress.equippedShipId, PlayerShipCatalog.defaultShip.id)
        XCTAssertEqual(PlayerProgress.credits, 0)
        XCTAssertFalse(PlayerProgress.isOwned(PlayerShipCatalog.auroraLance.id))
    }

    func testCatalogPrices() {
        XCTAssertEqual(PlayerShipCatalog.auroraLance.price, 500)
        XCTAssertEqual(PlayerShipCatalog.emberViper.price, 1000)
        XCTAssertEqual(PlayerShipCatalog.voidPhantom.price, 1500)
        XCTAssertEqual(PlayerShipCatalog.defaultShip.price, 0)
        XCTAssertEqual(PlayerShipCatalog.all.count, 4)
    }

    func testDefaultHardpointsAreOwned() {
        XCTAssertTrue(PlayerProgress.isWeaponOwned(WeaponCatalog.pulseLaser.id))
        XCTAssertTrue(PlayerProgress.isWeaponOwned(WeaponCatalog.plasmaGrenade.id))
        XCTAssertEqual(PlayerProgress.equippedPrimaryWeaponId, WeaponCatalog.pulseLaser.id)
        XCTAssertEqual(PlayerProgress.equippedSpecialWeaponId, WeaponCatalog.plasmaGrenade.id)
        XCTAssertFalse(PlayerProgress.isWeaponOwned(WeaponCatalog.railSpike.id))
        XCTAssertEqual(WeaponCatalog.all.count, 8)
        XCTAssertEqual(WeaponCatalog.primaries.count, 4)
        XCTAssertEqual(WeaponCatalog.specials.count, 4)
    }

    func testWeaponPurchaseAndEquip() {
        PlayerProgress.addCredits(450)
        XCTAssertEqual(
            PlayerProgress.purchaseWeapon(WeaponCatalog.scatterBolts.id),
            .purchased(remaining: 0)
        )
        XCTAssertEqual(PlayerProgress.equippedPrimaryWeaponId, WeaponCatalog.scatterBolts.id)
        XCTAssertEqual(PlayerProgress.equipWeapon(WeaponCatalog.pulseLaser.id), .equipped)
        XCTAssertEqual(PlayerProgress.equippedPrimaryWeaponId, WeaponCatalog.pulseLaser.id)

        PlayerProgress.addCredits(750)
        XCTAssertEqual(
            PlayerProgress.purchaseWeapon(WeaponCatalog.seekerPod.id),
            .purchased(remaining: 0)
        )
        XCTAssertEqual(PlayerProgress.equippedSpecialWeaponId, WeaponCatalog.seekerPod.id)
        XCTAssertEqual(
            PlayerProgress.purchaseWeapon(WeaponCatalog.seekerPod.id),
            .alreadyOwned
        )
    }

    func testWeaponPurchaseFailsWhenShort() {
        PlayerProgress.addCredits(100)
        XCTAssertEqual(
            PlayerProgress.purchaseWeapon(WeaponCatalog.flakBurst.id),
            .cannotAfford(needed: 550)
        )
        XCTAssertFalse(PlayerProgress.isWeaponOwned(WeaponCatalog.flakBurst.id))
        XCTAssertEqual(PlayerProgress.equipWeapon(WeaponCatalog.flakBurst.id), .notOwned)
        XCTAssertEqual(PlayerProgress.purchaseWeapon("missing"), .unknownWeapon)
    }

    func testPurchaseDeductsCreditsOwnsAndEquips() {
        PlayerProgress.addCredits(500)
        XCTAssertEqual(
            PlayerProgress.purchase(PlayerShipCatalog.auroraLance.id),
            .purchased(remaining: 0)
        )
        XCTAssertEqual(PlayerProgress.credits, 0)
        XCTAssertTrue(PlayerProgress.isOwned(PlayerShipCatalog.auroraLance.id))
        XCTAssertEqual(PlayerProgress.equippedShipId, PlayerShipCatalog.auroraLance.id)
    }

    func testPurchaseFailsWhenShortAndLeavesWalletUntouched() {
        PlayerProgress.addCredits(400)
        XCTAssertEqual(
            PlayerProgress.purchase(PlayerShipCatalog.auroraLance.id),
            .cannotAfford(needed: 100)
        )
        XCTAssertEqual(PlayerProgress.credits, 400)
        XCTAssertFalse(PlayerProgress.isOwned(PlayerShipCatalog.auroraLance.id))
        XCTAssertEqual(PlayerProgress.equippedShipId, PlayerShipCatalog.defaultShip.id)
    }

    func testCannotRebuyOwnedShip() {
        PlayerProgress.addCredits(1500)
        XCTAssertEqual(
            PlayerProgress.purchase(PlayerShipCatalog.emberViper.id),
            .purchased(remaining: 500)
        )
        XCTAssertEqual(
            PlayerProgress.purchase(PlayerShipCatalog.emberViper.id),
            .alreadyOwned
        )
        XCTAssertEqual(PlayerProgress.credits, 500)
    }

    func testEquipRequiresOwnership() {
        XCTAssertEqual(PlayerProgress.equip(PlayerShipCatalog.voidPhantom.id), .notOwned)
        XCTAssertEqual(PlayerProgress.equippedShipId, PlayerShipCatalog.defaultShip.id)

        PlayerProgress.addCredits(1500)
        _ = PlayerProgress.purchase(PlayerShipCatalog.voidPhantom.id)
        XCTAssertEqual(PlayerProgress.equip(PlayerShipCatalog.defaultShip.id), .equipped)
        XCTAssertEqual(PlayerProgress.equippedShipId, PlayerShipCatalog.defaultShip.id)
        XCTAssertEqual(PlayerProgress.equip(PlayerShipCatalog.voidPhantom.id), .equipped)
        XCTAssertEqual(PlayerProgress.equippedShipId, PlayerShipCatalog.voidPhantom.id)
    }

    func testUnknownShipIdsAreRejected() {
        XCTAssertEqual(PlayerProgress.purchase("missing"), .unknownShip)
        XCTAssertEqual(PlayerProgress.equip("missing"), .unknownShip)
    }

    func testRunScoreIsAddedToWalletOnce() {
        ScoreStore.addPoint(85)
        XCTAssertEqual(ScoreStore.commitWalletIfNeeded(), 85)
        XCTAssertEqual(ScoreStore.commitWalletIfNeeded(), 85, "second commit must not double-credit")
        XCTAssertEqual(PlayerProgress.credits, 85)
        XCTAssertEqual(ScoreStore.highScore, 0)
    }

    func testZeroScoreCommitDoesNotAddCredits() {
        XCTAssertEqual(ScoreStore.commitWalletIfNeeded(), 0)
        XCTAssertEqual(PlayerProgress.credits, 0)
    }

    func testWalletSurvivesNewRunReset() {
        ScoreStore.addPoint(40)
        XCTAssertEqual(ScoreStore.commitWalletIfNeeded(), 40)
        ScoreStore.resetCurrentScore()
        XCTAssertEqual(ScoreStore.currentScore, 0)
        XCTAssertEqual(PlayerProgress.credits, 40)

        ScoreStore.addPoint(12)
        XCTAssertEqual(ScoreStore.commitWalletIfNeeded(), 52)
        XCTAssertEqual(PlayerProgress.credits, 52)
    }

    func testWalletAndHangarPersistInUserDefaults() {
        PlayerProgress.addCredits(1600)
        XCTAssertEqual(
            PlayerProgress.purchase(PlayerShipCatalog.emberViper.id),
            .purchased(remaining: 600)
        )

        XCTAssertEqual(ScoreStore.storage.integer(forKey: "apolloX.walletCredits"), 600)
        XCTAssertEqual(ScoreStore.storage.string(forKey: "apolloX.equippedShipId"), PlayerShipCatalog.emberViper.id)
        let owned = Set(ScoreStore.storage.stringArray(forKey: "apolloX.ownedShipIds") ?? [])
        XCTAssertTrue(owned.contains(PlayerShipCatalog.emberViper.id))
    }
}
