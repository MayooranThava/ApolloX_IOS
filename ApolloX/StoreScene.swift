//
//  StoreScene.swift
//  ApolloX
//
//  Hangar: Hulls (rockets) and Weapons (hardpoints). Swipe, buy with run credits, equip.
//

import SpriteKit
import UIKit

final class StoreScene: SKScene {

    private enum Shelf: Int {
        case hulls
        case weapons
    }

    private let cardSpacing: CGFloat = 680

    private let titleLabel = SKLabelNode()
    private let walletPanel = SKSpriteNode()
    private let walletLabel = SKLabelNode()
    private let hintLabel = SKLabelNode()
    private let statusLabel = SKLabelNode()
    private let track = SKNode()
    private let crop = SKCropNode()
    private var cropSize = CGSize.zero

    private var backButton: MenuButtonNode?
    private var actionButton: MenuButtonNode?
    private var leftButton: MenuButtonNode?
    private var rightButton: MenuButtonNode?
    private var hullsTab: MenuButtonNode?
    private var weaponsTab: MenuButtonNode?
    private var dots: [SKSpriteNode] = []

    private var shelf: Shelf = .hulls
    private var pageIndex = 0
    private var dragStartX: CGFloat?
    private var trackStartX: CGFloat = 0
    private var isDragging = false
    private var lastBackgroundTick: TimeInterval = 0

    private var shipCatalog: [PlayerShip] { PlayerShipCatalog.all }
    private var weaponCatalog: [WeaponItem] { WeaponCatalog.all }

    private var pageCount: Int {
        shelf == .hulls ? shipCatalog.count : weaponCatalog.count
    }

    override func didMove(to view: SKView) {
        view.accessibilityIdentifier = GameConstants.Accessibility.storeScene
        view.accessibilityLabel = "Hangar"
        HapticManager.prepare()
        PlayerShipCatalog.registerTextures()
        WeaponCatalog.registerTextures()
        addProductionBackground()

        titleLabel.fontName = GameFont.resolved(size: 72)
        titleLabel.text = "Hangar"
        titleLabel.fontSize = 72
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = GameConstants.Z.hud
        addChild(titleLabel)

        walletPanel.zPosition = GameConstants.Z.hud
        addChild(walletPanel)
        walletLabel.fontName = GameFont.resolved(size: 32)
        walletLabel.fontSize = 32
        walletLabel.fontColor = GameTheme.credit
        walletLabel.verticalAlignmentMode = .center
        walletLabel.horizontalAlignmentMode = .center
        walletLabel.zPosition = 1
        walletLabel.position = .zero
        walletPanel.addChild(walletLabel)

        hintLabel.fontName = GameFont.resolved(size: 26)
        hintLabel.text = "Swipe  •  Hulls / Weapons  •  Buy  •  Equip"
        hintLabel.fontSize = 26
        hintLabel.fontColor = SKColor(white: 0.78, alpha: 1)
        hintLabel.verticalAlignmentMode = .center
        hintLabel.zPosition = GameConstants.Z.hud
        addChild(hintLabel)

        statusLabel.fontName = GameFont.resolved(size: 28)
        statusLabel.fontSize = 28
        statusLabel.fontColor = GameTheme.accent
        statusLabel.verticalAlignmentMode = .center
        statusLabel.zPosition = GameConstants.Z.hud
        statusLabel.alpha = 0
        addChild(statusLabel)

        crop.zPosition = GameConstants.Z.hud
        crop.addChild(track)
        addChild(crop)

        let hulls = MenuButtonNode(title: "Hulls", width: 220, height: 72, fontSize: 32, emphasized: true)
        let weapons = MenuButtonNode(title: "Weapons", width: 260, height: 72, fontSize: 32, emphasized: false)
        hullsTab = hulls
        weaponsTab = weapons
        addChild(hulls)
        addChild(weapons)

        let back = MenuButtonNode(title: "Back", width: 240, height: 88, fontSize: 40, emphasized: false)
        backButton = back
        addChild(back)

        let action = MenuButtonNode(title: "Equip", width: 480, height: 110, fontSize: 44, emphasized: true)
        actionButton = action
        addChild(action)

        let left = MenuButtonNode(title: "<", width: 88, height: 88, fontSize: 44, emphasized: false)
        let right = MenuButtonNode(title: ">", width: 88, height: 88, fontSize: 44, emphasized: false)
        leftButton = left
        rightButton = right
        addChild(left)
        addChild(right)

        rebuildShelf(animated: false)
        refreshWallet()

        whenSafeAreaReady { [weak self] in
            self?.relayout()
            self?.snapToPage(self?.pageIndex ?? 0, animated: false)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        if lastBackgroundTick > 0 {
            scrollingBackgroundNode()?.tick(deltaTime: currentTime - lastBackgroundTick)
        }
        lastBackgroundTick = currentTime
    }

    override func didChangeSize(_ oldSize: CGSize) {
        relayout()
        snapToPage(pageIndex, animated: false)
    }

    private func rebuildShelf(animated: Bool) {
        track.removeAllChildren()
        switch shelf {
        case .hulls:
            for (index, ship) in shipCatalog.enumerated() {
                let card = makeShipCard(for: ship)
                card.position = CGPoint(x: CGFloat(index) * cardSpacing, y: 0)
                track.addChild(card)
            }
            pageIndex = shipCatalog.firstIndex(where: { $0.id == PlayerProgress.equippedShipId }) ?? 0
        case .weapons:
            for (index, weapon) in weaponCatalog.enumerated() {
                let card = makeWeaponCard(for: weapon)
                card.position = CGPoint(x: CGFloat(index) * cardSpacing, y: 0)
                track.addChild(card)
            }
            let equipped = Set([
                PlayerProgress.equippedPrimaryWeaponId,
                PlayerProgress.equippedSpecialWeaponId
            ])
            pageIndex = weaponCatalog.firstIndex(where: { equipped.contains($0.id) }) ?? 0
        }
        buildDots()
        hullsTab?.setTitle("Hulls", emphasized: shelf == .hulls)
        weaponsTab?.setTitle("Weapons", emphasized: shelf == .weapons)
        snapToPage(pageIndex, animated: animated)
        refreshAction()
        refreshDots()
    }

    private func makeShipCard(for ship: PlayerShip) -> SKNode {
        let root = makeCardChrome()
        let sprite = SKSpriteNode(texture: TextureCache.texture(ship.textureName))
        if let texSize = sprite.texture?.size(), texSize.width > 0 {
            sprite.size = texSize
        }
        sprite.setScale(1.35)
        sprite.position = CGPoint(x: 0, y: 110)
        sprite.zPosition = 2
        sprite.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 14, duration: 1.15),
            .moveBy(x: 0, y: -14, duration: 1.15)
        ])))
        root.addChild(sprite)
        addCardLabels(
            to: root,
            title: ship.name,
            blurb: ship.blurb,
            meta: "HULL",
            price: ship.price,
            isFree: ship.isFree,
            accent: ship.engineColor
        )
        return root
    }

    private func makeWeaponCard(for weapon: WeaponItem) -> SKNode {
        let root = makeCardChrome()
        let sprite = SKSpriteNode(texture: TextureCache.texture(weapon.textureName))
        if let texSize = sprite.texture?.size(), texSize.width > 0 {
            sprite.size = texSize
        }
        sprite.setScale(1.55)
        sprite.position = CGPoint(x: 0, y: 110)
        sprite.zPosition = 2
        sprite.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 12, duration: 1.05),
            .moveBy(x: 0, y: -12, duration: 1.05)
        ])))
        root.addChild(sprite)
        addCardLabels(
            to: root,
            title: weapon.name,
            blurb: weapon.blurb,
            meta: weapon.slotLabel,
            price: weapon.price,
            isFree: weapon.isFree,
            accent: weapon.accent
        )
        return root
    }

    private func makeCardChrome() -> SKNode {
        let root = SKNode()
        let panel = SKSpriteNode()
        panel.size = CGSize(width: 560, height: 720)
        panel.texture = ShapeTexture.roundedRect(
            size: panel.size,
            cornerRadius: 42,
            fill: GameTheme.panel,
            stroke: SKColor(white: 1, alpha: 0.16),
            lineWidth: 2
        )
        panel.zPosition = 0
        root.addChild(panel)
        return root
    }

    private func addCardLabels(
        to root: SKNode,
        title: String,
        blurb: String,
        meta: String,
        price: Int,
        isFree: Bool,
        accent: SKColor
    ) {
        let slot = SKLabelNode(fontNamed: GameFont.resolved(size: 22))
        slot.text = meta
        slot.fontSize = 22
        slot.fontColor = accent
        slot.verticalAlignmentMode = .center
        slot.position = CGPoint(x: 0, y: -130)
        slot.zPosition = 2
        root.addChild(slot)

        let name = SKLabelNode(fontNamed: GameFont.resolved(size: 44))
        name.text = title
        name.fontSize = 44
        name.fontColor = .white
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: -178)
        name.zPosition = 2
        root.addChild(name)

        let blurbLabel = SKLabelNode(fontNamed: GameFont.resolved(size: 26))
        blurbLabel.text = blurb
        blurbLabel.fontSize = 26
        blurbLabel.fontColor = GameTheme.secondary
        blurbLabel.verticalAlignmentMode = .center
        blurbLabel.position = CGPoint(x: 0, y: -232)
        blurbLabel.zPosition = 2
        root.addChild(blurbLabel)

        let priceLabel = SKLabelNode(fontNamed: GameFont.resolved(size: 30))
        priceLabel.fontSize = 30
        priceLabel.verticalAlignmentMode = .center
        priceLabel.position = CGPoint(x: 0, y: -286)
        priceLabel.zPosition = 2
        if isFree {
            priceLabel.text = "STARTER"
            priceLabel.fontColor = GameTheme.accent
        } else {
            priceLabel.text = "\(price) CREDITS"
            priceLabel.fontColor = GameTheme.credit
        }
        root.addChild(priceLabel)
    }

    private func buildDots() {
        dots.forEach { $0.removeFromParent() }
        dots.removeAll()
        for _ in 0..<pageCount {
            let dot = SKSpriteNode()
            dot.size = CGSize(width: 18, height: 18)
            dot.zPosition = GameConstants.Z.hud
            addChild(dot)
            dots.append(dot)
        }
    }

    private func relayout() {
        relayoutProductionBackground()
        let safe = playfield.safeRect

        titleLabel.position = CGPoint(x: safe.midX, y: safe.maxY - 72)
        backButton?.position = CGPoint(x: safe.minX + 150, y: safe.maxY - 72)
        hintLabel.position = CGPoint(x: safe.midX, y: titleLabel.position.y - 52)

        hullsTab?.position = CGPoint(x: safe.midX - 150, y: hintLabel.position.y - 58)
        weaponsTab?.position = CGPoint(x: safe.midX + 150, y: hintLabel.position.y - 58)

        walletLabel.text = "CREDITS  \(PlayerProgress.credits)"
        let walletSize = CGSize(width: 360, height: 64)
        walletPanel.size = walletSize
        walletPanel.texture = ShapeTexture.roundedRect(
            size: walletSize,
            cornerRadius: 22,
            fill: GameTheme.panel,
            stroke: SKColor(white: 1, alpha: 0.16),
            lineWidth: 2
        )
        walletPanel.position = CGPoint(x: safe.midX, y: (hullsTab?.position.y ?? 0) - 70)

        cropSize = CGSize(width: min(safe.width - 40, 640), height: 700)
        let mask = SKSpriteNode(color: .white, size: cropSize)
        crop.maskNode = mask
        crop.position = CGPoint(x: safe.midX, y: safe.midY - 10)

        actionButton?.position = CGPoint(x: safe.midX, y: safe.minY + 118)
        leftButton?.position = CGPoint(x: safe.midX - cropSize.width * 0.5 + 20, y: crop.position.y)
        rightButton?.position = CGPoint(x: safe.midX + cropSize.width * 0.5 - 20, y: crop.position.y)
        statusLabel.position = CGPoint(x: safe.midX, y: safe.minY + 210)

        let dotY = safe.minY + 250
        let span = CGFloat(max(dots.count - 1, 1)) * 28
        let startX = safe.midX - span * 0.5
        for (index, dot) in dots.enumerated() {
            dot.position = CGPoint(x: startX + CGFloat(index) * 28, y: dotY)
        }
        refreshDots()
    }

    private func refreshWallet() {
        walletLabel.text = "CREDITS  \(PlayerProgress.credits)"
    }

    private func refreshAction() {
        switch shelf {
        case .hulls:
            refreshShipAction()
        case .weapons:
            refreshWeaponAction()
        }
    }

    private func refreshShipAction() {
        let ship = shipCatalog[min(max(pageIndex, 0), shipCatalog.count - 1)]
        let owned = PlayerProgress.isOwned(ship.id)
        let equipped = PlayerProgress.equippedShipId == ship.id
        if equipped {
            actionButton?.setTitle("Equipped", emphasized: false)
        } else if owned {
            actionButton?.setTitle("Equip", emphasized: true)
        } else if PlayerProgress.credits >= ship.price {
            actionButton?.setTitle("Buy  \(ship.price)", emphasized: true)
        } else {
            actionButton?.setTitle("Need  \(ship.price - PlayerProgress.credits)", emphasized: false)
        }
    }

    private func refreshWeaponAction() {
        let weapon = weaponCatalog[min(max(pageIndex, 0), weaponCatalog.count - 1)]
        let owned = PlayerProgress.isWeaponOwned(weapon.id)
        let equipped = weapon.slot == .primary
            ? PlayerProgress.equippedPrimaryWeaponId == weapon.id
            : PlayerProgress.equippedSpecialWeaponId == weapon.id
        if equipped {
            actionButton?.setTitle("Equipped", emphasized: false)
        } else if owned {
            actionButton?.setTitle("Equip", emphasized: true)
        } else if PlayerProgress.credits >= weapon.price {
            actionButton?.setTitle("Buy  \(weapon.price)", emphasized: true)
        } else {
            actionButton?.setTitle("Need  \(weapon.price - PlayerProgress.credits)", emphasized: false)
        }
    }

    private func refreshDots() {
        for (index, dot) in dots.enumerated() {
            let active = index == pageIndex
            let size = CGSize(width: active ? 22 : 16, height: active ? 22 : 16)
            dot.size = size
            dot.texture = ShapeTexture.roundedRect(
                size: size,
                cornerRadius: size.height * 0.5,
                fill: active ? GameTheme.accent : SKColor(white: 1, alpha: 0.28),
                stroke: SKColor(white: 1, alpha: active ? 0.4 : 0.12),
                lineWidth: 1
            )
        }
    }

    private func snapToPage(_ index: Int, animated: Bool) {
        pageIndex = min(max(index, 0), max(pageCount - 1, 0))
        let targetX = -CGFloat(pageIndex) * cardSpacing
        if animated {
            track.removeAction(forKey: "snap")
            track.run(.moveTo(x: targetX, duration: 0.18), withKey: "snap")
        } else {
            track.position.x = targetX
        }
        refreshAction()
        refreshDots()
    }

    private func showStatus(_ text: String, color: SKColor) {
        statusLabel.text = text
        statusLabel.fontColor = color
        statusLabel.removeAllActions()
        statusLabel.alpha = 1
        statusLabel.run(.sequence([
            .wait(forDuration: 0.9),
            .fadeOut(withDuration: 0.28)
        ]))
    }

    private func handleAction() {
        switch shelf {
        case .hulls:
            handleShipAction()
        case .weapons:
            handleWeaponAction()
        }
    }

    private func handleShipAction() {
        let ship = shipCatalog[min(max(pageIndex, 0), shipCatalog.count - 1)]
        if PlayerProgress.equippedShipId == ship.id {
            showStatus("Already equipped", color: GameTheme.secondary)
            AudioManager.play(.uiTap)
            return
        }
        if PlayerProgress.isOwned(ship.id) {
            guard PlayerProgress.equip(ship.id) == .equipped else { return }
            actionButton?.pulse()
            AudioManager.play(.uiTap)
            HapticManager.upgrade()
            refreshAction()
            showStatus("Equipped \(ship.name)", color: GameTheme.credit)
            return
        }

        switch PlayerProgress.purchase(ship.id) {
        case .purchased:
            actionButton?.pulse()
            AudioManager.play(.boost)
            HapticManager.upgrade()
            refreshWallet()
            refreshAction()
            showStatus("Purchased \(ship.name)", color: GameTheme.credit)
        case .cannotAfford(let needed):
            AudioManager.play(.uiTap)
            HapticManager.lifeLost()
            refreshAction()
            showStatus("Need \(needed) more credits", color: SKColor(red: 1, green: 0.45, blue: 0.38, alpha: 1))
        case .alreadyOwned:
            _ = PlayerProgress.equip(ship.id)
            refreshAction()
        case .unknownShip:
            break
        }
    }

    private func handleWeaponAction() {
        let weapon = weaponCatalog[min(max(pageIndex, 0), weaponCatalog.count - 1)]
        let equipped = weapon.slot == .primary
            ? PlayerProgress.equippedPrimaryWeaponId == weapon.id
            : PlayerProgress.equippedSpecialWeaponId == weapon.id
        if equipped {
            showStatus("Already equipped", color: GameTheme.secondary)
            AudioManager.play(.uiTap)
            return
        }
        if PlayerProgress.isWeaponOwned(weapon.id) {
            guard PlayerProgress.equipWeapon(weapon.id) == .equipped else { return }
            actionButton?.pulse()
            AudioManager.play(.uiTap)
            HapticManager.upgrade()
            refreshAction()
            showStatus("Equipped \(weapon.name)", color: GameTheme.credit)
            return
        }

        switch PlayerProgress.purchaseWeapon(weapon.id) {
        case .purchased:
            actionButton?.pulse()
            AudioManager.play(.boost)
            HapticManager.upgrade()
            refreshWallet()
            refreshAction()
            showStatus("Purchased \(weapon.name)", color: GameTheme.credit)
        case .cannotAfford(let needed):
            AudioManager.play(.uiTap)
            HapticManager.lifeLost()
            refreshAction()
            showStatus("Need \(needed) more credits", color: SKColor(red: 1, green: 0.45, blue: 0.38, alpha: 1))
        case .alreadyOwned:
            _ = PlayerProgress.equipWeapon(weapon.id)
            refreshAction()
        case .unknownWeapon:
            break
        }
    }

    private func cropFrame() -> CGRect {
        CGRect(
            x: crop.position.x - cropSize.width * 0.5,
            y: crop.position.y - cropSize.height * 0.5,
            width: cropSize.width,
            height: cropSize.height
        )
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if let backButton, backButton.containsTouch(point) {
            backButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            presentScene(GameTitleScene(size: size))
            return
        }
        if let hullsTab, hullsTab.containsTouch(point), shelf != .hulls {
            hullsTab.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            shelf = .hulls
            rebuildShelf(animated: false)
            relayout()
            return
        }
        if let weaponsTab, weaponsTab.containsTouch(point), shelf != .weapons {
            weaponsTab.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            shelf = .weapons
            rebuildShelf(animated: false)
            relayout()
            return
        }
        if let actionButton, actionButton.containsTouch(point) {
            handleAction()
            return
        }
        if let leftButton, leftButton.containsTouch(point) {
            leftButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            snapToPage(pageIndex - 1, animated: true)
            return
        }
        if let rightButton, rightButton.containsTouch(point) {
            rightButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            snapToPage(pageIndex + 1, animated: true)
            return
        }
        if cropFrame().contains(point) {
            isDragging = true
            dragStartX = point.x
            trackStartX = track.position.x
            track.removeAction(forKey: "snap")
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDragging, let touch = touches.first, let dragStartX else { return }
        let dx = touch.location(in: self).x - dragStartX
        let minX = -CGFloat(max(pageCount - 1, 0)) * cardSpacing
        track.position.x = min(0, max(minX, trackStartX + dx))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishDrag()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishDrag()
    }

    private func finishDrag() {
        guard isDragging else { return }
        isDragging = false
        dragStartX = nil
        let raw = Int(round(-track.position.x / cardSpacing))
        snapToPage(raw, animated: true)
    }
}
