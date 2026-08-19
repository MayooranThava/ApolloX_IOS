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
    private let bossHealthBar = BossHealthBarNode()
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
    private var bossSpawned = false
    private var bossActive = false
    private var bossVulnerable = false
    private var bossSpawnedAt: TimeInterval = 0
    private var bossNode: PooledSprite?
    /// Cached so swept tests do not rebuild `PlayfieldLayout` every pair.
    private var visibleMaxY: CGFloat = 0

    private var pauseOverlay: SKNode?
    private var resumeButton: MenuButtonNode?

    private var liveBullets: [PooledSprite] = []
    private var liveEnemies: [PooledSprite] = []
    private var livePickups: [PooledSprite] = []
    private var liveFireballs: [PooledSprite] = []

    private lazy var bulletPool = NodePool(prewarm: 18, maxIdle: 24) {
        PooledSprite(texture: TextureCache.texture(GameConstants.bulletImage))
    }
    private lazy var obstaclePool = NodePool(prewarm: 10, maxIdle: 16) {
        PooledSprite(texture: TextureCache.texture("asteroid"))
    }
    private lazy var explosionPool = NodePool(prewarm: 10, maxIdle: 16) {
        PooledSprite(texture: TextureCache.texture("explosion"))
    }
    private lazy var pickupPool = NodePool(prewarm: 2, maxIdle: 6) {
        PooledSprite(texture: TextureCache.texture(GameConstants.starImage))
    }
    private lazy var fireballPool = NodePool(prewarm: 6, maxIdle: 10) {
        PooledSprite(texture: TextureCache.texture(GameConstants.fireballImage))
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
        addChild(bossHealthBar)
        configurePlayer()
        relayoutForSafeArea()
        whenSafeAreaReady { [weak self] in
            self?.relayoutForSafeArea()
        }

        beginLevel()
        startSpawning()
        registerLifecycleObservers()
        updateHUD()
        applyPerformanceQuality()
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

        if GameRules.shouldSpawnBoss(elapsed: runElapsed, bossSpawned: bossSpawned, bossActive: bossActive) {
            bossSpawned = true
            spawnBoss()
        }

        updateBossVulnerability()
    }

    private func updateBossVulnerability() {
        guard bossActive, !bossVulnerable, let boss = bossNode, boss.parent != nil else { return }

        let elapsed = runElapsed - bossSpawnedAt
        let halfHeight = boss.size.height * boss.xScale * 0.5
        let fullyVisible = GameRules.isBossFullyVisible(
            centerY: boss.position.y,
            halfHeight: halfHeight,
            playMinY: playArea.minY,
            playMaxY: playArea.maxY
        )
        guard GameRules.isBossVulnerable(elapsedSinceSpawn: elapsed, fullyVisible: fullyVisible) else { return }

        bossVulnerable = true
        boss.removeAction(forKey: "bossInvulnPulse")
        boss.alpha = 1
        hud.setStatus("Boss Fight!")
        hud.pulseStatus()
        showStatusBanner(text: "ENGAGE!", color: GameTheme.accent)
    }

    override func didFinishUpdate() {
        guard currentState == .playing, !isPausedBySystem else { return }
        resolveSweptProjectileHits()
    }

    // MARK: - Layout

    private func relayoutForSafeArea() {
        let layout = playfield
        playArea = layout.safeRect
        visibleMaxY = layout.visibleRect.maxY
        hud.layout(in: layout.safeRect)
        bossHealthBar.layout(in: layout.safeRect, below: 108)

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
            | GameConstants.PhysicsCategory.enemyProjectile
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePerformanceChange),
            name: .apolloXPerformanceDidChange,
            object: nil
        )
    }

    @objc private func handlePerformanceChange() {
        applyPerformanceQuality()
        guard currentState == .playing else { return }
        engineEmitter?.particleBirthRate = FramePacing.currentQuality.engineBirthRate
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
        guard !bossActive else { return }
        let delay = GameRules.spawnInterval(elapsed: runElapsed)
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self, self.currentState == .playing, !self.bossActive else { return }
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
        }
    }

    private func lostALife(fromContact: Bool) {
        guard currentState == .playing else { return }
        let outcome = GameRules.resolvePlayerHit(lives: lives)
        lives = outcome.livesRemaining
        hud.setLives(lives)
        hud.pulseLives()
        HapticManager.lifeLost()
        AudioManager.play(.lifeLost)

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
        for sprite in liveBullets + liveEnemies + livePickups + liveFireballs {
            sprite.removeAllActions()
        }
        bossNode?.removeAllActions()
        bossHealthBar.hideBar()

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
            AudioManager.play(.uiTap)
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
        AudioManager.play(.uiTap)
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
        bullet.hitRadius = GameRules.bulletHitRadius
        bullet.lastPosition = bullet.position
        bullet.attachCirclePhysics(
            radius: GameRules.bulletHitRadius,
            category: GameConstants.PhysicsCategory.bullet,
            contact: GameConstants.PhysicsCategory.enemy | GameConstants.PhysicsCategory.powerUp
        )
        addChild(bullet)
        liveBullets.append(bullet)

        AudioManager.play(.laser)

        let duration = TimeInterval((size.height - bullet.position.y + 80) / GameRules.bulletSpeed)
        bullet.run(.sequence([
            .moveTo(y: size.height + 80, duration: duration),
            .run { [weak self, weak bullet] in
                guard let self, let bullet else { return }
                self.recycleProjectile(bullet)
            }
        ]))
    }

    private func spawnPowerUp() {
        guard currentState == .playing, playArea.width > 80 else { return }

        let inset: CGFloat = 50
        let startX = CGFloat.random(in: playArea.minX + inset...playArea.maxX - inset)
        let endX = CGFloat.random(in: playArea.minX + inset...playArea.maxX - inset)

        let powerUp = pickupPool.checkout()
        powerUp.texture = TextureCache.texture(GameConstants.starImage)
        powerUp.name = GameConstants.NodeName.powerUp
        powerUp.setScale(GameRules.starScale)
        powerUp.position = CGPoint(x: startX, y: playArea.maxY + 80)
        powerUp.zPosition = GameConstants.Z.powerUp
        powerUp.powerUpKind = .star
        powerUp.hitRadius = powerUp.size.width * GameRules.starHitboxFactor
        powerUp.attachCirclePhysics(
            radius: powerUp.hitRadius,
            category: GameConstants.PhysicsCategory.powerUp,
            contact: GameConstants.PhysicsCategory.bullet
        )
        addChild(powerUp)
        livePickups.append(powerUp)

        powerUp.run(.repeatForever(.sequence([
            .scale(to: GameRules.starPulseScale, duration: 0.55),
            .scale(to: GameRules.starScale, duration: 0.55)
        ])))
        powerUp.run(.repeatForever(.rotate(byAngle: .pi, duration: 3.2)))
        powerUp.run(.sequence([
            .move(to: CGPoint(x: endX, y: playArea.minY - 80), duration: GameConstants.powerUpTravelDuration),
            .run { [weak self, weak powerUp] in
                guard let self, let powerUp else { return }
                self.recyclePickup(powerUp)
            }
        ]))
    }

    private func spawnHealthPickup() {
        guard currentState == .playing, playArea.width > 80 else { return }
        // Don't clutter the board if already at max lives.
        guard lives < GameRules.maxLives else { return }

        let inset: CGFloat = 50
        let startX = CGFloat.random(in: playArea.minX + inset...playArea.maxX - inset)
        let endX = CGFloat.random(in: playArea.minX + inset...playArea.maxX - inset)

        let pickup = pickupPool.checkout()
        pickup.texture = TextureCache.texture(GameConstants.healthImage)
        pickup.name = GameConstants.NodeName.healthPickup
        pickup.setScale(GameRules.healthPickupScale)
        pickup.position = CGPoint(x: startX, y: playArea.maxY + 80)
        pickup.zPosition = GameConstants.Z.powerUp
        pickup.powerUpKind = .health
        pickup.hitRadius = pickup.size.width * GameRules.healthHitboxFactor
        pickup.attachCirclePhysics(
            radius: pickup.hitRadius,
            category: GameConstants.PhysicsCategory.powerUp,
            contact: GameConstants.PhysicsCategory.bullet
        )
        addChild(pickup)
        livePickups.append(pickup)

        pickup.run(.repeatForever(.sequence([
            .scale(to: GameRules.healthPickupPulseScale, duration: 0.5),
            .scale(to: GameRules.healthPickupScale, duration: 0.5)
        ])))
        pickup.run(.sequence([
            .move(to: CGPoint(x: endX, y: playArea.minY - 80), duration: GameConstants.powerUpTravelDuration),
            .run { [weak self, weak pickup] in
                guard let self, let pickup else { return }
                self.recyclePickup(pickup)
            }
        ]))
    }

    private func spawnObstacle() {
        guard currentState == .playing, playArea.width > 80, !bossActive else { return }

        let kind = GameRules.obstacleKind(
            elapsed: runElapsed,
            roll: Int.random(in: 0...99)
        )
        let inset: CGFloat = 58
        let laneInset = GameRules.isInOpeningGrace(elapsed: runElapsed) ? inset + 36 : inset
        let startX = CGFloat.random(in: playArea.minX + laneInset...playArea.maxX - laneInset)
        let endX: CGFloat
        if GameRules.isInOpeningGrace(elapsed: runElapsed) {
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
        node.colorBlendFactor = 0
        let radius = GameRules.obstacleHitRadius(for: kind, spriteSize: node.size, scale: node.xScale)
        node.obstacleKind = kind
        node.obstacleHP = kind.hitsToDestroy
        node.hitRadius = radius
        node.attachCirclePhysics(
            radius: radius,
            category: GameConstants.PhysicsCategory.enemy,
            contact: GameConstants.PhysicsCategory.player | GameConstants.PhysicsCategory.bullet
        )
        addChild(node)
        liveEnemies.append(node)

        if kind == .mine {
            AudioManager.play(.mine)
            node.run(.repeatForever(.sequence([
                .scale(to: kind.scale * 1.08, duration: 0.45),
                .scale(to: kind.scale, duration: 0.45)
            ])))
        } else {
            let spin = CGFloat.random(in: 0.6...1.4) * (Bool.random() ? 1 : -1)
            node.run(.repeatForever(.rotate(byAngle: spin, duration: 1.0)))
        }

        let duration = kind.travelDuration * (GameRules.isInOpeningGrace(elapsed: runElapsed) ? 1.25 : 1.0)
        node.run(.sequence([
            .move(to: end, duration: duration),
            .run { [weak self] in self?.lostALife(fromContact: false) },
            .run { [weak self, weak node] in
                guard let self, let node else { return }
                self.untrack(node, from: &self.liveEnemies)
                self.obstaclePool.recycle(node)
            }
        ]))
    }

    private func clearRegularObstacles() {
        let enemies = liveEnemies
        for enemy in enemies {
            guard enemy !== bossNode else { continue }
            enemy.removeAllActions()
            untrack(enemy, from: &liveEnemies)
            obstaclePool.recycle(enemy)
        }
    }

    private func spawnBoss() {
        guard currentState == .playing, playArea.width > 80 else { return }

        removeAction(forKey: "spawningEnemies")
        clearRegularObstacles()
        bossActive = true
        bossVulnerable = false
        bossSpawnedAt = runElapsed

        let kind = GameConstants.ObstacleKind.boss
        let node = obstaclePool.checkout()
        node.texture = TextureCache.texture(kind.rawValue)
        let texSize = node.texture?.size() ?? CGSize(width: 160, height: 160)
        node.size = texSize
        node.setScale(kind.scale)
        node.name = GameConstants.NodeName.boss
        node.position = CGPoint(x: playArea.midX, y: playArea.maxY + 180)
        node.zPosition = GameConstants.Z.enemy + 1
        node.alpha = 1
        node.zRotation = .pi
        node.color = SKColor(red: 0.85, green: 0.22, blue: 0.55, alpha: 1)
        node.colorBlendFactor = 0.35
        let radius = GameRules.obstacleHitRadius(for: kind, spriteSize: node.size, scale: node.xScale)
        node.obstacleKind = kind
        node.obstacleHP = kind.hitsToDestroy
        node.hitRadius = radius
        node.attachCirclePhysics(
            radius: radius,
            category: GameConstants.PhysicsCategory.enemy,
            contact: GameConstants.PhysicsCategory.player | GameConstants.PhysicsCategory.bullet
        )
        addChild(node)
        liveEnemies.append(node)
        bossNode = node

        bossHealthBar.show(maxHP: GameRules.bossMaxHP)
        hud.setStatus("Boss Incoming")
        hud.pulseStatus()

        node.alpha = 0.82
        node.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.62, duration: 0.4),
            .fadeAlpha(to: 0.82, duration: 0.4)
        ])), withKey: "bossInvulnPulse")

        let hoverY = playArea.minY + playArea.height * 0.58
        node.run(.sequence([
            .moveTo(y: hoverY, duration: GameRules.bossDescentDuration),
            .repeatForever(.sequence([
                .moveBy(x: 28, y: 0, duration: 1.4),
                .moveBy(x: -56, y: 0, duration: 2.8),
                .moveBy(x: 28, y: 0, duration: 1.4)
            ]))
        ]))

        node.run(.repeatForever(.sequence([
            .wait(forDuration: GameRules.bossFireInterval),
            .run { [weak self] in self?.fireBossVolley() }
        ])), withKey: "bossFire")

        showStatusBanner(text: "BOSS INCOMING", color: SKColor(red: 1, green: 0.45, blue: 0.35, alpha: 1))
        AudioManager.play(.mine)
    }

    private func fireBossVolley() {
        guard bossActive, bossVulnerable, let boss = bossNode, boss.parent != nil, currentState == .playing else { return }
        guard liveFireballs.count < 8 else { return }

        let shots = Bool.random() ? 1 : 2
        for i in 0..<shots {
            let spread = CGFloat(i) * 44 - CGFloat(shots - 1) * 22
            fireBossFireball(from: boss.position, targetX: player.position.x + spread)
        }
    }

    private func fireBossFireball(from origin: CGPoint, targetX: CGFloat) {
        let fireball = fireballPool.checkout()
        fireball.texture = TextureCache.texture(GameConstants.fireballImage)
        fireball.setScale(GameRules.fireballScale)
        fireball.name = GameConstants.NodeName.fireball
        fireball.position = CGPoint(x: origin.x, y: origin.y - 60)
        fireball.zPosition = GameConstants.Z.enemyProjectile
        fireball.zRotation = .pi * 0.5
        fireball.color = SKColor(red: 1, green: 0.55, blue: 0.12, alpha: 1)
        fireball.colorBlendFactor = 0.55
        let radius = fireball.size.width * fireball.xScale * 0.34
        fireball.hitRadius = radius
        fireball.attachCirclePhysics(
            radius: radius,
            category: GameConstants.PhysicsCategory.enemyProjectile,
            contact: GameConstants.PhysicsCategory.player
        )
        addChild(fireball)
        liveFireballs.append(fireball)

        let clampedTargetX = GameRules.clampPlayerX(
            x: targetX,
            playMinX: playArea.minX,
            playMaxX: playArea.maxX,
            halfWidth: radius
        )
        let end = CGPoint(x: clampedTargetX, y: playArea.minY - 80)
        let distance = hypot(end.x - fireball.position.x, end.y - fireball.position.y)
        let duration = TimeInterval(distance / GameRules.fireballSpeed)

        fireball.run(.sequence([
            .move(to: end, duration: duration),
            .run { [weak self, weak fireball] in
                guard let self, let fireball else { return }
                self.recycleFireball(fireball)
            }
        ]))
    }

    private func recycleFireball(_ node: PooledSprite) {
        untrack(node, from: &liveFireballs)
        fireballPool.recycle(node)
    }

    private func clearFireballs() {
        let shots = liveFireballs
        for shot in shots {
            shot.removeAllActions()
            recycleFireball(shot)
        }
    }

    private func onBossDefeated(at position: CGPoint) {
        bossActive = false
        bossVulnerable = false
        bossNode = nil
        bossHealthBar.hideBar()
        clearFireballs()
        spawnExplosion(at: position, image: "explosion", scale: 1.6)
        showStatusBanner(text: "BOSS DEFEATED", color: SKColor(red: 0.35, green: 0.95, blue: 0.55, alpha: 1))
        HapticManager.upgrade()
        updateHUD()
        scheduleNextObstacle()
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
        AudioManager.play(.explosion)

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
        AudioManager.play(.star)
        spawnExplosion(at: position, image: "mini_explosion", scale: 0.85)

        if outcome.activated {
            bulletImageName = GameConstants.poweredBulletImage
            fireDelay = GameConstants.poweredFireDelay
            poweredShotsRemaining = outcome.poweredShots
            HapticManager.upgrade()
            AudioManager.play(.boost)
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
        AudioManager.play(.star)
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
        let sprite = node as? PooledSprite
        let kind = sprite?.obstacleKind ?? .asteroid

        if kind == .boss && !bossVulnerable {
            spawnExplosion(at: blastPoint, image: "mini_explosion", scale: 0.35)
            return
        }

        let hp = max(0, (sprite?.obstacleHP ?? 1) - 1)
        sprite?.obstacleHP = hp

        if kind == .boss {
            bossHealthBar.setHP(current: hp, maximum: GameRules.bossMaxHP)
            bossHealthBar.pulseDamage()
        }

        if hp > 0 {
            node.run(.sequence([
                .scale(to: kind.scale * 1.15, duration: 0.06),
                .scale(to: kind.scale, duration: 0.08)
            ]))
            spawnExplosion(at: blastPoint, image: "mini_explosion", scale: kind == .boss ? 0.75 : 0.55)
            HapticManager.enemyDestroyed()
            return
        }

        if kind == .boss {
            if let sprite {
                untrack(sprite, from: &liveEnemies)
                obstaclePool.recycle(sprite)
            } else {
                node.removeFromParent()
            }
            spawnExplosion(at: blastPoint, image: "explosion", scale: 1.45)
            HapticManager.enemyDestroyed()
            addScore(kind.points)
            onBossDefeated(at: blastPoint)
            return
        }

        destroyObstacle(node, blastPoint: blastPoint, points: kind.points)
    }

    private func destroyObstacle(_ node: SKNode, blastPoint: CGPoint, points: Int) {
        if let sprite = node as? PooledSprite {
            untrack(sprite, from: &liveEnemies)
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
            if let pooled = enemyNode as? PooledSprite, pooled.obstacleKind == .boss {
                spawnExplosion(at: pooled.position, image: "mini_explosion", scale: 0.95)
                lostALife(fromContact: true)
                return
            }
            if let position = enemyNode?.position {
                spawnExplosion(at: position, image: "explosion", scale: 1.15)
            }
            if let enemy = enemyNode as? PooledSprite {
                untrack(enemy, from: &liveEnemies)
                obstaclePool.recycle(enemy)
            } else {
                enemyNode?.removeFromParent()
            }
            lostALife(fromContact: true)
            return
        }

        if combined == (GameConstants.PhysicsCategory.player | GameConstants.PhysicsCategory.enemyProjectile) {
            guard !isInvulnerable else { return }
            let fireballNode = maskA == GameConstants.PhysicsCategory.enemyProjectile ? contact.bodyA.node : contact.bodyB.node
            if let position = fireballNode?.position {
                spawnExplosion(at: position, image: "mini_explosion", scale: 0.85)
            }
            if let fireball = fireballNode as? PooledSprite {
                recycleFireball(fireball)
            } else {
                fireballNode?.removeFromParent()
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
            let hitRadius = colliderRadius(forPickup: pickupNode)
            guard pickupNode.position.y - hitRadius < visibleMaxY else { return }

            let point = pickupNode.position
            recycleProjectile(bulletNode)
            collectPickup(pickupNode, at: point)
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
        guard let bullet = node as? PooledSprite else {
            node?.removeFromParent()
            return
        }
        untrack(bullet, from: &liveBullets)
        bulletPool.recycle(bullet)
    }

    private func recyclePickup(_ node: PooledSprite) {
        untrack(node, from: &livePickups)
        pickupPool.recycle(node)
    }

    private func collectPickup(_ node: SKNode, at point: CGPoint) {
        let pooled = node as? PooledSprite
        let kind = pooled?.powerUpKind
            ?? (node.name == GameConstants.NodeName.healthPickup ? .health : .star)
        if let pooled {
            recyclePickup(pooled)
        } else {
            node.removeFromParent()
        }
        switch kind {
        case .star:
            collectStar(at: point)
        case .health:
            collectHealth(at: point)
        }
    }

    private func untrack(_ node: SKNode, from list: inout [PooledSprite]) {
        if let index = list.firstIndex(where: { $0 === node }) {
            list.swapAt(index, list.count - 1)
            list.removeLast()
        }
    }

    private func colliderRadius(forEnemy node: SKNode) -> CGFloat {
        if let pooled = node as? PooledSprite, pooled.hitRadius > 0 {
            return pooled.hitRadius
        }
        let kind = (node as? PooledSprite)?.obstacleKind ?? .asteroid
        if let sprite = node as? SKSpriteNode {
            return GameRules.obstacleHitRadius(for: kind, spriteSize: sprite.size, scale: sprite.xScale)
        }
        return 80
    }

    private func colliderRadius(forPickup node: SKNode) -> CGFloat {
        if let pooled = node as? PooledSprite, pooled.hitRadius > 0 {
            return pooled.hitRadius
        }
        return node.frame.width * 0.5
    }

    private func isColliderOnscreen(_ node: SKNode, radius: CGFloat) -> Bool {
        node.position.y - radius < visibleMaxY
    }

    private func resolveSweptProjectileHits() {
        var index = 0
        while index < liveBullets.count {
            let bullet = liveBullets[index]
            guard bullet.parent != nil else {
                liveBullets.remove(at: index)
                continue
            }
            let start = bullet.lastPosition
            let end = bullet.position
            bullet.lastPosition = end
            if applySweptHit(bullet: bullet, start: start, end: end) {
                continue
            }
            index += 1
        }
    }

    private func applySweptHit(bullet: PooledSprite, start: CGPoint, end: CGPoint) -> Bool {
        for enemy in liveEnemies {
            guard enemy.parent != nil else { continue }
            let radius = colliderRadius(forEnemy: enemy)
            guard isColliderOnscreen(enemy, radius: radius) else { continue }
            if GameRules.projectileHitsTarget(
                start: start,
                end: end,
                projectileRadius: GameRules.bulletHitRadius,
                target: enemy.position,
                targetRadius: radius
            ) {
                recycleProjectile(bullet)
                damageObstacle(enemy, blastPoint: enemy.position)
                return true
            }
        }

        for pickup in livePickups {
            guard pickup.parent != nil else { continue }
            let radius = colliderRadius(forPickup: pickup)
            if GameRules.projectileHitsTarget(
                start: start,
                end: end,
                projectileRadius: GameRules.bulletHitRadius,
                target: pickup.position,
                targetRadius: radius
            ) {
                recycleProjectile(bullet)
                collectPickup(pickup, at: pickup.position)
                return true
            }
        }

        return false
    }
}
