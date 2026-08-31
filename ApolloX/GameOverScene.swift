//
//  GameOverScene.swift
//  ApolloX
//

import SpriteKit
import UIKit

final class GameOverScene: SKScene {

    private let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.45), size: .zero)
    private let card = SKSpriteNode()
    private let titleLabel = SKLabelNode()
    private let newBestBanner = SKLabelNode()
    private let scoreLabel = SKLabelNode()
    private let earnedLabel = SKLabelNode()
    private let walletLabel = SKLabelNode()
    private let bestLabel = SKLabelNode()
    private let rankDeltaLabel = SKLabelNode()
    private let ranksHintLabel = SKLabelNode()
    private var restartButton: MenuButtonNode?
    private var ranksButton: MenuButtonNode?
    private var menuButton: MenuButtonNode?

    override func didMove(to view: SKView) {
        addProductionBackground()

        let finalScore = ScoreStore.currentScore
        let best = ScoreStore.commitHighScoreIfNeeded()
        let wallet = ScoreStore.commitWalletIfNeeded()
        let isNewBest = ScoreStore.lastCommitWasNewBest
        GameCenterAchievementService.checkWallet(wallet)

        dim.zPosition = GameConstants.Z.hud - 2
        addChild(dim)

        card.color = GameTheme.panel
        card.zPosition = GameConstants.Z.hud - 1
        addChild(card)

        titleLabel.fontName = GameFont.resolved(size: 86)
        titleLabel.text = "Game Over"
        titleLabel.fontSize = 86
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = GameConstants.Z.hud
        addChild(titleLabel)

        newBestBanner.fontName = GameFont.resolved(size: 44)
        newBestBanner.text = "★  NEW BEST  ★"
        newBestBanner.fontSize = 44
        newBestBanner.fontColor = GameTheme.accent
        newBestBanner.verticalAlignmentMode = .center
        newBestBanner.zPosition = GameConstants.Z.hud
        newBestBanner.isHidden = !isNewBest
        addChild(newBestBanner)

        scoreLabel.fontName = GameFont.resolved(size: 54)
        scoreLabel.text = "SCORE  \(finalScore)"
        scoreLabel.fontSize = 54
        scoreLabel.fontColor = .white
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.zPosition = GameConstants.Z.hud
        addChild(scoreLabel)

        earnedLabel.fontName = GameFont.resolved(size: 40)
        earnedLabel.text = "+\(finalScore) CREDITS"
        earnedLabel.fontSize = 40
        earnedLabel.fontColor = GameTheme.credit
        earnedLabel.verticalAlignmentMode = .center
        earnedLabel.zPosition = GameConstants.Z.hud
        addChild(earnedLabel)

        walletLabel.fontName = GameFont.resolved(size: 36)
        walletLabel.text = "WALLET  \(wallet)"
        walletLabel.fontSize = 36
        walletLabel.fontColor = GameTheme.secondary
        walletLabel.verticalAlignmentMode = .center
        walletLabel.zPosition = GameConstants.Z.hud
        addChild(walletLabel)

        bestLabel.fontName = GameFont.resolved(size: 44)
        if isNewBest, ScoreStore.lastCommitPreviousBest > 0 {
            bestLabel.text = "BEST  \(ScoreStore.lastCommitPreviousBest) → \(best)"
        } else {
            bestLabel.text = "BEST  \(best)"
        }
        bestLabel.fontSize = 44
        bestLabel.fontColor = isNewBest ? GameTheme.accent : GameTheme.secondary
        bestLabel.verticalAlignmentMode = .center
        bestLabel.zPosition = GameConstants.Z.hud
        addChild(bestLabel)

        rankDeltaLabel.fontName = GameFont.resolved(size: 28)
        rankDeltaLabel.fontSize = 28
        rankDeltaLabel.fontColor = SKColor(white: 0.78, alpha: 1)
        rankDeltaLabel.verticalAlignmentMode = .center
        rankDeltaLabel.zPosition = GameConstants.Z.hud
        rankDeltaLabel.text = "Checking rank…"
        addChild(rankDeltaLabel)

        ranksHintLabel.fontName = GameFont.resolved(size: 26)
        ranksHintLabel.text = GameCenterService.isAuthenticated
            ? "Best score sent to Game Center"
            : "Sign in to Game Center to join global ranks"
        ranksHintLabel.fontSize = 26
        ranksHintLabel.fontColor = SKColor(white: 0.72, alpha: 1)
        ranksHintLabel.verticalAlignmentMode = .center
        ranksHintLabel.zPosition = GameConstants.Z.hud
        addChild(ranksHintLabel)

        let restart = MenuButtonNode(title: "Restart", width: 480, height: 104, fontSize: 48, emphasized: true)
        let ranks = MenuButtonNode(title: "Ranks", width: 360, height: 88, fontSize: 40, emphasized: false)
        let menu = MenuButtonNode(title: "Menu", width: 360, height: 88, fontSize: 40, emphasized: false)
        restartButton = restart
        ranksButton = ranks
        menuButton = menu
        addChild(restart)
        addChild(ranks)
        addChild(menu)

        // Entrance
        card.alpha = 0
        titleLabel.alpha = 0
        newBestBanner.alpha = 0
        scoreLabel.alpha = 0
        earnedLabel.alpha = 0
        walletLabel.alpha = 0
        bestLabel.alpha = 0
        rankDeltaLabel.alpha = 0
        ranksHintLabel.alpha = 0
        restart.alpha = 0
        ranks.alpha = 0
        menu.alpha = 0
        card.run(.fadeIn(withDuration: 0.3))
        titleLabel.run(.sequence([.wait(forDuration: 0.05), .fadeIn(withDuration: 0.3)]))
        if isNewBest {
            newBestBanner.run(.sequence([
                .wait(forDuration: 0.08),
                .fadeIn(withDuration: 0.25),
                .repeatForever(.sequence([
                    .scale(to: 1.06, duration: 0.45),
                    .scale(to: 1.0, duration: 0.45)
                ]))
            ]))
        }
        scoreLabel.run(.sequence([.wait(forDuration: 0.1), .fadeIn(withDuration: 0.3)]))
        earnedLabel.run(.sequence([.wait(forDuration: 0.12), .fadeIn(withDuration: 0.3)]))
        walletLabel.run(.sequence([.wait(forDuration: 0.14), .fadeIn(withDuration: 0.3)]))
        bestLabel.run(.sequence([.wait(forDuration: 0.16), .fadeIn(withDuration: 0.3)]))
        rankDeltaLabel.run(.sequence([.wait(forDuration: 0.18), .fadeIn(withDuration: 0.3)]))
        ranksHintLabel.run(.sequence([.wait(forDuration: 0.2), .fadeIn(withDuration: 0.3)]))
        restart.run(.sequence([.wait(forDuration: 0.22), .fadeIn(withDuration: 0.3)]))
        ranks.run(.sequence([.wait(forDuration: 0.26), .fadeIn(withDuration: 0.3)]))
        menu.run(.sequence([.wait(forDuration: 0.30), .fadeIn(withDuration: 0.3)]))

        whenSafeAreaReady { [weak self] in
            self?.relayout()
        }
        refreshRankDelta()
    }

    private func refreshRankDelta() {
        guard GameCenterService.isAuthenticated else {
            rankDeltaLabel.text = ""
            rankDeltaLabel.alpha = 0
            relayout()
            return
        }

        let previousRank = AppSettings.lastKnownGameCenterRank
        GameCenterService.loadLocalPlayerRank { [weak self] newRank in
            guard let self else { return }
            if let newRank, let previousRank, previousRank != newRank {
                if newRank < previousRank {
                    self.rankDeltaLabel.text = "RANK  #\(previousRank) → #\(newRank)  ▲"
                    self.rankDeltaLabel.fontColor = GameTheme.credit
                } else {
                    self.rankDeltaLabel.text = "RANK  #\(newRank)"
                    self.rankDeltaLabel.fontColor = SKColor(white: 0.78, alpha: 1)
                }
            } else if let newRank {
                self.rankDeltaLabel.text = "RANK  #\(newRank)"
                self.rankDeltaLabel.fontColor = GameTheme.accent
            } else {
                self.rankDeltaLabel.text = "RANK  —"
                self.rankDeltaLabel.fontColor = SKColor(white: 0.65, alpha: 1)
            }
            self.relayout()
        }
    }

    private func relayout() {
        let safe = playfield.safeRect
        dim.size = playfield.visibleRect.size
        dim.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)

        let cardWidth = min(safe.width, 980)
        let cardHeight: CGFloat = newBestBanner.isHidden ? 980 : 1040
        card.size = CGSize(width: cardWidth, height: cardHeight)
        card.texture = ShapeTexture.roundedRect(
            size: card.size,
            cornerRadius: 42,
            fill: GameTheme.panel,
            stroke: SKColor(white: 1, alpha: 0.14),
            lineWidth: 2
        )
        card.position = CGPoint(x: safe.midX, y: safe.midY + 10)

        var y = card.position.y + 360
        titleLabel.position = CGPoint(x: safe.midX, y: y)
        if !newBestBanner.isHidden {
            y -= 72
            newBestBanner.position = CGPoint(x: safe.midX, y: y)
        }
        scoreLabel.position = CGPoint(x: safe.midX, y: card.position.y + 220)
        earnedLabel.position = CGPoint(x: safe.midX, y: card.position.y + 152)
        walletLabel.position = CGPoint(x: safe.midX, y: card.position.y + 98)
        bestLabel.position = CGPoint(x: safe.midX, y: card.position.y + 38)
        rankDeltaLabel.position = CGPoint(x: safe.midX, y: card.position.y - 18)
        ranksHintLabel.position = CGPoint(x: safe.midX, y: card.position.y - 62)
        restartButton?.position = CGPoint(x: safe.midX, y: card.position.y - 168)
        ranksButton?.position = CGPoint(x: safe.midX, y: card.position.y - 286)
        menuButton?.position = CGPoint(x: safe.midX, y: card.position.y - 398)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        relayout()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if let restartButton, restartButton.containsTouch(point) {
            restartButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            presentScene(GameScene(size: size))
            return
        }

        if let ranksButton, ranksButton.containsTouch(point) {
            ranksButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            presentScene(LeaderboardScene(size: size))
            return
        }

        if let menuButton, menuButton.containsTouch(point) {
            menuButton.pulse()
            AudioManager.play(.uiTap)
            HapticManager.fire()
            presentScene(GameTitleScene(size: size))
        }
    }
}
