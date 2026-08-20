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
    }

    override func tearDown() {
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
