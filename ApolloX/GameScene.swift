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

    private lazy var bulletPool = NodePool(prewarm: 18) {
        SKSpriteNode(texture: TextureCache.texture(GameConstants.bulletImage))
    }
    private lazy var obstaclePool = NodePool(prewarm: 10) {
        SKSpriteNode(texture: TextureCache.texture("asteroid"))
    }
    private lazy var explosionPool = NodePool(prewarm: 10) {
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
            player.position.x = min(
                max(player.position.x, playArea.minX + player.size.width * 0.35),
                playArea.maxX - player.size.width * 0.35
            )
            player.position.y = playArea.minY + player.size.height * 0.42 + 16
        }
    }

    private func configurePlayer() {
        player.setScale(0.42)
        player.zPosition = GameConstants.Z.player
        let radius = min(player.size.width, player.size.height) * player.xScale * 0.30
        player.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        player.physicsBody?.isDynamic = true
        player.physicsBody?.affectedByGravity = false
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.player
        player.physicsBody?.collisionBitMask = GameConstants.PhysicsCategory.none
        player.physicsBody?.contactTestBitMask = GameConstants.PhysicsCategory.enemy
        addChild(player)

        let engine = makeEngineEmitter()
        engine.position = CGPoint(x: 0, y: -player.size.height * 0.40)
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

    // MARK: - Flow

    private func beginLevel() {
        level += 1
    }

    private func startSpawning() {
        removeAction(forKey: "spawningEnemies")
        removeAction(forKey: "spawningPowerUp")
        restartFiring()

        run(.repeatForever(.sequence([
            .wait(forDuration: GameConstants.levelSpawnInterval(for: level)),
            .run { [weak self] in self?.spawnObstacle() }
        ])), withKey: "spawningEnemies")

        run(.repeatForever(.sequence([
            .wait(forDuration: GameConstants.powerUpSpawnInterval),
            .run { [weak self] in self?.spawnPowerUp() }
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

    private func addScore(_ amount: Int = 1) {
        let previous = ScoreStore.currentScore
        let score = ScoreStore.addPoint(amount)
        hud.setScore(score)

        let thresholds = [10, 25, 50, 80]
        if thresholds.contains(where: { previous < $0 && score >= $0 }) {
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
        AudioManager.play(AudioManager.lifeLost, on: self)
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
        for name in [GameConstants.NodeName.bullet, GameConstants.NodeName.enemy, GameConstants.NodeName.powerUp] {
            enumerateChildNodes(withName: name) { node, _ in
                node.removeAllActions()
            }
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
        bullet.size = CGSize(width: 28, height: 56)
        bullet.name = GameConstants.NodeName.bullet
        bullet.position = CGPoint(x: player.position.x, y: player.position.y + player.size.height * 0.28)
        bullet.zPosition = GameConstants.Z.bullet
        bullet.physicsBody = SKPhysicsBody(circleOfRadius: 8)
        bullet.physicsBody?.isDynamic = true
        bullet.physicsBody?.affectedByGravity = false
        bullet.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.bullet
        bullet.physicsBody?.collisionBitMask = GameConstants.PhysicsCategory.none
        bullet.physicsBody?.contactTestBitMask =
            GameConstants.PhysicsCategory.enemy | GameConstants.PhysicsCategory.powerUp
        addChild(bullet)

        AudioManager.play(AudioManager.laser, on: self)

        let duration = TimeInterval((size.height - bullet.position.y + 80) / 1700)
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

        let powerUp = SKSpriteNode(texture: TextureCache.texture(GameConstants.starImage))
        powerUp.name = GameConstants.NodeName.powerUp
        powerUp.setScale(0.42)
        powerUp.position = CGPoint(x: startX, y: playArea.maxY + 80)
        powerUp.zPosition = GameConstants.Z.powerUp
        powerUp.physicsBody = SKPhysicsBody(circleOfRadius: powerUp.size.width * 0.32)
        powerUp.physicsBody?.isDynamic = true
        powerUp.physicsBody?.affectedByGravity = false
        powerUp.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.powerUp
        powerUp.physicsBody?.collisionBitMask = GameConstants.PhysicsCategory.none
        powerUp.physicsBody?.contactTestBitMask = GameConstants.PhysicsCategory.bullet
        addChild(powerUp)

        powerUp.run(.repeatForever(.sequence([
            .scale(to: 0.48, duration: 0.55),
            .scale(to: 0.42, duration: 0.55)
        ])))
        powerUp.run(.repeatForever(.rotate(byAngle: .pi, duration: 3.2)))
        powerUp.run(.sequence([
            .move(to: CGPoint(x: endX, y: playArea.minY - 80), duration: GameConstants.powerUpTravelDuration),
            .removeFromParent()
        ]))
    }

    private func spawnObstacle() {
        guard currentState == .playing, playArea.width > 80 else { return }

        let kind = GameConstants.randomObstacle(for: level)
        let inset: CGFloat = kind == .comet ? 40 : 58
        let startX = CGFloat.random(in: playArea.minX + inset...playArea.maxX - inset)
        let endX: CGFloat
        if kind == .comet {
            // Comets slash across the lane.
            let bias: CGFloat = Bool.random() ? 1 : -1
            endX = min(max(startX + bias * CGFloat.random(in: 180...320), playArea.minX + inset), playArea.maxX - inset)
        } else {
            endX = CGFloat.random(in: playArea.minX + inset...playArea.maxX - inset)
        }

        let start = CGPoint(x: startX, y: playArea.maxY + 100)
        let end = CGPoint(x: endX, y: playArea.minY - 120)

        let node = obstaclePool.checkout()
        node.texture = TextureCache.texture(kind.rawValue)
        let texSize = node.texture?.size() ?? CGSize(width: 160, height: 160)
        node.size = texSize
        node.setScale(kind.scale)
        node.name = GameConstants.NodeName.enemy
        node.position = start
        node.zPosition = GameConstants.Z.enemy
        node.alpha = 1
        node.userData = NSMutableDictionary(dictionary: [
            GameConstants.NodeName.obstacleKind: kind.rawValue,
            GameConstants.NodeName.obstacleHP: kind.hitsToDestroy
        ])

        let radius = min(node.size.width, node.size.height) * node.xScale * 0.34
        node.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        node.physicsBody?.isDynamic = true
        node.physicsBody?.affectedByGravity = false
        node.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.enemy
        node.physicsBody?.collisionBitMask = GameConstants.PhysicsCategory.none
        node.physicsBody?.contactTestBitMask =
            GameConstants.PhysicsCategory.player | GameConstants.PhysicsCategory.bullet
        addChild(node)

        if kind == .comet {
            let dx = end.x - start.x
            let dy = end.y - start.y
            node.zRotation = atan2(dy, dx)
        } else if kind == .drone {
            node.zRotation = 0
        } else if kind == .mine {
            AudioManager.play(AudioManager.mine, on: self)
            node.run(.repeatForever(.sequence([
                .scale(to: kind.scale * 1.08, duration: 0.45),
                .scale(to: kind.scale, duration: 0.45)
            ])))
        } else {
            let spin = CGFloat.random(in: 0.6...1.4) * (Bool.random() ? 1 : -1)
            node.run(.repeatForever(.rotate(byAngle: spin, duration: 1.0)))
        }

        node.run(.sequence([
            .move(to: end, duration: kind.travelDuration),
            .run { [weak self] in self?.lostALife() },
            .run { [weak self, weak node] in
                guard let self, let node else { return }
                self.obstaclePool.recycle(node)
            }
        ]))
    }

    private func spawnExplosion(at position: CGPoint, image: String, scale: CGFloat = 1) {
        let explosion = explosionPool.checkout()
        explosion.texture = TextureCache.texture(image)
        explosion.size = explosion.texture?.size() ?? CGSize(width: 160, height: 160)
        explosion.position = position
        explosion.zPosition = GameConstants.Z.effect
        explosion.setScale(0)
        explosion.alpha = 1
        addChild(explosion)
        AudioManager.play(AudioManager.explosion, on: self)

        explosion.run(.sequence([
            .group([
                .scale(to: scale, duration: 0.16),
                .fadeOut(withDuration: 0.28)
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
        AudioManager.play(AudioManager.star, on: self)
        spawnExplosion(at: position, image: "mini_explosion", scale: 0.7)
        updateHUD()
        hud.pulseStatus()

        if starCharge >= GameConstants.starsNeededForUpgrade {
            starCharge = 0
            bulletImageName = GameConstants.poweredBulletImage
            fireDelay = GameConstants.poweredFireDelay
            poweredShotsRemaining = GameConstants.poweredShotCount
            HapticManager.upgrade()
            AudioManager.play(AudioManager.boost, on: self)
            refreshFireRate()
        }
    }

    private func damageObstacle(_ node: SKNode, blastPoint: CGPoint) {
        guard let data = node.userData else {
            destroyObstacle(node, blastPoint: blastPoint, points: 1)
            return
        }
        let kindRaw = data[GameConstants.NodeName.obstacleKind] as? String
        let kind = kindRaw.flatMap(GameConstants.ObstacleKind.init(rawValue:)) ?? .asteroid
        let hp = max(0, (data[GameConstants.NodeName.obstacleHP] as? Int ?? 1) - 1)
        data[GameConstants.NodeName.obstacleHP] = hp

        if hp > 0 {
            // Mine damaged but still alive.
            node.run(.sequence([
                .scale(to: kind.scale * 1.15, duration: 0.06),
                .scale(to: kind.scale, duration: 0.08)
            ]))
            spawnExplosion(at: blastPoint, image: "mini_explosion", scale: 0.55)
            HapticManager.enemyDestroyed()
            return
        }

        destroyObstacle(node, blastPoint: blastPoint, points: kind.points)
    }

    private func destroyObstacle(_ node: SKNode, blastPoint: CGPoint, points: Int) {
        if let sprite = node as? SKSpriteNode {
            obstaclePool.recycle(sprite)
        } else {
            node.removeFromParent()
        }
        spawnExplosion(at: blastPoint, image: "explosion", scale: points >= 3 ? 1.15 : 0.95)
        HapticManager.enemyDestroyed()
        addScore(points)
    }

    // MARK: - Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        guard currentState == .playing else { return }

        let maskA = contact.bodyA.categoryBitMask
        let maskB = contact.bodyB.categoryBitMask
        let combined = maskA | maskB

        if combined == (GameConstants.PhysicsCategory.player | GameConstants.PhysicsCategory.enemy) {
            let playerNode = maskA == GameConstants.PhysicsCategory.player ? contact.bodyA.node : contact.bodyB.node
            let enemyNode = maskA == GameConstants.PhysicsCategory.enemy ? contact.bodyA.node : contact.bodyB.node
            if let position = playerNode?.position {
                spawnExplosion(at: position, image: "explosion", scale: 1.2)
            }
            playerNode?.removeFromParent()
            if let enemy = enemyNode as? SKSpriteNode {
                obstaclePool.recycle(enemy)
            } else {
                enemyNode?.removeFromParent()
            }
            runGameOver()
            return
        }

        if combined == (GameConstants.PhysicsCategory.bullet | GameConstants.PhysicsCategory.enemy) {
            let bulletNode = maskA == GameConstants.PhysicsCategory.bullet ? contact.bodyA.node : contact.bodyB.node
            let enemyNode = maskA == GameConstants.PhysicsCategory.enemy ? contact.bodyA.node : contact.bodyB.node
            guard let enemyNode, enemyNode.position.y < playArea.maxY + 50 else { return }

            let blast = enemyNode.position
            if let bullet = bulletNode as? SKSpriteNode {
                bulletPool.recycle(bullet)
            } else {
                bulletNode?.removeFromParent()
            }
            damageObstacle(enemyNode, blastPoint: blast)
            return
        }

        if combined == (GameConstants.PhysicsCategory.bullet | GameConstants.PhysicsCategory.powerUp) {
            let bulletNode = maskA == GameConstants.PhysicsCategory.bullet ? contact.bodyA.node : contact.bodyB.node
            let starNode = maskA == GameConstants.PhysicsCategory.powerUp ? contact.bodyA.node : contact.bodyB.node
            guard let starNode, starNode.position.y < playArea.maxY + 50 else { return }

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
            player.position.x += touch.location(in: self).x - touch.previousLocation(in: self).x
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
        let halfWidth = player.size.width * player.xScale * 0.45
        player.position.x = min(max(player.position.x, playArea.minX + halfWidth), playArea.maxX - halfWidth)
    }
}
