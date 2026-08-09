//
//  GameScene.swift
//  ApolloX
//

import SpriteKit
import UIKit

final class GameScene: SKScene, SKPhysicsContactDelegate {

    private enum State {
        case playing
        case gameOver
    }

    private let scoreLabel = SKLabelNode()
    private let livesLabel = SKLabelNode()
    private let powerLabel = SKLabelNode()
    private let player = SKSpriteNode(imageNamed: "playerShip")

    private var lives = GameConstants.startingLives
    private var level = 0
    private var starCharge = 0
    private var poweredShotsRemaining = 0
    private var fireDelay = GameConstants.baseFireDelay
    private var bulletImageName = GameConstants.bulletImage
    private var currentState: State = .playing
    private var gameArea = CGRect.zero
    private var isPausedBySystem = false

    private let laserSound = SKAction.playSoundFileNamed("laserSound.mp3", waitForCompletion: false)
    private let explosionSound = SKAction.playSoundFileNamed("explosionShort.wav", waitForCompletion: false)

    override init(size: CGSize) {
        super.init(size: size)
        recalculateGameArea()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didMove(to view: SKView) {
        ScoreStore.resetCurrentScore()
        HapticManager.prepare()
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = .zero

        addScrollingBackground()
        configureHUD()
        configurePlayer()
        beginLevel()
        startSpawning()
        registerLifecycleObservers()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        recalculateGameArea()
    }

    // MARK: - Setup

    private func recalculateGameArea() {
        // Side margins keep the ship fully visible under aspectFill on modern Pro displays.
        let margin = size.width * 0.05
        gameArea = CGRect(x: margin, y: 0, width: size.width - margin * 2, height: size.height)
    }

    private func configureHUD() {
        let insets = safeAreaInsetsInScene
        let topY = size.height - max(insets.top, 40) - 70

        configure(label: scoreLabel, text: "Score: 0", size: 64, alignment: .left)
        scoreLabel.position = CGPoint(x: gameArea.minX + 36, y: topY)

        configure(label: livesLabel, text: "Lives: \(lives)", size: 64, alignment: .right)
        livesLabel.position = CGPoint(x: gameArea.maxX - 36, y: topY)

        configure(label: powerLabel, text: "Fire: Normal", size: 42, alignment: .center)
        powerLabel.fontColor = SKColor(red: 1, green: 0.85, blue: 0.35, alpha: 1)
        powerLabel.position = CGPoint(x: size.width / 2, y: topY - 70)

        addChild(scoreLabel)
        addChild(livesLabel)
        addChild(powerLabel)
    }

    private func configure(label: SKLabelNode, text: String, size fontSize: CGFloat, alignment: SKLabelHorizontalAlignmentMode) {
        label.fontName = UIFont(name: GameConstants.fontName, size: fontSize) != nil
            ? GameConstants.fontName
            : GameConstants.fallbackFontName
        label.text = text
        label.fontSize = fontSize
        label.fontColor = .white
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        label.zPosition = GameConstants.Z.hud
    }

    private func configurePlayer() {
        let insets = safeAreaInsetsInScene
        player.setScale(1)
        player.position = CGPoint(
            x: size.width / 2,
            y: max(insets.bottom, 24) + player.size.height * 0.9 + size.height * 0.08
        )
        player.zPosition = GameConstants.Z.player
        player.physicsBody = SKPhysicsBody(circleOfRadius: min(player.size.width, player.size.height) * 0.35)
        player.physicsBody?.isDynamic = true
        player.physicsBody?.affectedByGravity = false
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.player
        player.physicsBody?.collisionBitMask = GameConstants.PhysicsCategory.none
        player.physicsBody?.contactTestBitMask = GameConstants.PhysicsCategory.enemy
        addChild(player)
    }

    private func registerLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appWillResignActive() {
        isPausedBySystem = true
        isPaused = true
        view?.isPaused = true
    }

    @objc private func appDidBecomeActive() {
        guard currentState == .playing else { return }
        isPausedBySystem = false
        isPaused = false
        view?.isPaused = false
    }

    // MARK: - Game flow

    private func beginLevel() {
        level += 1
    }

    private func currentSpawnInterval() -> TimeInterval {
        GameConstants.levelSpawnInterval(for: level)
    }

    private func startSpawning() {
        removeAction(forKey: "spawningEnemies")
        removeAction(forKey: "spawningPowerUp")
        restartFiring()

        let spawnEnemyAction = SKAction.run { [weak self] in self?.spawnEnemy() }
        let spawnPowerAction = SKAction.run { [weak self] in self?.spawnPowerUp() }

        let enemySequence = SKAction.sequence([
            .wait(forDuration: currentSpawnInterval()),
            spawnEnemyAction
        ])
        let powerSequence = SKAction.sequence([
            .wait(forDuration: GameConstants.powerUpSpawnInterval),
            spawnPowerAction
        ])

        run(.repeatForever(enemySequence), withKey: "spawningEnemies")
        run(.repeatForever(powerSequence), withKey: "spawningPowerUp")
    }

    private func restartFiring() {
        removeAction(forKey: "fireBullets")
        let fireAction = SKAction.run { [weak self] in self?.fireBullet() }
        let fireSequence = SKAction.sequence([
            .wait(forDuration: fireDelay),
            fireAction
        ])
        run(.repeatForever(fireSequence), withKey: "fireBullets")
    }

    private func refreshFireRate() {
        restartFiring()
        let speedText = poweredShotsRemaining > 0 ? "Fire: BOOST" : "Fire: Normal"
        powerLabel.text = speedText
        powerLabel.run(.sequence([
            .scale(to: 1.25, duration: 0.12),
            .scale(to: 1.0, duration: 0.12)
        ]))
    }

    private func addScore() {
        let score = ScoreStore.addPoint()
        scoreLabel.text = "Score: \(score)"

        if score == 10 || score == 25 || score == 50 || score == 80 {
            beginLevel()
            startSpawning()
        }
    }

    private func lostALife() {
        guard currentState == .playing else { return }

        lives -= 1
        livesLabel.text = "Lives: \(lives)"
        livesLabel.run(.sequence([
            .scale(to: 1.35, duration: 0.12),
            .scale(to: 1.0, duration: 0.12)
        ]))
        HapticManager.lifeLost()

        if lives <= 0 {
            runGameOver()
        }
    }

    private func runGameOver() {
        guard currentState == .playing else { return }
        currentState = .gameOver
        HapticManager.gameOver()

        removeAllActions()
        enumerateChildNodes(withName: GameConstants.NodeName.bullet) { node, _ in
            node.removeAllActions()
        }
        enumerateChildNodes(withName: GameConstants.NodeName.enemy) { node, _ in
            node.removeAllActions()
        }
        enumerateChildNodes(withName: GameConstants.NodeName.powerUp) { node, _ in
            node.removeAllActions()
        }

        ScoreStore.commitHighScoreIfNeeded()

        run(.sequence([
            .wait(forDuration: 0.9),
            .run { [weak self] in
                guard let self else { return }
                self.presentScene(GameOverScene(size: self.size))
            }
        ]))
    }

    // MARK: - Spawning

    private func fireBullet() {
        guard currentState == .playing, player.parent != nil else { return }

        if poweredShotsRemaining > 0 {
            poweredShotsRemaining -= 1
            if poweredShotsRemaining == 0 {
                bulletImageName = GameConstants.bulletImage
                fireDelay = GameConstants.baseFireDelay
                refreshFireRate()
            }
        }

        let bullet = SKSpriteNode(imageNamed: bulletImageName)
        bullet.name = GameConstants.NodeName.bullet
        bullet.position = CGPoint(x: player.position.x, y: player.position.y + player.size.height * 0.35)
        bullet.zPosition = GameConstants.Z.bullet
        bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
        bullet.physicsBody?.affectedByGravity = false
        bullet.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.bullet
        bullet.physicsBody?.collisionBitMask = GameConstants.PhysicsCategory.none
        bullet.physicsBody?.contactTestBitMask =
            GameConstants.PhysicsCategory.enemy | GameConstants.PhysicsCategory.powerUp
        addChild(bullet)

        run(laserSound)
        HapticManager.fire()

        let move = SKAction.moveTo(y: size.height + bullet.size.height, duration: 0.85)
        bullet.run(.sequence([move, .removeFromParent()]))
    }

    private func spawnPowerUp() {
        guard currentState == .playing else { return }

        let startX = CGFloat.random(in: gameArea.minX + 40...gameArea.maxX - 40)
        let endX = CGFloat.random(in: gameArea.minX + 40...gameArea.maxX - 40)
        let start = CGPoint(x: startX, y: size.height * 1.15)
        let end = CGPoint(x: endX, y: -size.height * 0.1)

        let powerUp = SKSpriteNode(imageNamed: GameConstants.starImage)
        powerUp.name = GameConstants.NodeName.powerUp
        powerUp.setScale(0.14)
        powerUp.position = start
        powerUp.zPosition = GameConstants.Z.powerUp
        powerUp.physicsBody = SKPhysicsBody(circleOfRadius: powerUp.size.width * 0.35)
        powerUp.physicsBody?.affectedByGravity = false
        powerUp.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.powerUp
        powerUp.physicsBody?.collisionBitMask = GameConstants.PhysicsCategory.none
        powerUp.physicsBody?.contactTestBitMask = GameConstants.PhysicsCategory.bullet
        addChild(powerUp)

        powerUp.run(.sequence([
            .move(to: end, duration: GameConstants.powerUpTravelDuration),
            .removeFromParent()
        ]))
    }

    private func spawnEnemy() {
        guard currentState == .playing else { return }

        let inset: CGFloat = 60
        let startX = CGFloat.random(in: gameArea.minX + inset...gameArea.maxX - inset)
        let endX = CGFloat.random(in: gameArea.minX + inset...gameArea.maxX - inset)
        let start = CGPoint(x: startX, y: size.height * 1.15)
        let end = CGPoint(x: endX, y: -size.height * 0.15)

        let enemy = SKSpriteNode(imageNamed: "enemyShip")
        enemy.name = GameConstants.NodeName.enemy
        enemy.position = start
        enemy.zPosition = GameConstants.Z.enemy
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: min(enemy.size.width, enemy.size.height) * 0.38)
        enemy.physicsBody?.affectedByGravity = false
        enemy.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.enemy
        enemy.physicsBody?.collisionBitMask = GameConstants.PhysicsCategory.none
        enemy.physicsBody?.contactTestBitMask =
            GameConstants.PhysicsCategory.player | GameConstants.PhysicsCategory.bullet
        addChild(enemy)

        let dx = end.x - start.x
        let dy = end.y - start.y
        enemy.zRotation = atan2(dy, dx)

        let move = SKAction.move(to: end, duration: GameConstants.enemyTravelDuration)
        let escape = SKAction.run { [weak self] in self?.lostALife() }
        enemy.run(.sequence([move, escape, .removeFromParent()]))
    }

    private func spawnExplosion(at position: CGPoint, image: String, scale: CGFloat = 1) {
        let explosion = SKSpriteNode(imageNamed: image)
        explosion.position = position
        explosion.zPosition = GameConstants.Z.effect
        explosion.setScale(0)
        addChild(explosion)
        run(explosionSound)

        explosion.run(.sequence([
            .group([
                .scale(to: scale, duration: 0.18),
                .fadeOut(withDuration: 0.28)
            ]),
            .removeFromParent()
        ]))
    }

    private func collectStar(at position: CGPoint) {
        starCharge += 1
        HapticManager.starHit()
        spawnExplosion(at: position, image: "mini_explosion", scale: 0.8)
        powerLabel.text = "Stars: \(starCharge)/\(GameConstants.starsNeededForUpgrade)"

        if starCharge >= GameConstants.starsNeededForUpgrade {
            starCharge = 0
            bulletImageName = GameConstants.poweredBulletImage
            fireDelay = GameConstants.poweredFireDelay
            poweredShotsRemaining = GameConstants.poweredShotCount
            HapticManager.upgrade()
            refreshFireRate()
        }
    }

    // MARK: - Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        guard currentState == .playing else { return }

        let bodyA = contact.bodyA
        let bodyB = contact.bodyB
        let maskA = bodyA.categoryBitMask
        let maskB = bodyB.categoryBitMask
        let combined = maskA | maskB

        if combined == (GameConstants.PhysicsCategory.player | GameConstants.PhysicsCategory.enemy) {
            let playerNode = maskA == GameConstants.PhysicsCategory.player ? bodyA.node : bodyB.node
            let enemyNode = maskA == GameConstants.PhysicsCategory.enemy ? bodyA.node : bodyB.node
            if let position = playerNode?.position {
                spawnExplosion(at: position, image: "explosion", scale: 1.2)
            }
            playerNode?.removeFromParent()
            enemyNode?.removeFromParent()
            runGameOver()
            return
        }

        if combined == (GameConstants.PhysicsCategory.bullet | GameConstants.PhysicsCategory.enemy) {
            let bulletNode = maskA == GameConstants.PhysicsCategory.bullet ? bodyA.node : bodyB.node
            let enemyNode = maskA == GameConstants.PhysicsCategory.enemy ? bodyA.node : bodyB.node
            guard let enemyNode, enemyNode.position.y < size.height else { return }

            let blastPoint = enemyNode.position
            bulletNode?.removeFromParent()
            enemyNode.removeFromParent()
            spawnExplosion(at: blastPoint, image: "explosion")
            HapticManager.enemyDestroyed()
            addScore()
            return
        }

        if combined == (GameConstants.PhysicsCategory.bullet | GameConstants.PhysicsCategory.powerUp) {
            let bulletNode = maskA == GameConstants.PhysicsCategory.bullet ? bodyA.node : bodyB.node
            let starNode = maskA == GameConstants.PhysicsCategory.powerUp ? bodyA.node : bodyB.node
            guard let starNode, starNode.position.y < size.height else { return }

            let point = starNode.position
            bulletNode?.removeFromParent()
            starNode.removeFromParent()
            collectStar(at: point)
        }
    }

    // MARK: - Controls

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard currentState == .playing, !isPausedBySystem else { return }

        for touch in touches {
            let point = touch.location(in: self)
            let previous = touch.previousLocation(in: self)
            player.position.x += point.x - previous.x
            clampPlayer()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard currentState == .playing, !isPausedBySystem else { return }
        guard let touch = touches.first else { return }
        player.position.x = touch.location(in: self).x
        clampPlayer()
    }

    private func clampPlayer() {
        let halfWidth = player.size.width * 0.5
        let minX = gameArea.minX + halfWidth
        let maxX = gameArea.maxX - halfWidth
        player.position.x = min(max(player.position.x, minX), maxX)
    }
}
