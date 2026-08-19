//
//  GameScene.swift
//  ApolloX
//

import SpriteKit
import UIKit

final class GameScene: SKScene, SKPhysicsContactDelegate {

    private enum State {
        case playing
        case paused
        case gameOver
    }

    private let hud = HUDBarNode()
    private let player = SKSpriteNode(texture: TextureCache.texture("playerShip"))
    private var engineEmitter: SKEmitterNode?

    private var lives = GameRules.startingLives
    private var level = 0
    private var starCharge = 0
    private var poweredShotsRemaining = 0
    private var fireDelay = GameConstants.baseFireDelay
    private var bulletImageName = GameConstants.bulletImage
    private var currentState: State = .playing
    private var playArea = CGRect.zero
    private var isPausedBySystem = false
    private var isInvulnerable = false
    private var runElapsed: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0

    private var pauseOverlay: SKNode?
    private var resumeButton: MenuButtonNode?
    /// Previous-frame projectile positions for swept hit tests against fast shots.
    private var lastProjectilePositions: [ObjectIdentifier: CGPoint] = [:]

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

    override func update(_ currentTime: TimeInterval) {
        guard currentState == .playing, !isPausedBySystem else {
            lastUpdateTime = currentTime
            return
        }
        if lastUpdateTime > 0 {
            runElapsed += currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime
    }

    override func didFinishUpdate() {
        guard currentState == .playing, !isPausedBySystem else { return }
        resolveSweptProjectileHits()
    }

    // MARK: - Layout

    private func relayoutForSafeArea() {
        let layout = playfield
        playArea = layout.safeRect
        hud.layout(in: layout.safeRect)

        if player.parent != nil {
            player.position.x = GameRules.clampPlayerX(
                x: player.position.x,
                playMinX: playArea.minX,
                playMaxX: playArea.maxX,
                halfWidth: player.size.width * player.xScale * 0.45
            )
            player.position.y = playArea.minY + player.size.height * player.yScale * 0.42 + 16
        }

        if let overlay = pauseOverlay {
            overlay.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            resumeButton?.position = CGPoint(x: 0, y: -40)
        }
    }

    private func configurePlayer() {
        player.setScale(GameRules.playerScale)
        player.zPosition = GameConstants.Z.player
        let radius = min(player.size.width, player.size.height) * player.xScale * GameRules.playerHitboxFactor
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
        } else if GameRules.starsNeededForUpgrade > 1, starCharge > 0 {
            hud.setStatus("Stars: \(starCharge)/\(GameRules.starsNeededForUpgrade)")
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
        if currentState == .playing {
            enterPause(showOverlay: true, fromSystem: true)
        } else {
            isPaused = true
            view?.isPaused = true
        }
    }

    @objc private func appDidBecomeActive() {
        isPausedBySystem = false
        // Stay paused until the player taps Resume.
        guard currentState == .paused else { return }
        isPaused = true
        view?.isPaused = true
    }

    // MARK: - Flow

    private func beginLevel() {
        level += 1
    }

    private func startSpawning() {
        removeAction(forKey: "spawningEnemies")
        removeAction(forKey: "spawningPowerUp")
        restartFiring()
        scheduleNextObstacle()
        schedulePowerUps()
        scheduleHealthPickups()
    }

    private func scheduleNextObstacle() {
        removeAction(forKey: "spawningEnemies")
        let delay = GameRules.spawnInterval(level: level, elapsed: runElapsed)
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self, self.currentState == .playing else { return }
                self.spawnObstacle()
                self.scheduleNextObstacle()
            }
        ]), withKey: "spawningEnemies")
    }

    private func schedulePowerUps() {
        removeAction(forKey: "spawningPowerUp")
        let initialDelay = max(0, GameRules.openingPowerUpDelay - runElapsed)
        run(.sequence([
            .wait(forDuration: initialDelay),
            .repeatForever(.sequence([
                .run { [weak self] in self?.spawnPowerUp() },
                .wait(forDuration: GameConstants.powerUpSpawnInterval)
            ]))
        ]), withKey: "spawningPowerUp")
    }

    private func scheduleHealthPickups() {
        removeAction(forKey: "spawningHealth")
        scheduleNextHealthPickup(after: GameRules.nextHealthPickupDelay())
    }

    private func scheduleNextHealthPickup(after delay: TimeInterval) {
        removeAction(forKey: "spawningHealth")
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self, self.currentState == .playing else { return }
                self.spawnHealthPickup()
                self.scheduleNextHealthPickup(after: GameRules.nextHealthPickupDelay())
            }
        ]), withKey: "spawningHealth")
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

        if GameRules.shouldAdvanceLevel(previousScore: previous, newScore: score) {
            beginLevel()
            // Reschedule so the new level interval applies after grace.
            scheduleNextObstacle()
        }
    }

    private func lostALife(fromContact: Bool) {
        guard currentState == .playing else { return }
        let outcome = GameRules.resolvePlayerHit(lives: lives)
        lives = outcome.livesRemaining
        hud.setLives(lives)
        hud.pulseLives()
        HapticManager.lifeLost()
        AudioManager.play(AudioManager.lifeLost, on: self)

        if outcome.isGameOver {
            runGameOver()
            return
        }

        if outcome.grantInvulnerability {
            beginInvulnerability()
        }

        if fromContact {
            // Brief camera shake feel via player nudge.
            player.run(.sequence([
                .moveBy(x: 0, y: 18, duration: 0.05),
                .moveBy(x: 0, y: -18, duration: 0.08)
            ]))
        }
    }

    private func beginInvulnerability() {
        isInvulnerable = true
        player.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.none
        player.removeAction(forKey: "invulnBlink")
        player.alpha = 1
        player.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.35, duration: 0.12),
            .fadeAlpha(to: 1.0, duration: 0.12)
        ])), withKey: "invulnBlink")

        run(.sequence([
            .wait(forDuration: GameRules.invulnerabilityDuration),
            .run { [weak self] in self?.endInvulnerability() }
        ]), withKey: "invulnTimer")
    }

    private func endInvulnerability() {
        isInvulnerable = false
        player.removeAction(forKey: "invulnBlink")
        player.alpha = 1
        player.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.player
    }

    private func runGameOver() {
        guard currentState == .playing || currentState == .paused else { return }
        currentState = .gameOver
        dismissPauseOverlay()
        HapticManager.gameOver()
        engineEmitter?.particleBirthRate = 0

        removeAllActions()
        for name in [
            GameConstants.NodeName.bullet,
            GameConstants.NodeName.enemy,
            GameConstants.NodeName.powerUp,
            GameConstants.NodeName.healthPickup
        ] {
            enumerateChildNodes(withName: name) { node, _ in
                node.removeAllActions()
            }
        }

        ScoreStore.commitHighScoreIfNeeded()
        isPaused = false
        view?.isPaused = false
        run(.sequence([
            .wait(forDuration: 0.85),
            .run { [weak self] in
                guard let self else { return }
                self.presentScene(GameOverScene(size: self.size))
            }
        ]))
    }

    // MARK: - Pause

    private func enterPause(showOverlay: Bool, fromSystem: Bool = false) {
        guard currentState == .playing || currentState == .paused else { return }
        currentState = .paused
        isPaused = true
        view?.isPaused = true
        if showOverlay {
            presentPauseOverlay()
        }
        if !fromSystem {
            AudioManager.play(AudioManager.uiTap, on: self)
            HapticManager.fire()
        }
    }

    private func resumeFromPause() {
        guard currentState == .paused else { return }
        dismissPauseOverlay()
        currentState = .playing
        isPaused = false
        view?.isPaused = false
        lastUpdateTime = 0
        AudioManager.play(AudioManager.uiTap, on: self)
        HapticManager.fire()
    }

    private func presentPauseOverlay() {
        dismissPauseOverlay()

        let root = SKNode()
        root.zPosition = GameConstants.Z.overlay
        root.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)

        let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.55), size: CGSize(width: size.width * 1.2, height: size.height * 1.2))
        dim.zPosition = 0
        root.addChild(dim)

        let title = SKLabelNode(fontNamed: GameFont.resolved(size: 64))
        title.text = "Paused"
        title.fontSize = 64
        title.fontColor = .white
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 80)
        title.zPosition = 1
        root.addChild(title)

        let resume = MenuButtonNode(title: "Resume", width: 420, height: 110, fontSize: 48, emphasized: true)
        resume.position = CGPoint(x: 0, y: -40)
        resume.zPosition = 1
        root.addChild(resume)

        addChild(root)
        pauseOverlay = root
        resumeButton = resume
    }

    private func dismissPauseOverlay() {
        pauseOverlay?.removeFromParent()
        pauseOverlay = nil
        resumeButton = nil
    }

    // MARK: - Spawning

    private func fireBullet() {
        guard currentState == .playing, player.parent != nil else { return }

        let powered = poweredShotsRemaining > 0
        if powered {
            poweredShotsRemaining -= 1
            if poweredShotsRemaining == 0 {
                bulletImageName = GameConstants.bulletImage
                fireDelay = GameConstants.baseFireDelay
                refreshFireRate()
            }
        }

        let bullet = bulletPool.checkout()
        bullet.texture = TextureCache.texture(bulletImageName)
        bullet.size = powered ? GameRules.poweredBulletSize : GameRules.bulletSize
        bullet.name = GameConstants.NodeName.bullet
        bullet.position = CGPoint(x: player.position.x, y: player.position.y + player.size.height * player.yScale * 0.28)
        bullet.zPosition = GameConstants.Z.bullet
        bullet.physicsBody = SKPhysicsBody(circleOfRadius: GameRules.bulletHitRadius)
        bullet.physicsBody?.isDynamic = true
        bullet.physicsBody?.affectedByGravity = false
        bullet.physicsBody?.allowsRotation = false
        bullet.physicsBody?.usesPreciseCollisionDetection = true
        bullet.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.bullet
        bullet.physicsBody?.collisionBitMask = GameConstants.PhysicsCategory.none
        bullet.physicsBody?.contactTestBitMask =
            GameConstants.PhysicsCategory.enemy | GameConstants.PhysicsCategory.powerUp
        addChild(bullet)
        lastProjectilePositions[ObjectIdentifier(bullet)] = bullet.position

        AudioManager.play(AudioManager.laser, on: self)

        let duration = TimeInterval((size.height - bullet.position.y + 80) / GameRules.bulletSpeed)
        bullet.run(.sequence([
            .moveTo(y: size.height + 80, duration: duration),
            .run { [weak self, weak bullet] in
                guard let self, let bullet else { return }
                self.forgetProjectile(bullet)
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
        powerUp.setScale(GameRules.starScale)
        powerUp.position = CGPoint(x: startX, y: playArea.maxY + 80)
        powerUp.zPosition = GameConstants.Z.powerUp
        powerUp.userData = NSMutableDictionary(dictionary: [
            GameConstants.NodeName.powerUpKind: GameConstants.PowerUpKind.star.rawValue
        ])
        powerUp.physicsBody = SKPhysicsBody(circleOfRadius: powerUp.size.width * GameRules.starHitboxFactor)
        powerUp.physicsBody?.isDynamic = true
        powerUp.physicsBody?.affectedByGravity = false
        powerUp.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.powerUp
        powerUp.physicsBody?.collisionBitMask = GameConstants.PhysicsCategory.none
        powerUp.physicsBody?.contactTestBitMask = GameConstants.PhysicsCategory.bullet
        addChild(powerUp)

        powerUp.run(.repeatForever(.sequence([
            .scale(to: GameRules.starPulseScale, duration: 0.55),
            .scale(to: GameRules.starScale, duration: 0.55)
        ])))
        powerUp.run(.repeatForever(.rotate(byAngle: .pi, duration: 3.2)))
        powerUp.run(.sequence([
            .move(to: CGPoint(x: endX, y: playArea.minY - 80), duration: GameConstants.powerUpTravelDuration),
            .removeFromParent()
        ]))
    }

    private func spawnHealthPickup() {
        guard currentState == .playing, playArea.width > 80 else { return }
        // Don't clutter the board if already at max lives.
        guard lives < GameRules.maxLives else { return }

        let inset: CGFloat = 50
        let startX = CGFloat.random(in: playArea.minX + inset...playArea.maxX - inset)
        let endX = CGFloat.random(in: playArea.minX + inset...playArea.maxX - inset)

        let pickup = SKSpriteNode(texture: TextureCache.texture(GameConstants.healthImage))
        pickup.name = GameConstants.NodeName.healthPickup
        pickup.setScale(GameRules.healthPickupScale)
        pickup.position = CGPoint(x: startX, y: playArea.maxY + 80)
        pickup.zPosition = GameConstants.Z.powerUp
        pickup.userData = NSMutableDictionary(dictionary: [
            GameConstants.NodeName.powerUpKind: GameConstants.PowerUpKind.health.rawValue
        ])
        pickup.physicsBody = SKPhysicsBody(circleOfRadius: pickup.size.width * GameRules.healthHitboxFactor)
        pickup.physicsBody?.isDynamic = true
        pickup.physicsBody?.affectedByGravity = false
        pickup.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.powerUp
        pickup.physicsBody?.collisionBitMask = GameConstants.PhysicsCategory.none
        pickup.physicsBody?.contactTestBitMask = GameConstants.PhysicsCategory.bullet
        addChild(pickup)

        pickup.run(.repeatForever(.sequence([
            .scale(to: GameRules.healthPickupPulseScale, duration: 0.5),
            .scale(to: GameRules.healthPickupScale, duration: 0.5)
        ])))
        pickup.run(.sequence([
            .move(to: CGPoint(x: endX, y: playArea.minY - 80), duration: GameConstants.powerUpTravelDuration),
            .removeFromParent()
        ]))
    }

    private func spawnObstacle() {
        guard currentState == .playing, playArea.width > 80 else { return }

        let kind = GameRules.obstacleKind(
            level: level,
            elapsed: runElapsed,
            roll: Int.random(in: 0...99)
        )
        let inset: CGFloat = kind == .comet ? 40 : 58
        // During opening grace, keep paths more centered / less extreme.
        let laneInset = GameRules.isInOpeningGrace(elapsed: runElapsed) ? inset + 36 : inset
        let startX = CGFloat.random(in: playArea.minX + laneInset...playArea.maxX - laneInset)
        let endX: CGFloat
        if kind == .comet {
            let bias: CGFloat = Bool.random() ? 1 : -1
            endX = min(max(startX + bias * CGFloat.random(in: 180...320), playArea.minX + laneInset), playArea.maxX - laneInset)
        } else if GameRules.isInOpeningGrace(elapsed: runElapsed) {
            // Milder drift early on.
            endX = min(max(startX + CGFloat.random(in: -80...80), playArea.minX + laneInset), playArea.maxX - laneInset)
        } else {
            endX = CGFloat.random(in: playArea.minX + laneInset...playArea.maxX - laneInset)
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
        node.zRotation = 0
        let radius = GameRules.obstacleHitRadius(for: kind, spriteSize: node.size, scale: node.xScale)
        node.userData = NSMutableDictionary(dictionary: [
            GameConstants.NodeName.obstacleKind: kind.rawValue,
            GameConstants.NodeName.obstacleHP: kind.hitsToDestroy,
            GameConstants.NodeName.hitRadius: NSNumber(value: Double(radius))
        ])

        node.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        node.physicsBody?.isDynamic = true
        node.physicsBody?.affectedByGravity = false
        node.physicsBody?.allowsRotation = false
        node.physicsBody?.usesPreciseCollisionDetection = true
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

        // Opening grace: slightly slower travel.
        let duration = kind.travelDuration * (GameRules.isInOpeningGrace(elapsed: runElapsed) ? 1.25 : 1.0)
        node.run(.sequence([
            .move(to: end, duration: duration),
            .run { [weak self] in self?.lostALife(fromContact: false) },
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
        let outcome = GameRules.collectStar(currentCharge: starCharge)
        starCharge = outcome.starCharge
        HapticManager.starHit()
        AudioManager.play(AudioManager.star, on: self)
        spawnExplosion(at: position, image: "mini_explosion", scale: 0.85)

        if outcome.activated {
            bulletImageName = GameConstants.poweredBulletImage
            fireDelay = GameConstants.poweredFireDelay
            poweredShotsRemaining = outcome.poweredShots
            HapticManager.upgrade()
            AudioManager.play(AudioManager.boost, on: self)
            refreshFireRate()
            showBoostBanner()
        } else {
            updateHUD()
            hud.pulseStatus()
        }
    }

    private func collectHealth(at position: CGPoint) {
        let previous = lives
        lives = GameRules.livesAfterHealthPickup(current: lives)
        HapticManager.upgrade()
        AudioManager.play(AudioManager.star, on: self)
        spawnExplosion(at: position, image: "mini_explosion", scale: 0.75)
        hud.setLives(lives)
        hud.pulseLives()
        if lives > previous {
            showStatusBanner(text: "+1 LIFE", color: SKColor(red: 0.35, green: 0.95, blue: 0.55, alpha: 1))
        } else {
            showStatusBanner(text: "MAX LIVES", color: GameTheme.accent)
        }
    }

    private func showStatusBanner(text: String, color: SKColor) {
        let banner = SKLabelNode(fontNamed: GameFont.resolved(size: 64))
        banner.text = text
        banner.fontSize = 64
        banner.fontColor = color
        banner.verticalAlignmentMode = .center
        banner.horizontalAlignmentMode = .center
        banner.position = CGPoint(x: playArea.midX, y: playArea.midY + 40)
        banner.zPosition = GameConstants.Z.overlay
        banner.setScale(0.4)
        banner.alpha = 0
        addChild(banner)
        banner.run(.sequence([
            .group([
                .fadeIn(withDuration: 0.1),
                .scale(to: 1.12, duration: 0.16)
            ]),
            .scale(to: 1.0, duration: 0.1),
            .wait(forDuration: 0.35),
            .group([
                .fadeOut(withDuration: 0.22),
                .moveBy(x: 0, y: 36, duration: 0.22)
            ]),
            .removeFromParent()
        ]))
    }

    private func showBoostBanner() {
        let banner = SKLabelNode(fontNamed: GameFont.resolved(size: 72))
        banner.text = "BOOST!"
        banner.fontSize = 72
        banner.fontColor = GameTheme.accent
        banner.verticalAlignmentMode = .center
        banner.horizontalAlignmentMode = .center
        banner.position = CGPoint(x: playArea.midX, y: playArea.midY + 40)
        banner.zPosition = GameConstants.Z.overlay
        banner.setScale(0.4)
        banner.alpha = 0
        addChild(banner)

        let flash = SKSpriteNode(color: SKColor(red: 1, green: 0.85, blue: 0.35, alpha: 0.22), size: size)
        flash.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        flash.zPosition = GameConstants.Z.effect + 1
        flash.alpha = 0
        addChild(flash)

        flash.run(.sequence([
            .fadeAlpha(to: 1, duration: 0.08),
            .fadeOut(withDuration: 0.35),
            .removeFromParent()
        ]))
        banner.run(.sequence([
            .group([
                .fadeIn(withDuration: 0.1),
                .scale(to: 1.15, duration: 0.18)
            ]),
            .scale(to: 1.0, duration: 0.12),
            .wait(forDuration: 0.35),
            .group([
                .fadeOut(withDuration: 0.25),
                .moveBy(x: 0, y: 40, duration: 0.25)
            ]),
            .removeFromParent()
        ]))
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
        spawnExplosion(at: blastPoint, image: "explosion", scale: points >= 3 ? 1.25 : 1.05)
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
            guard !isInvulnerable else { return }
            let enemyNode = maskA == GameConstants.PhysicsCategory.enemy ? contact.bodyA.node : contact.bodyB.node
            if let position = enemyNode?.position {
                spawnExplosion(at: position, image: "explosion", scale: 1.15)
            }
            if let enemy = enemyNode as? SKSpriteNode {
                obstaclePool.recycle(enemy)
            } else {
                enemyNode?.removeFromParent()
            }
            lostALife(fromContact: true)
            return
        }

        if combined == (GameConstants.PhysicsCategory.bullet | GameConstants.PhysicsCategory.enemy) {
            let bulletNode = maskA == GameConstants.PhysicsCategory.bullet ? contact.bodyA.node : contact.bodyB.node
            let enemyNode = maskA == GameConstants.PhysicsCategory.enemy ? contact.bodyA.node : contact.bodyB.node
            guard let enemyNode, enemyNode.parent != nil else { return }
            let hitRadius = colliderRadius(forEnemy: enemyNode)
            guard isColliderOnscreen(enemyNode, radius: hitRadius) else { return }

            let blast = enemyNode.position
            recycleProjectile(bulletNode)
            damageObstacle(enemyNode, blastPoint: blast)
            return
        }

        if combined == (GameConstants.PhysicsCategory.bullet | GameConstants.PhysicsCategory.powerUp) {
            let bulletNode = maskA == GameConstants.PhysicsCategory.bullet ? contact.bodyA.node : contact.bodyB.node
            let pickupNode = maskA == GameConstants.PhysicsCategory.powerUp ? contact.bodyA.node : contact.bodyB.node
            guard let pickupNode, pickupNode.parent != nil else { return }
            let hitRadius = pickupNode.frame.width * 0.5
            guard pickupNode.position.y - hitRadius < playfield.visibleRect.maxY else { return }

            let point = pickupNode.position
            recycleProjectile(bulletNode)

            let kindRaw = pickupNode.userData?[GameConstants.NodeName.powerUpKind] as? String
            let kind = kindRaw.flatMap(GameConstants.PowerUpKind.init(rawValue:))
                ?? (pickupNode.name == GameConstants.NodeName.healthPickup ? .health : .star)
            pickupNode.removeFromParent()

            switch kind {
            case .star:
                collectStar(at: point)
            case .health:
                collectHealth(at: point)
            }
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
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if currentState == .paused {
            if let resumeButton, resumeButton.containsTouch(CGPoint(
                x: point.x - (pauseOverlay?.position.x ?? 0),
                y: point.y - (pauseOverlay?.position.y ?? 0)
            )) {
                resumeButton.pulse()
                resumeFromPause()
            }
            return
        }

        guard currentState == .playing, !isPausedBySystem else { return }

        if hud.containsPauseTouch(point) {
            enterPause(showOverlay: true)
            return
        }

        player.position.x = point.x
        clampPlayer()
    }

    private func clampPlayer() {
        let halfWidth = player.size.width * player.xScale * 0.45
        player.position.x = GameRules.clampPlayerX(
            x: player.position.x,
            playMinX: playArea.minX,
            playMaxX: playArea.maxX,
            halfWidth: halfWidth
        )
    }

    // MARK: - Swept projectile hits

    private func recycleProjectile(_ node: SKNode?) {
        guard let node else { return }
        forgetProjectile(node)
        if let bullet = node as? SKSpriteNode {
            bulletPool.recycle(bullet)
        } else {
            node.removeFromParent()
        }
    }

    private func colliderRadius(forEnemy node: SKNode) -> CGFloat {
        let kindRaw = node.userData?[GameConstants.NodeName.obstacleKind] as? String
        let kind = kindRaw.flatMap(GameConstants.ObstacleKind.init(rawValue:)) ?? .asteroid
        if let sprite = node as? SKSpriteNode {
            return GameRules.obstacleHitRadius(for: kind, spriteSize: sprite.size, scale: sprite.xScale)
        }
        if let number = node.userData?[GameConstants.NodeName.hitRadius] as? NSNumber {
            return CGFloat(truncating: number)
        }
        return 80
    }

    private func isColliderOnscreen(_ node: SKNode, radius: CGFloat) -> Bool {
        node.position.y - radius < playfield.visibleRect.maxY
    }

    private func resolveSweptProjectileHits() {
        var bullets: [SKSpriteNode] = []
        enumerateChildNodes(withName: GameConstants.NodeName.bullet) { node, _ in
            if let sprite = node as? SKSpriteNode, sprite.parent != nil {
                bullets.append(sprite)
            }
        }

        var liveKeys = Set<ObjectIdentifier>()
        for bullet in bullets {
            let key = ObjectIdentifier(bullet)
            liveKeys.insert(key)
            let start = lastProjectilePositions[key] ?? bullet.position
            let end = bullet.position
            lastProjectilePositions[key] = end

            if applySweptHit(bullet: bullet, start: start, end: end) {
                continue
            }
        }

        lastProjectilePositions = lastProjectilePositions.filter { liveKeys.contains($0.key) }
    }

    private func applySweptHit(bullet: SKSpriteNode, start: CGPoint, end: CGPoint) -> Bool {
        var hitEnemy: SKNode?
        enumerateChildNodes(withName: GameConstants.NodeName.enemy) { node, stop in
            guard node.parent != nil else { return }
            let radius = colliderRadius(forEnemy: node)
            guard isColliderOnscreen(node, radius: radius) else { return }
            if GameRules.projectileHitsTarget(
                start: start,
                end: end,
                projectileRadius: GameRules.bulletHitRadius,
                target: node.position,
                targetRadius: radius
            ) {
                hitEnemy = node
                stop.pointee = true
            }
        }
        if let enemy = hitEnemy {
            recycleProjectile(bullet)
            damageObstacle(enemy, blastPoint: enemy.position)
            return true
        }

        var hitPickup: SKNode?
        let pickupNames = [GameConstants.NodeName.powerUp, GameConstants.NodeName.healthPickup]
        for name in pickupNames {
            enumerateChildNodes(withName: name) { node, stop in
                guard node.parent != nil else { return }
                let radius = node.frame.width * 0.5
                if GameRules.projectileHitsTarget(
                    start: start,
                    end: end,
                    projectileRadius: GameRules.bulletHitRadius,
                    target: node.position,
                    targetRadius: radius
                ) {
                    hitPickup = node
                    stop.pointee = true
                }
            }
            if hitPickup != nil { break }
        }
        if let pickup = hitPickup {
            recycleProjectile(bullet)
            let point = pickup.position
            let kindRaw = pickup.userData?[GameConstants.NodeName.powerUpKind] as? String
            let kind = kindRaw.flatMap(GameConstants.PowerUpKind.init(rawValue:))
                ?? (pickup.name == GameConstants.NodeName.healthPickup ? .health : .star)
            pickup.removeFromParent()
            switch kind {
            case .star:
                collectStar(at: point)
            case .health:
                collectHealth(at: point)
            }
            return true
        }

        return false
    }
}
