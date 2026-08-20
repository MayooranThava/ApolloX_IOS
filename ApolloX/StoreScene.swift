//
//  StoreScene.swift
//  ApolloX
//
//  Hangar: swipe horizontally through rockets, buy with run credits, then equip.
//

import SpriteKit
import UIKit

final class StoreScene: SKScene {

    private let catalog = PlayerShipCatalog.all
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
    private var dots: [SKSpriteNode] = []

    private var pageIndex = 0
    private var dragStartX: CGFloat?
    private var trackStartX: CGFloat = 0
    private var isDragging = false
    private var lastBackgroundTick: TimeInterval = 0

    override func didMove(to view: SKView) {
        view.accessibilityIdentifier = GameConstants.Accessibility.storeScene
        view.accessibilityLabel = "Hangar"
        HapticManager.prepare()
        PlayerShipCatalog.registerTextures()
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
        hintLabel.text = "Swipe to browse  •  Buy  •  Equip"
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
        buildCards()

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

        buildDots()
        pageIndex = catalog.firstIndex(where: { $0.id == PlayerProgress.equippedShipId }) ?? 0
        refreshWallet()
        refreshAction()
        refreshDots()

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

    private func buildCards() {
        track.removeAllChildren()

        for (index, ship) in catalog.enumerated() {
            let card = makeCard(for: ship)
            card.position = CGPoint(x: CGFloat(index) * cardSpacing, y: 0)
            track.addChild(card)
        }
    }

    private func makeCard(for ship: PlayerShip) -> SKNode {
        let root = SKNode()
        root.name = ship.id

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

        let name = SKLabelNode(fontNamed: GameFont.resolved(size: 44))
        name.text = ship.name
        name.fontSize = 44
        name.fontColor = .white
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: -170)
        name.zPosition = 2
        root.addChild(name)

        let blurb = SKLabelNode(fontNamed: GameFont.resolved(size: 26))
        blurb.text = ship.blurb
        blurb.fontSize = 26
        blurb.fontColor = GameTheme.secondary
        blurb.verticalAlignmentMode = .center
        blurb.position = CGPoint(x: 0, y: -230)
        blurb.zPosition = 2
        root.addChild(blurb)

        let price = SKLabelNode(fontNamed: GameFont.resolved(size: 30))
        price.fontSize = 30
        price.verticalAlignmentMode = .center
        price.position = CGPoint(x: 0, y: -286)
        price.zPosition = 2
        if ship.isFree {
            price.text = "STARTER"
            price.fontColor = GameTheme.accent
        } else {
            price.text = "\(ship.price) CREDITS"
            price.fontColor = GameTheme.credit
        }
        root.addChild(price)

        return root
    }

    private func buildDots() {
        dots.forEach { $0.removeFromParent() }
        dots.removeAll()
        for _ in catalog {
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

        titleLabel.position = CGPoint(x: safe.midX, y: safe.maxY - 88)
        hintLabel.position = CGPoint(x: safe.midX, y: titleLabel.position.y - 62)

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
        walletPanel.position = CGPoint(x: safe.midX, y: hintLabel.position.y - 70)

        cropSize = CGSize(width: min(safe.width - 40, 640), height: 760)
        let mask = SKSpriteNode(color: .white, size: cropSize)
        crop.maskNode = mask
        crop.position = CGPoint(x: safe.midX, y: safe.midY + 10)

        backButton?.position = CGPoint(x: safe.minX + 150, y: safe.maxY - 88)
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

    private func currentShip() -> PlayerShip {
        catalog[min(max(pageIndex, 0), catalog.count - 1)]
    }

    private func refreshWallet() {
        walletLabel.text = "CREDITS  \(PlayerProgress.credits)"
    }

    private func refreshAction() {
        let ship = currentShip()
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
        pageIndex = min(max(index, 0), catalog.count - 1)
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
        let ship = currentShip()
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
            walletLabel.run(.sequence([
                .scale(to: 1.12, duration: 0.1),
                .scale(to: 1.0, duration: 0.12)
            ]))
        case .cannotAfford(let needed):
            AudioManager.play(.uiTap)
            HapticManager.lifeLost()
            refreshAction()
            showStatus("Need \(needed) more credits", color: SKColor(red: 1, green: 0.45, blue: 0.38, alpha: 1))
            walletPanel.run(.sequence([
                .moveBy(x: -10, y: 0, duration: 0.04),
                .moveBy(x: 20, y: 0, duration: 0.06),
                .moveBy(x: -10, y: 0, duration: 0.04)
            ]))
        case .alreadyOwned:
            _ = PlayerProgress.equip(ship.id)
            refreshAction()
        case .unknownShip:
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
        let minX = -CGFloat(catalog.count - 1) * cardSpacing
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
