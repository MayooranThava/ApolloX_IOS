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

    private let hud = HUDBarNode()
    private let player = SKSpriteNode(texture: TextureCache.texture("playerShip"))
    private var engineEmitter: SKEmitterNode?

    private var lives = GameConstants.startingLives
    private var level = 0
    private var starCharge = 0
    private var poweredShotsRemaining = 0
    private var fireDelay = GameConstants.baseFireDelay
    private var bulletImageName = GameConstants.bulletImage
    private var currentState: State = .playing
    private var playArea = CGRect.zero
    private var isPausedBySystem = false

    private let laserSound = SKAction.playSoundFileNamed("laserSound.mp3", waitForCompletion: false)
    private let explosionSound = SKAction.playSoundFileNamed("explosionShort.wav", waitForCompletion: false)

    private lazy var bulletPool = NodePool(prewarm: 16) {
        SKSpriteNode(texture: TextureCache.texture(GameConstants.bulletImage))
    }
    private lazy var enemyPool = NodePool(prewarm: 8) {
        SKSpriteNode(texture: TextureCache.texture("enemyShip"))
    }
    private lazy var explosionPool = NodePool(prewarm: 8) {
        SKSpriteNode(texture: TextureCache.texture("explosion"))
    }

    override init(size: CGSize) {
        super.init(size: size)
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
        // Contact-only gameplay; skip expensive continuous collision resolution.
        physicsWorld.speed = 1

        addProductionBackground()
        addChild(hud)
        configurePlayer()
        relayoutForSafeArea()
        whenSafeAreaReady { [weak self] in
            self?.relayoutForSafeArea()
        }

        beginLevel()
        startSpawning()
        registerLifecycleObservers()
        updateHUD()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        relayoutForSafeArea()
    }

    // MARK: - Layout

    private func relayoutForSafeArea() {
        let layout = playfield
        playArea = layout.safeRect
        hud.layout(in: layout.safeRect)

        if player.parent != nil {
            player.position.x = min(max(player.position.x, playArea.minX + player.size.width * 0.4),
                                    playArea.maxX - player.size.width * 0.4)
            player.position.y = playArea.minY + player.size.height * 0.75 + 20
        }
    }

    private func configurePlayer() {
        player.setScale(0.92)
        player.zPosition = GameConstants.Z.player
        player.physicsBody = SKPhysicsBody(circleOfRadius: min(player.size.width, player.size.height) * 0.32)
        player.physicsBody?.isDynamic = true
        player.physicsBody?.affectedByGravity = false
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.player
        player.physicsBody?.collisionBitMask = GameConstants.PhysicsCategory.none
        player.physicsBody?.contactTestBitMask = GameConstants.PhysicsCategory.enemy
        addChild(player)

        let engine = makeEngineEmitter()
        engine.position = CGPoint(x: 0, y: -player.size.height * 0.42)
        player.addChild(engine)
        engineEmitter = engine
    }

    private func updateHUD() {
        hud.setScore(ScoreStore.currentScore)
        hud.setLives(lives)
        if poweredShotsRemaining > 0 {
            hud.setStatus("Fire: Boost")
        } else if starCharge > 0 {
            hud.setStatus("Stars: \(starCharge)/\(GameConstants.starsNeededForUpgrade)")
        } else {
            hud.setStatus("Fire: Normal")
        }
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

        run(.repeatForever(.sequence([
            .wait(forDuration: currentSpawnInterval()),
            spawnEnemyAction
        ])), withKey: "spawningEnemies")

        run(.repeatForever(.sequence([
            .wait(forDuration: GameConstants.powerUpSpawnInterval),
            spawnPowerAction
        ])), withKey: "spawningPowerUp")
    }

    private func restartFiring() {
        removeAction(forKey: "fireBullets")
        run(.repeatForever(.sequence([
            .wait(forDuration: fireDelay),
            .run { [weak self] in self?.fireBullet() }
        ])), withKey: "fireBullets")
    }

    private func refreshFireRate() {
        restartFiring()
        updateHUD()
        hud.pulseStatus()
    }

    private func addScore() {
        _ = ScoreStore.addPoint()
        hud.setScore(ScoreStore.currentScore)

        let score = ScoreStore.currentScore
        if score == 10 || score == 25 || score == 50 || score == 80 {
            beginLevel()
            startSpawning()
        }
    }

    private func lostALife() {
        guard currentState == .playing else { return }

        lives -= 1
        hud.setLives(lives)
        hud.pulseLives()
        HapticManager.lifeLost()

        if lives <= 0 {
            runGameOver()
        }
    }

    private func runGameOver() {
        guard currentState == .playing else { return }
        currentState = .gameOver
        HapticManager.gameOver()
        engineEmitter?.particleBirthRate = 0

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
            .wait(forDuration: 0.85),
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

        let bullet = bulletPool.checkout()
        bullet.texture = TextureCache.texture(bulletImageName)
        bullet.size = bullet.texture?.size() ?? CGSize(width: 20, height: 40)
        bullet.name = GameConstants.NodeName.bullet
        bullet.position = CGPoint(x: player.position.x, y: player.position.y + player.size.height * 0.34)
        bullet.zPosition = GameConstants.Z.bullet
        bullet.physicsBody = SKPhysicsBody(circleOfRadius: max(6, bullet.size.width * 0.35))
        bullet.physicsBody?.isDynamic = true
        bullet.physicsBody?.affectedByGravity = false
        bullet.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.bullet
        bullet.physicsBody?.collisionBitMask = GameConstants.PhysicsCategory.none
        bullet.physicsBody?.contactTestBitMask =
            GameConstants.PhysicsCategory.enemy | GameConstants.PhysicsCategory.powerUp
        addChild(bullet)

        // Sound only — per-shot haptics are expensive and muddy on ProMotion devices.
        run(laserSound)

        let distance = size.height - bullet.position.y + 80
        let duration = TimeInterval(distance / 1600)
        bullet.run(.sequence([
            .moveTo(y: size.height + 80, duration: duration),
            .run { [weak self, weak bullet] in
                guard let self, let bullet else { return }
                self.bulletPool.recycle(bullet)
            }
        ]))
    }

    private func spawnPowerUp() {
        guard currentState == .playing, playArea.width > 80 else { return }

        let inset: CGFloat = 50
        let startX = CGFloat.random(in: playArea.minX + inset...playArea.maxX - inset)
        let endX = CGFloat.random(in: playArea.minX + inset...playArea.maxX - inset)
        let start = CGPoint(x: startX, y: playArea.maxY + 80)
        let end = CGPoint(x: endX, y: playArea.minY - 80)

        let powerUp = SKSpriteNode(texture: TextureCache.texture(GameConstants.starImage))
        powerUp.name = GameConstants.NodeName.powerUp
        powerUp.setScale(0.13)
        powerUp.position = start
        powerUp.zPosition = GameConstants.Z.powerUp
        powerUp.physicsBody = SKPhysicsBody(circleOfRadius: powerUp.size.width * 0.34)
        powerUp.physicsBody?.isDynamic = true
        powerUp.physicsBody?.affectedByGravity = false
        powerUp.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.powerUp
        powerUp.physicsBody?.collisionBitMask = GameConstants.PhysicsCategory.none
        powerUp.physicsBody?.contactTestBitMask = GameConstants.PhysicsCategory.bullet
        addChild(powerUp)

        powerUp.run(.repeatForever(.rotate(byAngle: .pi, duration: 2.4)))
        powerUp.run(.sequence([
            .move(to: end, duration: GameConstants.powerUpTravelDuration),
            .removeFromParent()
        ]))
    }

    private func spawnEnemy() {
        guard currentState == .playing, playArea.width > 80 else { return }

        let inset: CGFloat = 56
        let startX = CGFloat.random(in: playArea.minX + inset...playArea.maxX - inset)
        let endX = CGFloat.random(in: playArea.minX + inset...playArea.maxX - inset)
        let start = CGPoint(x: startX, y: playArea.maxY + 90)
        let end = CGPoint(x: endX, y: playArea.minY - 100)

        let enemy = enemyPool.checkout()
        enemy.texture = TextureCache.texture("enemyShip")
        enemy.size = enemy.texture?.size() ?? CGSize(width: 100, height: 100)
        enemy.name = GameConstants.NodeName.enemy
        enemy.position = start
        enemy.zPosition = GameConstants.Z.enemy
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: min(enemy.size.width, enemy.size.height) * 0.34)
        enemy.physicsBody?.isDynamic = true
        enemy.physicsBody?.affectedByGravity = false
        enemy.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.enemy
        enemy.physicsBody?.collisionBitMask = GameConstants.PhysicsCategory.none
        enemy.physicsBody?.contactTestBitMask =
            GameConstants.PhysicsCategory.player | GameConstants.PhysicsCategory.bullet
        addChild(enemy)

        let dx = end.x - start.x
        let dy = end.y - start.y
        enemy.zRotation = atan2(dy, dx)

        enemy.run(.sequence([
            .move(to: end, duration: GameConstants.enemyTravelDuration),
            .run { [weak self] in self?.lostALife() },
            .run { [weak self, weak enemy] in
                guard let self, let enemy else { return }
                self.enemyPool.recycle(enemy)
            }
        ]))
    }

    private func spawnExplosion(at position: CGPoint, image: String, scale: CGFloat = 1) {
        let explosion = explosionPool.checkout()
        explosion.texture = TextureCache.texture(image)
        explosion.size = explosion.texture?.size() ?? CGSize(width: 120, height: 120)
        explosion.position = position
        explosion.zPosition = GameConstants.Z.effect
        explosion.setScale(0)
        explosion.alpha = 1
        addChild(explosion)
        run(explosionSound)

        explosion.run(.sequence([
            .group([
                .scale(to: scale, duration: 0.16),
                .fadeOut(withDuration: 0.26)
            ]),
            .run { [weak self, weak explosion] in
                guard let self, let explosion else { return }
                self.explosionPool.recycle(explosion)
            }
        ]))
    }

    private func collectStar(at position: CGPoint) {
        starCharge += 1
        HapticManager.starHit()
        spawnExplosion(at: position, image: "mini_explosion", scale: 0.75)
        updateHUD()
        hud.pulseStatus()

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
                spawnExplosion(at: position, image: "explosion", scale: 1.15)
            }
            playerNode?.removeFromParent()
            if let enemy = enemyNode as? SKSpriteNode {
                enemyPool.recycle(enemy)
            } else {
                enemyNode?.removeFromParent()
            }
            runGameOver()
            return
        }

        if combined == (GameConstants.PhysicsCategory.bullet | GameConstants.PhysicsCategory.enemy) {
            let bulletNode = maskA == GameConstants.PhysicsCategory.bullet ? bodyA.node : bodyB.node
            let enemyNode = maskA == GameConstants.PhysicsCategory.enemy ? bodyA.node : bodyB.node
            guard let enemyNode, enemyNode.position.y < playArea.maxY + 40 else { return }

            let blastPoint = enemyNode.position
            if let bullet = bulletNode as? SKSpriteNode {
                bulletPool.recycle(bullet)
            } else {
                bulletNode?.removeFromParent()
            }
            if let enemy = enemyNode as? SKSpriteNode {
                enemyPool.recycle(enemy)
            } else {
                enemyNode.removeFromParent()
            }
            spawnExplosion(at: blastPoint, image: "explosion")
            HapticManager.enemyDestroyed()
            addScore()
            return
        }

        if combined == (GameConstants.PhysicsCategory.bullet | GameConstants.PhysicsCategory.powerUp) {
            let bulletNode = maskA == GameConstants.PhysicsCategory.bullet ? bodyA.node : bodyB.node
            let starNode = maskA == GameConstants.PhysicsCategory.powerUp ? bodyA.node : bodyB.node
            guard let starNode, starNode.position.y < playArea.maxY + 40 else { return }

            let point = starNode.position
            if let bullet = bulletNode as? SKSpriteNode {
                bulletPool.recycle(bullet)
            } else {
                bulletNode?.removeFromParent()
            }
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
        let halfWidth = player.size.width * 0.42
        player.position.x = min(max(player.position.x, playArea.minX + halfWidth), playArea.maxX - halfWidth)
    }
}
