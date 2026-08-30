//
//  LeaderboardScene.swift
//  ApolloX
//
//  In-game Top 5 from Game Center. Falls back to clear guidance when the player
//  is signed out or the board is empty / unreachable.
//

import SpriteKit
import UIKit

final class LeaderboardScene: SKScene {

    private let titleLabel = SKLabelNode()
    private let subtitleLabel = SKLabelNode()
    private let statusLabel = SKLabelNode()
    private let listRoot = SKNode()
    private var backButton: MenuButtonNode?
    private var gameCenterButton: MenuButtonNode?
    private var retryButton: MenuButtonNode?
    private var rowNodes: [SKNode] = []
    private var lastBackgroundTick: TimeInterval = 0
    private var isLoading = false

    override func didMove(to view: SKView) {
        view.accessibilityIdentifier = GameConstants.Accessibility.leaderboardScene
        view.accessibilityLabel = "Ranks"
        HapticManager.prepare()
        addProductionBackground()

        titleLabel.fontName = GameFont.resolved(size: 72)
        titleLabel.text = "Ranks"
        titleLabel.fontSize = 72
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = GameConstants.Z.hud
        titleLabel.isAccessibilityElement = true
        titleLabel.accessibilityLabel = "Ranks"
        addChild(titleLabel)

        subtitleLabel.fontName = GameFont.resolved(size: 28)
        subtitleLabel.text = "\(GameCenterService.classicHighScoreDisplayName)  •  Top \(GameCenterService.topEntryCount)"
        subtitleLabel.fontSize = 28
        subtitleLabel.fontColor = GameTheme.secondary
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.zPosition = GameConstants.Z.hud
        addChild(subtitleLabel)

        statusLabel.fontName = GameFont.resolved(size: 30)
        statusLabel.fontSize = 30
        statusLabel.fontColor = SKColor(white: 0.78, alpha: 1)
        statusLabel.verticalAlignmentMode = .center
        statusLabel.horizontalAlignmentMode = .center
        statusLabel.zPosition = GameConstants.Z.hud
        statusLabel.numberOfLines = 3
        statusLabel.preferredMaxLayoutWidth = 900
        addChild(statusLabel)

        listRoot.zPosition = GameConstants.Z.hud
        addChild(listRoot)

        let back = MenuButtonNode(title: "Back", width: 240, height: 88, fontSize: 40, emphasized: false)
        backButton = back
        addChild(back)

        let gc = MenuButtonNode(title: "Game Center", width: 360, height: 88, fontSize: 36, emphasized: false)
        gameCenterButton = gc
        addChild(gc)

        let retry = MenuButtonNode(title: "Retry", width: 240, height: 88, fontSize: 40, emphasized: true)
        retryButton = retry
        retry.isHidden = true
        addChild(retry)

        titleLabel.alpha = 0
        subtitleLabel.alpha = 0
        statusLabel.alpha = 0
        back.alpha = 0
        gc.alpha = 0
        titleLabel.run(.fadeIn(withDuration: 0.35))
        subtitleLabel.run(.sequence([.wait(forDuration: 0.06), .fadeIn(withDuration: 0.35)]))
        statusLabel.run(.sequence([.wait(forDuration: 0.1), .fadeIn(withDuration: 0.35)]))
        back.run(.sequence([.wait(forDuration: 0.14), .fadeIn(withDuration: 0.35)]))
        gc.run(.sequence([.wait(forDuration: 0.18), .fadeIn(withDuration: 0.35)]))

        whenSafeAreaReady { [weak self] in
            self?.relayout()
        }
        reloadEntries()
    }

    override func update(_ currentTime: TimeInterval) {
        if lastBackgroundTick > 0 {
            scrollingBackgroundNode()?.tick(deltaTime: currentTime - lastBackgroundTick)
        }
        lastBackgroundTick = currentTime
    }

    override func didChangeSize(_ oldSize: CGSize) {
        relayoutProductionBackground()
        relayout()
    }

    private func relayout() {
        relayoutProductionBackground()
        let safe = playfield.safeRect

        titleLabel.position = CGPoint(x: safe.midX, y: safe.maxY - 120)
        subtitleLabel.position = CGPoint(x: safe.midX, y: titleLabel.position.y - 70)
        statusLabel.position = CGPoint(x: safe.midX, y: safe.midY + 40)
        statusLabel.preferredMaxLayoutWidth = min(safe.width - 80, 980)

        listRoot.position = CGPoint(x: safe.midX, y: safe.midY + 180)
        layoutRows(in: safe)

        backButton?.position = CGPoint(x: safe.midX - 200, y: safe.minY + 88)
        gameCenterButton?.position = CGPoint(x: safe.midX + 140, y: safe.minY + 88)
        retryButton?.position = CGPoint(x: safe.midX, y: safe.minY + 200)
    }

    private func layoutRows(in safe: CGRect) {
        let rowWidth = min(safe.width - 64, 980)
        let rowHeight: CGFloat = 96
        let spacing: CGFloat = 18
        let totalHeight = CGFloat(rowNodes.count) * rowHeight
            + CGFloat(max(0, rowNodes.count - 1)) * spacing
        var y = totalHeight * 0.5 - rowHeight * 0.5
        for row in rowNodes {
            if let panel = row as? SKSpriteNode {
                panel.size = CGSize(width: rowWidth, height: rowHeight)
                panel.texture = ShapeTexture.roundedRect(
                    size: panel.size,
                    cornerRadius: 28,
                    fill: GameTheme.panel,
                    stroke: SKColor(white: 1, alpha: 0.14),
                    lineWidth: 2
                )
            }
            row.position = CGPoint(x: 0, y: y)
            if let rank = row.childNode(withName: "rank") as? SKLabelNode {
                rank.position = CGPoint(x: -rowWidth * 0.5 + 56, y: 0)
            }
            if let name = row.childNode(withName: "name") as? SKLabelNode {
                name.position = CGPoint(x: -rowWidth * 0.5 + 130, y: 0)
                name.preferredMaxLayoutWidth = rowWidth * 0.48
            }
            if let score = row.childNode(withName: "score") as? SKLabelNode {
                score.position = CGPoint(x: rowWidth * 0.5 - 48, y: 0)
            }
            y -= rowHeight + spacing
        }
    }

    private func reloadEntries() {
        guard !isLoading else { return }
        isLoading = true
        clearRows()
        retryButton?.isHidden = true
        statusLabel.alpha = 1
        statusLabel.text = "Loading top \(GameCenterService.topEntryCount)…"
        statusLabel.fontColor = SKColor(white: 0.78, alpha: 1)
        GameCenterService.authenticateAtLaunch()

        GameCenterService.loadTopEntries { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            switch result {
            case .success(let entries):
                if entries.isEmpty {
                    self.statusLabel.text = "No scores yet — be the first on the board.\nIf Game Center shows Pre-release, submit the leaderboard with this app version."
                    self.statusLabel.fontColor = GameTheme.accent
                } else {
                    self.statusLabel.alpha = 0
                    self.show(entries: entries)
                }
            case .failure(let error):
                self.statusLabel.alpha = 1
                self.statusLabel.fontColor = GameTheme.accent
                if let gcError = error as? GameCenterError, gcError == .notAuthenticated {
                    self.statusLabel.text = "Sign in to Game Center to see global ranks.\nYour local best still saves on this device."
                } else {
                    self.statusLabel.text = error.localizedDescription
                }
                self.retryButton?.isHidden = false
                self.retryButton?.alpha = 1
            }
            self.relayout()
        }
    }

    private func show(entries: [LeaderboardEntry]) {
        clearRows()
        for entry in entries.prefix(GameCenterService.topEntryCount) {
            let row = makeRow(entry: entry)
            rowNodes.append(row)
            listRoot.addChild(row)
            row.alpha = 0
            row.run(.fadeIn(withDuration: 0.28))
        }
        relayout()
    }

    private func makeRow(entry: LeaderboardEntry) -> SKSpriteNode {
        let panel = SKSpriteNode(color: GameTheme.panel, size: CGSize(width: 900, height: 96))
        panel.zPosition = 0

        let rank = SKLabelNode(fontNamed: GameFont.resolved(size: 36))
        rank.name = "rank"
        rank.text = "#\(entry.rank)"
        rank.fontSize = 36
        rank.fontColor = entry.rank <= 3 ? GameTheme.accent : GameTheme.secondary
        rank.verticalAlignmentMode = .center
        rank.horizontalAlignmentMode = .left
        rank.zPosition = 1
        panel.addChild(rank)

        let name = SKLabelNode(fontNamed: GameFont.resolved(size: 34))
        name.name = "name"
        name.text = entry.displayName
        name.fontSize = 34
        name.fontColor = entry.isLocalPlayer ? GameTheme.credit : .white
        name.verticalAlignmentMode = .center
        name.horizontalAlignmentMode = .left
        name.zPosition = 1
        panel.addChild(name)

        let score = SKLabelNode(fontNamed: GameFont.resolved(size: 36))
        score.name = "score"
        score.text = "\(entry.score)"
        score.fontSize = 36
        score.fontColor = .white
        score.verticalAlignmentMode = .center
        score.horizontalAlignmentMode = .right
        score.zPosition = 1
        panel.addChild(score)

        panel.isAccessibilityElement = true
        panel.accessibilityLabel = "Rank \(entry.rank), \(entry.displayName), score \(entry.score)"
        return panel
    }

    private func clearRows() {
        rowNodes.forEach { $0.removeFromParent() }
        rowNodes.removeAll()
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

        if let gameCenterButton, gameCenterButton.containsTouch(point) {
            gameCenterButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            GameCenterService.authenticateAtLaunch()
            if GameCenterService.isAuthenticated {
                GameCenterService.presentSystemLeaderboard()
            } else {
                statusLabel.alpha = 1
                statusLabel.fontColor = GameTheme.accent
                statusLabel.text = "Sign in to Game Center to open the full board."
                retryButton?.isHidden = false
            }
            return
        }

        if let retryButton, !retryButton.isHidden, retryButton.containsTouch(point) {
            retryButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            reloadEntries()
        }
    }
}
