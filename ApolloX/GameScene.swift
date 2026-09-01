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
    private let player = SKSpriteNode()
    private var engineEmitter: SKEmitterNode?
    private var engineFlame: SKNode?

    private var lives = GameRules.startingLives
    private var killCombo = 0
    private var level = 0
    private var starCharge = 0
    private var poweredShotsRemaining = 0
    private var fireDelay = GameConstants.baseFireDelay
    private var bulletImageName = GameConstants.bulletImage
    private var equippedPrimaryID = PrimaryWeaponID.pulseLaser
    private var equippedSpecialID = SpecialWeaponID.plasmaGrenade
    private var specialReadyAt: TimeInterval = 0
    private let specialButton = SpecialWeaponButton()
    private var currentState: State = .playing
    private var playArea = CGRect.zero
    /// True after the app actually enters the background (home switch), not screenshot/Control Center.
    private var requiresManualResume = false
    private var isPausedBySystem = false
    private var isInvulnerable = false
    private var runElapsed: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var lastFrameDelta: TimeInterval = 1.0 / 60.0
    private var bossesSpawnedCount = 0
    private var bossesDefeatedCount = 0
    private var currentBossMaxHP = GameRules.bossMaxHP
    private var currentBossPoints = GameRules.bossPoints
    private var bossActive = false
    private var bossVulnerable = false
    private var bossSpawnedAt: TimeInterval = 0
    private var nextBossSpawnAt: TimeInterval = GameRules.firstBossSpawnTime()
    private var bossNode: PooledSprite?
    private var activeBossProfile: GameRules.BossProfile?
    private var bossVolleyIndex = 0
    /// Soft gravity well (gentle lateral pull) while active.
    private var softGravityUntil: TimeInterval = 0
    private var softGravityCenter = CGPoint.zero
    /// Soft time warp — boss projectiles play actions slower while active.
    private var softTimeWarpUntil: TimeInterval = 0
    private var gravityWellFX: SKSpriteNode?
    private var backgroundTier = -1
    private var scrollingBackground: ScrollingBackgroundNode?
    /// Cached so swept tests do not rebuild `PlayfieldLayout` every pair.
    private var visibleMaxY: CGFloat = 0
    /// Touch X target applied once per frame in `update(_:)` for smoother steering.
    private var steeringTouchX: CGFloat?

    private struct PlayerXSample {
        let time: TimeInterval
        let x: CGFloat
    }

    /// Rolling history so rockets can target where the player was ~2s ago.
    private var playerXHistory: [PlayerXSample] = []
    private var rocketSequenceCounter = 0
    private var pendingRocketAudio = false
    /// Obstacle spawns hold until this run timestamp after a yellow clear-mine detonation.
    private var obstacleSpawnPausedUntil: TimeInterval = 0

    private var pauseOverlay: SKNode?
    private var resumeButton: MenuButtonNode?
    private var menuButton: MenuButtonNode?
    private var gameplayFrozen = false

    private var liveBullets: [PooledSprite] = []
    private var liveEnemies: [PooledSprite] = []
    private var livePickups: [PooledSprite] = []
    private var liveFireballs: [PooledSprite] = []
    private var liveRockets: [PooledSprite] = []
    private var liveSpecials: [PooledSprite] = []

    private lazy var bulletPool = NodePool(prewarm: 18, maxIdle: 28) {
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
    private lazy var fireballPool = NodePool(prewarm: 16, maxIdle: 28) {
        PooledSprite(texture: TextureCache.texture(GameConstants.fireballImage))
    }
    private lazy var rocketPool = NodePool(prewarm: 6, maxIdle: 12) {
        PooledSprite(texture: TextureCache.texture(GameConstants.rocketImage))
    }
    private lazy var specialPool = NodePool(prewarm: 4, maxIdle: 8) {
        PooledSprite(texture: TextureCache.texture(WeaponTextures.plasmaGrenade))
    }

    override init(size: CGSize) {
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        FramePacing.setOverlayFrameCapActive(false)
    }

    override func didMove(to view: SKView) {
        ScoreStore.resetCurrentScore()
        HapticManager.prepare()
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = .zero

        scrollingBackground = addProductionBackground()
        GameplayTextures.registerProceduralTextures()
        WeaponCatalog.registerTextures()
        addChild(hud)
        addChild(bossHealthBar)
        addChild(specialButton)
        configureLoadout()
        configurePlayer()
        relayoutForSafeArea()
        whenSafeAreaReady { [weak self] in
            self?.relayoutForSafeArea()
        }

        beginLevel()
        startSpawning()
        registerLifecycleObservers()
        updateHUD()
        refreshParticleRates()
        refreshSpecialButton()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        relayoutForSafeArea()
    }

    override func update(_ currentTime: TimeInterval) {
        // Frozen / paused frames must not advance run time or scroll — that was the
        // main post-pause hitch (Control Center kept ticking while sprites were frozen).
        guard currentState == .playing, !isPausedBySystem, !gameplayFrozen else {
            lastUpdateTime = currentTime
            return
        }
        if lastUpdateTime > 0 {
            let rawDelta = currentTime - lastUpdateTime
            FramePacing.reportFrameDuration(rawDelta)
            let delta = FramePacing.clampedDelta(rawDelta)
            runElapsed += delta
            scrollingBackground?.tick(deltaTime: delta)
            lastFrameDelta = delta

            let tier = GameRules.spawnTier(elapsed: runElapsed)
            if tier != backgroundTier {
                backgroundTier = tier
                updateBackgroundTier(tier, animated: tier > 0)
            }
        } else {
            lastFrameDelta = 1.0 / TimeInterval(max(FramePacing.currentFramesPerSecond, 30))
        }
        lastUpdateTime = currentTime

        if GameRules.shouldSpawnBoss(
            elapsed: runElapsed,
            bossesSpawned: bossesSpawnedCount,
            bossActive: bossActive,
            nextBossSpawnAt: nextBossSpawnAt
        ) {
            spawnBoss()
        }

        updateBossVulnerability()
        applyPlayerSteering()
        applySoftBossEffects()
        recordPlayerXHistory()
        updateSpecialProjectiles(delta: lastFrameDelta)
        refreshSpecialCooldownUI()
    }

    private func applySoftBossEffects() {
        guard currentState == .playing else { return }

        if runElapsed < softGravityUntil {
            let dx = softGravityCenter.x - player.position.x
            let distance = abs(dx)
            if distance > 4, distance < GameRules.softGravityRadius {
                let falloff = 1 - (distance / GameRules.softGravityRadius)
                let pull = GameRules.softGravityStrength * falloff * CGFloat(min(lastFrameDelta, 0.05))
                let halfWidth = player.size.width * player.xScale * 0.45
                let nudged = player.position.x + (dx > 0 ? pull : -pull)
                player.position.x = GameRules.clampPlayerX(
                    x: nudged,
                    playMinX: playArea.minX,
                    playMaxX: playArea.maxX,
                    halfWidth: halfWidth
                )
            }
        } else if gravityWellFX != nil {
            clearGravityWellFX()
        }

        let warpActive = runElapsed < softTimeWarpUntil
        let factor: CGFloat = warpActive ? GameRules.softTimeWarpFactor : 1
        for shot in liveFireballs where abs(shot.speed - factor) > 0.01 {
            shot.speed = factor
        }
    }

    private func activateSoftGravity(at point: CGPoint) {
        softGravityCenter = point
        softGravityUntil = runElapsed + GameRules.softGravityDuration
        clearGravityWellFX()

        let fx = SKSpriteNode(texture: TextureCache.texture(BossAttackTextures.gravityWell))
        fx.size = CGSize(width: 120, height: 120)
        fx.position = point
        fx.zPosition = GameConstants.Z.effect
        fx.alpha = 0.85
        fx.setScale(0.6)
        addChild(fx)
        gravityWellFX = fx
        fx.run(.repeatForever(.sequence([
            .group([
                .scale(to: 1.15, duration: 0.55),
                .fadeAlpha(to: 0.45, duration: 0.55)
            ]),
            .group([
                .scale(to: 0.7, duration: 0.55),
                .fadeAlpha(to: 0.85, duration: 0.55)
            ])
        ])))
        fx.run(.sequence([
            .wait(forDuration: GameRules.softGravityDuration),
            .fadeOut(withDuration: 0.2),
            .run { [weak self] in self?.clearGravityWellFX() }
        ]))
    }

    private func clearGravityWellFX() {
        gravityWellFX?.removeAllActions()
        gravityWellFX?.removeFromParent()
        gravityWellFX = nil
    }

    private func activateSoftTimeWarp(at point: CGPoint) {
        softTimeWarpUntil = runElapsed + GameRules.softTimeWarpDuration
        for shot in liveFireballs {
            shot.speed = GameRules.softTimeWarpFactor
        }

        let fx = SKSpriteNode(texture: TextureCache.texture(BossAttackTextures.timeWarpOrb))
        fx.size = CGSize(width: 110, height: 110)
        fx.position = point
        fx.zPosition = GameConstants.Z.effect
        fx.alpha = 0.8
        addChild(fx)
        fx.run(.sequence([
            .group([
                .scale(to: 1.35, duration: 0.35),
                .fadeAlpha(to: 0.35, duration: 0.35)
            ]),
            .wait(forDuration: GameRules.softTimeWarpDuration - 0.55),
            .fadeOut(withDuration: 0.25),
            .removeFromParent()
        ]))
    }

    private func recordPlayerXHistory() {
        guard currentState == .playing, player.parent != nil else { return }
        playerXHistory.append(PlayerXSample(time: runElapsed, x: player.position.x))
        let cutoff = runElapsed - (GameRules.rocketTargetLookback + 1.0)
        // One range delete instead of repeated removeFirst shifts every frame.
        if let keepFrom = playerXHistory.firstIndex(where: { $0.time >= cutoff }) {
            if keepFrom > 0 {
                playerXHistory.removeFirst(keepFrom)
            }
        } else if !playerXHistory.isEmpty {
            playerXHistory.removeAll(keepingCapacity: true)
        }
    }

    private func playerX(atLookback lookback: TimeInterval) -> CGFloat {
        let targetTime = runElapsed - lookback
        guard !playerXHistory.isEmpty else { return player.position.x }

        if targetTime <= playerXHistory[0].time {
            return playerXHistory[0].x
        }
        if let last = playerXHistory.last, targetTime >= last.time {
            return last.x
        }

        for index in 1..<playerXHistory.count {
            let previous = playerXHistory[index - 1]
            let next = playerXHistory[index]
            guard previous.time <= targetTime, next.time >= targetTime else { continue }
            let span = next.time - previous.time
            guard span > 0.0001 else { return previous.x }
            let blend = (targetTime - previous.time) / span
            return previous.x + CGFloat(blend) * (next.x - previous.x)
        }
        return player.position.x
    }

    private func clampedRocketLaneX(_ x: CGFloat) -> CGFloat {
        let laneHalf = player.size.width * player.xScale * 0.45
        return GameRules.clampPlayerX(
            x: x,
            playMinX: playArea.minX,
            playMaxX: playArea.maxX,
            halfWidth: laneHalf
        )
    }

    private func applyPlayerSteering() {
        guard let targetX = steeringTouchX else { return }
        let halfWidth = player.size.width * player.xScale * 0.45
        player.position.x = GameRules.clampPlayerX(
            x: targetX,
            playMinX: playArea.minX,
            playMaxX: playArea.maxX,
            halfWidth: halfWidth
        )
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
        guard currentState == .playing, !isPausedBySystem, !gameplayFrozen else { return }
        resolveSweptProjectileHits()
    }

    // MARK: - Layout

    private func relayoutForSafeArea() {
        let layout = playfield
        playArea = layout.safeRect
        visibleMaxY = layout.visibleRect.maxY
        relayoutProductionBackground()
        hud.layout(in: layout.safeRect)
        bossHealthBar.layout(in: layout.safeRect, below: 156)
        specialButton.layout(in: layout.safeRect)

        if player.parent != nil {
            player.position.x = GameRules.clampPlayerX(
                x: player.position.x,
                playMinX: playArea.minX,
                playMaxX: playArea.maxX,
                halfWidth: player.size.width * player.xScale * 0.45
            )
            player.position.y = GameRules.playerBaselineY(
                playMinY: playArea.minY,
                scaledHeight: player.size.height * player.yScale
            )
        }

        if let overlay = pauseOverlay {
            overlay.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            resumeButton?.position = CGPoint(x: 0, y: -40)
        }
    }

    private func configureLoadout() {
        equippedPrimaryID = WeaponCatalog.primaryID(PlayerProgress.equippedPrimaryWeaponId)
        equippedSpecialID = WeaponCatalog.specialID(PlayerProgress.equippedSpecialWeaponId)
        let primary = GameRules.primaryProfile(for: equippedPrimaryID)
        fireDelay = primary.fireDelay
        bulletImageName = primary.textureName
        specialReadyAt = 0
    }

    private func configurePlayer() {
        let ship = PlayerProgress.equippedShip()
        player.texture = TextureCache.texture(ship.textureName)
        if let texSize = player.texture?.size(), texSize.width > 0 {
            player.size = texSize
        }
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
        engine.particleColor = ship.engineColor
        // Sit at the nozzle line so the particle trail starts where flames begin.
        engine.position = CGPoint(x: 0, y: -player.size.height * 0.48)
        engine.zPosition = 2
        player.addChild(engine)
        engineEmitter = engine

        let flame = makeEngineFlameNode(tint: ship.engineColor)
        // Anchor just above the bottom of the hull so tongues extend clearly past the ship.
        flame.position = CGPoint(x: 0, y: -player.size.height * 0.46)
        flame.setScale(1.35)
        player.addChild(flame)
        engineFlame = flame
    }

    private func updateHUD() {
        hud.setScore(ScoreStore.currentScore)
        hud.setHighScore(ScoreStore.highScore)
        hud.setCombo(killCombo)
        hud.setLives(lives)
        if poweredShotsRemaining > 0 {
            hud.setStatus("Boost • \(PlayerProgress.equippedPrimary().name)")
        } else if GameRules.starsNeededForUpgrade > 1, starCharge > 0 {
            hud.setStatus("Stars: \(starCharge)/\(GameRules.starsNeededForUpgrade)")
        } else {
            hud.setStatus(PlayerProgress.equippedPrimary().name)
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
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
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
        refreshParticleRates()
    }

    private func refreshParticleRates() {
        let quality = FramePacing.currentQuality
        let engineRate = FramePacing.scaledBirthRate(quality.engineBirthRate)
        engineEmitter?.particleBirthRate = engineRate
        engineEmitter?.isHidden = quality.engineBirthRate <= 0
        engineEmitter?.isPaused = gameplayFrozen || quality.engineBirthRate <= 0
        let dustRate = bossActive ? 0 : FramePacing.scaledBirthRate(quality.starDustBirthRate)
        applyPerformanceQuality(starDustRate: dustRate)
        if let dust = childNode(withName: GameConstants.NodeName.starDust) as? SKEmitterNode {
            dust.isPaused = gameplayFrozen || dustRate <= 0
        }
        scrollingBackground?.applyEffectsQuality(quality)
    }

    private var bossProjectileCap: Int {
        FramePacing.currentQuality.maxBossProjectiles
    }

    @objc private func appWillResignActive() {
        guard currentState == .playing, !requiresManualResume else { return }
        freezeGameplay()
    }

    @objc private func appDidEnterBackground() {
        requiresManualResume = true
        isPausedBySystem = true
        if currentState == .playing {
            enterPause(showOverlay: true, fromSystem: true)
        } else if currentState == .paused {
            freezeGameplay()
        } else if currentState != .gameOver {
            freezeGameplay()
        }
    }

    @objc private func appDidBecomeActive() {
        isPausedBySystem = false
        if requiresManualResume {
            if currentState == .paused {
                freezeGameplay()
            }
            // Stay on the overlay cap until the player taps Resume.
            return
        }
        if currentState == .playing {
            unfreezeGameplay()
        }
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
        scheduleNextRocket()
        scheduleNextClearMine()
    }

    private func scheduleNextObstacle() {
        removeAction(forKey: "spawningEnemies")
        guard !bossActive else { return }
        let intervalDelay = GameRules.spawnInterval(elapsed: runElapsed)
        let pauseRemaining = max(0, obstacleSpawnPausedUntil - runElapsed)
        let delay = max(intervalDelay, pauseRemaining)
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self, self.currentState == .playing, !self.bossActive else { return }
                if self.runElapsed < self.obstacleSpawnPausedUntil {
                    self.scheduleNextObstacle()
                    return
                }
                self.spawnObstacle()
                self.scheduleNextObstacle()
            }
        ]), withKey: "spawningEnemies")
    }

    private func scheduleNextClearMine() {
        removeAction(forKey: "spawningClearMine")
        guard currentState == .playing else { return }
        let delay = GameRules.clearMineSpawnInterval(elapsed: runElapsed, bossActive: bossActive)
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self, self.currentState == .playing else { return }
                if GameRules.shouldSpawnClearMine(
                    elapsed: self.runElapsed,
                    bossActive: self.bossActive,
                    roll: Int.random(in: 0..<100)
                ) {
                    self.spawnClearMine()
                }
                self.scheduleNextClearMine()
            }
        ]), withKey: "spawningClearMine")
    }

    private func schedulePowerUps() {
        removeAction(forKey: "spawningPowerUp")
        let initialDelay = max(0, GameRules.openingPowerUpDelay - runElapsed)
        run(.sequence([
            .wait(forDuration: initialDelay),
            .run { [weak self] in self?.scheduleNextStarPickup() }
        ]), withKey: "spawningPowerUp")
    }

    private func scheduleNextStarPickup() {
        guard currentState == .playing else { return }
        let delay = GameRules.starPickupSpawnInterval(elapsed: runElapsed)
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self, self.currentState == .playing else { return }
                if GameRules.shouldSpawnStar(
                    elapsed: self.runElapsed,
                    roll: Int.random(in: 0..<100)
                ) {
                    self.spawnPowerUp()
                }
                self.scheduleNextStarPickup()
            }
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

    private func scheduleNextRocket() {
        removeAction(forKey: "spawningRockets")
        guard currentState == .playing, !bossActive else { return }

        let delay: TimeInterval
        if !GameRules.shouldSpawnRockets(elapsed: runElapsed, bossActive: false) {
            delay = max(0.5, GameRules.rocketFirstSpawnDelay - runElapsed)
        } else {
            delay = GameRules.rocketSpawnInterval(elapsed: runElapsed)
        }

        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self, self.currentState == .playing, !self.bossActive else { return }
                guard GameRules.shouldSpawnRockets(elapsed: self.runElapsed, bossActive: false) else {
                    self.scheduleNextRocket()
                    return
                }
                self.beginRocketWave()
                self.scheduleNextRocket()
            }
        ]), withKey: "spawningRockets")
    }

    private func beginRocketWave() {
        guard currentState == .playing, !bossActive else { return }
        let waveSize = GameRules.rocketsPerWave(elapsed: runElapsed)
        let headroom = GameRules.maxConcurrentRockets - liveRockets.count
        guard headroom > 0 else { return }
        let count = min(waveSize, headroom)

        for index in 0..<count {
            let delay = Double(index) * GameRules.rocketWaveStagger
            run(.sequence([
                .wait(forDuration: delay),
                .run { [weak self] in
                    guard let self, self.currentState == .playing, !self.bossActive else { return }
                    guard self.liveRockets.count < GameRules.maxConcurrentRockets else { return }
                    self.beginRocketSequence()
                }
            ]))
        }
    }

    private func beginRocketSequence() {
        guard currentState == .playing, !bossActive else { return }
        guard liveRockets.count < GameRules.maxConcurrentRockets else { return }

        let targetX = clampedRocketLaneX(playerX(atLookback: GameRules.rocketTargetLookback))

        showRocketWarning(at: targetX)
        rocketSequenceCounter += 1
        let sequenceKey = "rocketSequence-\(rocketSequenceCounter)"
        run(.sequence([
            .wait(forDuration: GameRules.rocketWarningDuration),
            .run { [weak self] in
                guard let self, self.currentState == .playing else { return }
                self.spawnFallingRocket(at: targetX)
            }
        ]), withKey: sequenceKey)
    }

    private func showRocketWarning(at columnX: CGFloat) {
        let warning = RocketWarningNode(columnX: columnX, playArea: playArea)
        addChild(warning)
        warning.playFlash(
            duration: GameRules.rocketWarningDuration,
            interval: GameRules.rocketWarningFlashInterval
        )
        if !pendingRocketAudio {
            pendingRocketAudio = true
            AudioManager.play(.rocketWarning)
            run(.sequence([
                .wait(forDuration: 0.12),
                .run { [weak self] in self?.pendingRocketAudio = false }
            ]))
        }
        HapticManager.fire()
    }

    private func spawnFallingRocket(at columnX: CGFloat) {
        let rocket = rocketPool.checkout()
        rocket.childNode(withName: "rocketTailSmoke")?.removeFromParent()
        rocket.texture = TextureCache.texture(GameConstants.rocketImage)
        rocket.setScale(GameRules.rocketScale)
        rocket.name = GameConstants.NodeName.rocket
        rocket.position = CGPoint(x: columnX, y: playArea.maxY + 120)
        rocket.zPosition = GameConstants.Z.enemyProjectile + 1
        rocket.zRotation = 0
        rocket.colorBlendFactor = 0
        let radius = min(rocket.size.width, rocket.size.height) * rocket.xScale * GameRules.rocketHitboxFactor
        rocket.hitRadius = radius
        rocket.attachCirclePhysics(
            radius: radius,
            category: GameConstants.PhysicsCategory.enemyProjectile,
            contact: GameConstants.PhysicsCategory.player
        )

        let smoke = makeRocketTailSmokeEmitter()
        if let smoke {
            smoke.name = "rocketTailSmoke"
            // Texture is nose-down: exhaust / smoke emits from the tail near the top.
            smoke.position = CGPoint(x: 0, y: rocket.size.height * 0.46)
            smoke.zPosition = -1
            rocket.addChild(smoke)
        }

        addChild(rocket)
        liveRockets.append(rocket)

        let end = CGPoint(x: columnX, y: playArea.minY - 80)
        let distance = hypot(end.x - rocket.position.x, end.y - rocket.position.y)
        let speed = GameRules.rocketSpeed(forScore: ScoreStore.currentScore)
        let duration = TimeInterval(distance / speed)

        rocket.run(.sequence([
            .move(to: end, duration: duration),
            .run { [weak self, weak rocket] in
                guard let self, let rocket else { return }
                self.recycleRocket(rocket)
            }
        ]))
    }

    private func recycleRocket(_ node: PooledSprite) {
        node.childNode(withName: "rocketTailSmoke")?.removeFromParent()
        untrack(node, from: &liveRockets)
        rocketPool.recycle(node)
    }

    private func clearRockets() {
        let rockets = liveRockets
        for rocket in rockets {
            rocket.removeAllActions()
            recycleRocket(rocket)
        }
        for node in children where node.name == GameConstants.NodeName.rocketWarning {
            node.removeAllActions()
            node.removeFromParent()
        }
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

    private func registerKillCombo() {
        killCombo = GameRules.comboAfterKill(current: killCombo)
        hud.setCombo(killCombo)
        hud.pulseCombo()
    }

    private func lostALife(fromContact: Bool) {
        guard currentState == .playing else { return }
        let outcome = GameRules.resolvePlayerHit(lives: lives)
        lives = outcome.livesRemaining
        killCombo = GameRules.comboAfterPlayerHit()
        hud.setLives(lives)
        hud.setCombo(killCombo)
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
        if gameplayFrozen {
            gameplayFrozen = false
            speed = 1
            FramePacing.setOverlayFrameCapActive(false)
        }
        dismissPauseOverlay()
        HapticManager.gameOver()
        engineEmitter?.particleBirthRate = 0
        engineFlame?.isHidden = true
        engineFlame?.removeAllActions()

        removeAllActions()
        for sprite in liveBullets + liveEnemies + livePickups + liveFireballs + liveRockets + liveSpecials {
            sprite.removeAllActions()
        }
        bossNode?.removeAllActions()
        bossHealthBar.hideBar()

        ScoreStore.commitHighScoreIfNeeded()
        ScoreStore.commitWalletIfNeeded()
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
        steeringTouchX = nil
        currentState = .paused
        freezeGameplay()
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
        requiresManualResume = false
        dismissPauseOverlay()
        currentState = .playing
        unfreezeGameplay()
        AudioManager.play(.uiTap)
        HapticManager.fire()
    }

    private func freezeGameplay() {
        guard !gameplayFrozen else { return }
        gameplayFrozen = true
        // Scene speed freezes every SKAction (spawns, fire, delayed boss volleys)
        // in place so resume does not restart timers or dump a spawn wave.
        speed = 0
        player.isPaused = true
        engineEmitter?.isPaused = true
        setAmbientEmittersPaused(true)
        gravityWellFX?.isPaused = true
        for node in liveBullets + liveEnemies + livePickups + liveFireballs + liveRockets + liveSpecials {
            node.isPaused = true
        }
        bossNode?.isPaused = true
        FramePacing.setOverlayFrameCapActive(true)
    }

    private func unfreezeGameplay() {
        guard gameplayFrozen else { return }
        gameplayFrozen = false
        speed = 1
        player.isPaused = false
        gravityWellFX?.isPaused = false
        for node in liveBullets + liveEnemies + livePickups + liveFireballs + liveRockets + liveSpecials {
            node.isPaused = false
        }
        bossNode?.isPaused = false
        // Restore ProMotion / thermal target before the next played frame.
        FramePacing.setOverlayFrameCapActive(false)
        lastUpdateTime = 0
        refreshParticleRates()
    }

    private func setAmbientEmittersPaused(_ paused: Bool) {
        if let dust = childNode(withName: GameConstants.NodeName.starDust) as? SKEmitterNode {
            dust.isPaused = paused || dust.particleBirthRate <= 0
        }
        if paused {
            engineEmitter?.isPaused = true
        }
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
        title.position = CGPoint(x: 0, y: 120)
        title.zPosition = 1
        root.addChild(title)

        let resume = MenuButtonNode(title: "Resume", width: 440, height: 108, fontSize: 48, emphasized: true)
        resume.position = CGPoint(x: 0, y: -10)
        resume.zPosition = 1
        root.addChild(resume)

        let menu = MenuButtonNode(title: "Menu", width: 440, height: 96, fontSize: 40, emphasized: false)
        menu.position = CGPoint(x: 0, y: -140)
        menu.zPosition = 1
        root.addChild(menu)

        addChild(root)
        pauseOverlay = root
        resumeButton = resume
        menuButton = menu
    }

    private func dismissPauseOverlay() {
        pauseOverlay?.removeFromParent()
        pauseOverlay = nil
        resumeButton = nil
        menuButton = nil
    }

    private func exitToTitleFromPause() {
        guard currentState == .paused else { return }
        AudioManager.play(.uiTap)
        HapticManager.fire()
        if gameplayFrozen {
            gameplayFrozen = false
            speed = 1
        }
        FramePacing.setOverlayFrameCapActive(false)
        dismissPauseOverlay()
        presentScene(GameTitleScene(size: size))
    }

    private func fireBullet() {
        guard currentState == .playing, player.parent != nil else { return }

        let profile = GameRules.primaryProfile(for: equippedPrimaryID)
        let powered = poweredShotsRemaining > 0
        if powered {
            poweredShotsRemaining -= 1
            if poweredShotsRemaining == 0 {
                fireDelay = profile.fireDelay
                bulletImageName = profile.textureName
                refreshFireRate()
            }
        }

        let textureName = powered && equippedPrimaryID == .pulseLaser
            ? GameConstants.poweredBulletImage
            : profile.textureName
        let boltSize = powered && equippedPrimaryID == .pulseLaser
            ? GameRules.poweredBulletSize
            : profile.size
        let muzzle = CGPoint(
            x: player.position.x,
            y: player.position.y + player.size.height * player.yScale * 0.28
        )

        let count = max(1, profile.boltCount)
        for index in 0..<count {
            let bullet = bulletPool.checkout()
            bullet.texture = TextureCache.texture(textureName)
            bullet.size = boltSize
            bullet.name = GameConstants.NodeName.bullet
            bullet.position = muzzle
            bullet.zPosition = GameConstants.Z.bullet
            bullet.hitRadius = profile.hitRadius
            bullet.pierceRemaining = profile.pierceCount
            bullet.projectileDamage = profile.damage
            bullet.lastPosition = muzzle
            bullet.physicsBody = nil

            var angle: CGFloat = 0
            if count > 1 {
                let t = CGFloat(index) / CGFloat(count - 1)
                angle = -profile.spread * 0.5 + profile.spread * t
            }
            bullet.zRotation = -angle

            addChild(bullet)
            liveBullets.append(bullet)

            let dx = sin(angle)
            let dy = cos(angle)
            let travel = size.height - muzzle.y + 120
            let end = CGPoint(x: muzzle.x + dx * travel, y: muzzle.y + dy * travel)
            let distance = hypot(end.x - muzzle.x, end.y - muzzle.y)
            let duration = TimeInterval(distance / profile.bulletSpeed)
            bullet.run(.sequence([
                .move(to: end, duration: duration),
                .run { [weak self, weak bullet] in
                    guard let self, let bullet else { return }
                    self.recycleProjectile(bullet)
                }
            ]))
        }

        AudioManager.play(.laser)
    }

    private func fireSpecial() {
        guard currentState == .playing, !gameplayFrozen, player.parent != nil else { return }
        guard runElapsed >= specialReadyAt else { return }

        let profile = GameRules.specialProfile(for: equippedSpecialID)
        if liveSpecials.count >= min(profile.maxLive, GameRules.maxLiveSpecialProjectiles) {
            return
        }

        specialReadyAt = runElapsed + profile.cooldown
        specialButton.pulse()
        HapticManager.fire()
        AudioManager.play(.mine)

        switch equippedSpecialID {
        case .plasmaGrenade:
            launchPlasmaGrenade(profile: profile)
        case .seekerPod:
            launchSeekerPod(profile: profile)
        case .flakBurst:
            triggerFlakBurst(profile: profile)
        case .cooldownMine:
            dropCooldownMine(profile: profile)
        }
        refreshSpecialCooldownUI()
    }

    private func launchPlasmaGrenade(profile: GameRules.SpecialFireProfile) {
        let node = specialPool.checkout()
        configureSpecialNode(
            node,
            textureName: profile.textureName,
            size: CGSize(width: 72, height: 72),
            kind: .plasmaGrenade,
            damage: profile.damage,
            hitRadius: profile.aoeRadius,
            glowColor: SKColor(red: 0.45, green: 1.0, blue: 0.35, alpha: 0.55)
        )
        node.isArmed = true
        node.flightSpeed = GameRules.plasmaGrenadeFlightSpeed
        node.spawnedAt = runElapsed
        node.position = CGPoint(x: player.position.x, y: player.position.y + 40)
        node.lastPosition = node.position
        addChild(node)
        liveSpecials.append(node)

        node.run(.repeatForever(.sequence([
            .rotate(byAngle: .pi * 2, duration: 0.45),
            .rotate(byAngle: -.pi * 2, duration: 0.45)
        ])))
    }

    private func launchSeekerPod(profile: GameRules.SpecialFireProfile) {
        let node = specialPool.checkout()
        configureSpecialNode(
            node,
            textureName: profile.textureName,
            size: CGSize(width: 68, height: 68),
            kind: .seekerPod,
            damage: profile.damage,
            hitRadius: 30,
            glowColor: SKColor(red: 1.0, green: 0.45, blue: 0.85, alpha: 0.5)
        )
        node.flightSpeed = 700
        node.isArmed = true
        node.position = CGPoint(x: player.position.x, y: player.position.y + 36)
        node.lastPosition = node.position
        addChild(node)
        liveSpecials.append(node)

        node.run(.sequence([
            .wait(forDuration: profile.travelDuration),
            .run { [weak self, weak node] in
                guard let self, let node, node.parent != nil else { return }
                self.recycleSpecial(node)
            }
        ]))
    }

    private func triggerFlakBurst(profile: GameRules.SpecialFireProfile) {
        // Center the blast ahead of the ship — threats come from above.
        let origin = CGPoint(x: player.position.x, y: player.position.y + 110)
        spawnExplosion(at: origin, image: "explosion", scale: 1.45)
        let rings = FramePacing.currentQuality == .conservative ? 1 : 2
        for index in 0..<rings {
            let delay = Double(index) * 0.05
            run(.sequence([
                .wait(forDuration: delay),
                .run { [weak self] in
                    self?.spawnShockwaveRing(
                        at: origin,
                        startScale: 0.2,
                        endScale: 4.6 + CGFloat(index),
                        duration: 0.36,
                        color: SKColor(red: 1, green: 0.55, blue: 0.2, alpha: 0.9),
                        lineWidth: 6
                    )
                }
            ]))
        }

        let radius = profile.aoeRadius
        let radius2 = radius * radius
        for enemy in liveEnemies where enemy.parent != nil {
            let dx = enemy.position.x - origin.x
            let dy = enemy.position.y - origin.y
            guard dx * dx + dy * dy <= radius2 else { continue }
            damageObstacle(enemy, blastPoint: enemy.position, amount: profile.damage)
        }
        AudioManager.play(.explosion)
    }

    private func dropCooldownMine(profile: GameRules.SpecialFireProfile) {
        let node = specialPool.checkout()
        configureSpecialNode(
            node,
            textureName: profile.textureName,
            size: CGSize(width: 78, height: 78),
            kind: .cooldownMine,
            damage: profile.damage,
            hitRadius: profile.aoeRadius,
            glowColor: SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 0.5)
        )
        node.isArmed = false
        node.position = CGPoint(x: player.position.x, y: player.position.y + 20)
        node.lastPosition = node.position
        node.setScale(0.75)
        addChild(node)
        liveSpecials.append(node)

        // Hover in-lane ahead of the player so falling hazards run into it.
        let hoverY = min(playArea.maxY - 140, playArea.minY + playArea.height * 0.58)
        let hover = CGPoint(x: player.position.x, y: hoverY)
        let deployDuration: TimeInterval = 0.35
        node.run(.sequence([
            .group([
                .move(to: hover, duration: deployDuration),
                .scale(to: 1.0, duration: deployDuration)
            ]),
            .run { [weak node] in
                guard let node else { return }
                node.isArmed = true
                node.run(.repeatForever(.sequence([
                    .scale(to: 1.08, duration: 0.32),
                    .scale(to: 0.94, duration: 0.32)
                ])), withKey: "skyMinePulse")
            },
            .wait(forDuration: profile.travelDuration),
            .run { [weak self, weak node] in
                guard let self, let node, node.parent != nil else { return }
                self.detonateSpecial(node, at: node.position)
            }
        ]))

        // Readable arming radius (sprite ring, not SKShapeNode).
        if FramePacing.currentQuality != .conservative {
            let ring = SKSpriteNode(texture: TextureCache.texture(WeaponTextures.softGlow))
            ring.name = "skyMineRadius"
            ring.size = CGSize(width: profile.aoeRadius * 1.6, height: profile.aoeRadius * 1.6)
            ring.alpha = 0.22
            ring.zPosition = -1
            ring.blendMode = .add
            ring.color = SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
            ring.colorBlendFactor = 1
            node.addChild(ring)
            ring.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.12, duration: 0.45),
                .fadeAlpha(to: 0.28, duration: 0.45)
            ])))
        }
    }

    private func configureSpecialNode(
        _ node: PooledSprite,
        textureName: String,
        size: CGSize,
        kind: SpecialWeaponID,
        damage: Int,
        hitRadius: CGFloat,
        glowColor: SKColor
    ) {
        node.childNode(withName: "specialGlow")?.removeFromParent()
        node.childNode(withName: "skyMineRadius")?.removeFromParent()
        node.texture = TextureCache.texture(textureName)
        node.size = size
        node.name = GameConstants.NodeName.playerSpecial
        node.specialKind = kind
        node.projectileDamage = damage
        node.hitRadius = hitRadius
        node.zPosition = GameConstants.Z.bullet + 1
        node.physicsBody = nil
        node.zRotation = 0
        node.alpha = 1
        node.setScale(1)

        if FramePacing.currentQuality != .conservative {
            let glow = SKSpriteNode(texture: TextureCache.texture(WeaponTextures.softGlow))
            glow.name = "specialGlow"
            glow.size = CGSize(width: size.width * 1.55, height: size.height * 1.55)
            glow.zPosition = -1
            glow.blendMode = .add
            glow.color = glowColor
            glow.colorBlendFactor = 1
            glow.alpha = 0.85
            node.addChild(glow)
            glow.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.45, duration: 0.28),
                .fadeAlpha(to: 0.9, duration: 0.28)
            ])))
        }
    }

    private func smartGrenadeTarget() -> CGPoint {
        if let enemy = preferredGrenadeTarget(from: player.position) {
            return enemy.position
        }
        return CGPoint(
            x: player.position.x,
            y: playArea.maxY - GameRules.plasmaGrenadeTopInset
        )
    }

    private func enemyIsVisibleInPlayArea(_ enemy: PooledSprite, margin: CGFloat = 32) -> Bool {
        guard enemy.parent != nil else { return false }
        let point = enemy.position
        return point.x >= playArea.minX - margin
            && point.x <= playArea.maxX + margin
            && point.y >= playArea.minY - margin
            && point.y <= playArea.maxY + margin
    }

    private func preferredGrenadeTarget(from point: CGPoint) -> PooledSprite? {
        if bossVulnerable, let boss = bossNode, boss.parent != nil, enemyIsVisibleInPlayArea(boss) {
            return boss
        }
        if let mine = liveEnemies.first(where: {
            $0.obstacleKind == .clearMine && $0.parent != nil && enemyIsVisibleInPlayArea($0)
        }) {
            return mine
        }
        return nearestThreatForGrenade(from: point, onScreenOnly: true)
    }

    private func nearestThreatForGrenade(from point: CGPoint? = nil, onScreenOnly: Bool = false) -> PooledSprite? {
        let origin = point ?? player.position
        var best: PooledSprite?
        var bestScore = CGFloat.greatestFiniteMagnitude
        for enemy in liveEnemies where enemy.parent != nil {
            guard enemy.obstacleKind != nil else { continue }
            if onScreenOnly, !enemyIsVisibleInPlayArea(enemy) { continue }
            let dx = enemy.position.x - origin.x
            let dy = enemy.position.y - origin.y
            var score = dx * dx + dy * dy * 0.6
            if dy < -24 { score += 60_000 }
            switch enemy.obstacleKind {
            case .clearMine: score *= 0.25
            case .mine: score *= 0.45
            case .boss: score *= 0.15
            default: break
            }
            if score < bestScore {
                bestScore = score
                best = enemy
            }
        }
        return best
    }

    private func updateSpecialProjectiles(delta: TimeInterval) {
        guard delta > 0 else { return }
        var index = 0
        while index < liveSpecials.count {
            let node = liveSpecials[index]
            guard node.parent != nil else {
                liveSpecials.remove(at: index)
                continue
            }

            switch node.specialKind {
            case .seekerPod:
                steerSeeker(node, delta: delta)
                if seekerHitTest(node) {
                    continue
                }
            case .plasmaGrenade:
                steerPlasmaGrenade(node, delta: delta)
                if node.isArmed {
                    if preferredGrenadeTarget(from: node.position) != nil {
                        if specialProximityDetonate(
                            node,
                            triggerFactor: GameRules.plasmaGrenadeProximityFactor
                        ) {
                            continue
                        }
                    } else if node.position.y >= playArea.maxY - GameRules.plasmaGrenadeTopInset {
                        detonateSpecial(node, at: node.position)
                        continue
                    } else if runElapsed - node.spawnedAt >= GameRules.plasmaGrenadeMaxLifetime {
                        detonateSpecial(node, at: node.position)
                        continue
                    }
                }
            case .cooldownMine:
                if node.isArmed, specialProximityDetonate(node, triggerFactor: 0.72) {
                    continue
                }
            default:
                break
            }
            index += 1
        }
    }

    private func steerPlasmaGrenade(_ node: PooledSprite, delta: TimeInterval) {
        let topY = playArea.maxY - GameRules.plasmaGrenadeTopInset
        guard let target = preferredGrenadeTarget(from: node.position) else {
            let step = node.flightSpeed * CGFloat(delta)
            node.position.y = min(topY, node.position.y + step)
            node.zRotation = 0
            return
        }
        let dx = target.position.x - node.position.x
        let dy = target.position.y - node.position.y
        let length = max(0.001, hypot(dx, dy))
        let step = node.flightSpeed * CGFloat(delta)
        node.position.x += dx / length * step
        node.position.y += dy / length * step
        node.zRotation = atan2(dx, dy)
    }

    private func steerSeeker(_ node: PooledSprite, delta: TimeInterval) {
        guard let target = preferredSeekerTarget(from: node.position) else {
            node.position.y += node.flightSpeed * CGFloat(delta)
            return
        }
        let dx = target.position.x - node.position.x
        let dy = target.position.y - node.position.y
        let length = max(0.001, hypot(dx, dy))
        let step = node.flightSpeed * CGFloat(delta)
        node.position.x += dx / length * step
        node.position.y += dy / length * step
        node.zRotation = atan2(dx, dy)
    }

    private func preferredSeekerTarget(from point: CGPoint) -> PooledSprite? {
        if bossVulnerable, let boss = bossNode, boss.parent != nil {
            return boss
        }
        return nearestEnemy(to: point)
    }

    private func nearestEnemy(to point: CGPoint) -> PooledSprite? {
        var best: PooledSprite?
        var bestDist = CGFloat.greatestFiniteMagnitude
        for enemy in liveEnemies where enemy.parent != nil {
            let dx = enemy.position.x - point.x
            let dy = enemy.position.y - point.y
            let d = dx * dx + dy * dy
            if d < bestDist {
                bestDist = d
                best = enemy
            }
        }
        return best
    }

    private func seekerHitTest(_ node: PooledSprite) -> Bool {
        for enemy in liveEnemies where enemy.parent != nil {
            let radius = colliderRadius(forEnemy: enemy) + node.hitRadius
            let dx = enemy.position.x - node.position.x
            let dy = enemy.position.y - node.position.y
            if dx * dx + dy * dy <= radius * radius {
                let damage = node.projectileDamage
                let point = enemy.position
                recycleSpecial(node)
                damageObstacle(enemy, blastPoint: point, amount: damage)
                return true
            }
        }
        return false
    }

    private func specialProximityDetonate(_ node: PooledSprite, triggerFactor: CGFloat) -> Bool {
        let trigger = max(48, node.hitRadius * triggerFactor)
        for enemy in liveEnemies where enemy.parent != nil {
            let dx = enemy.position.x - node.position.x
            let dy = enemy.position.y - node.position.y
            if dx * dx + dy * dy <= trigger * trigger {
                detonateSpecial(node, at: node.position)
                return true
            }
        }
        return false
    }

    private func detonateSpecial(_ node: PooledSprite, at point: CGPoint) {
        let damage = node.projectileDamage
        let radius: CGFloat
        switch node.specialKind {
        case .plasmaGrenade:
            radius = GameRules.plasmaGrenadeAOERadius(playAreaSize: playArea.size)
        default:
            radius = max(40, node.hitRadius)
        }
        let tint: SKColor
        switch node.specialKind {
        case .plasmaGrenade:
            tint = SKColor(red: 0.45, green: 1.0, blue: 0.35, alpha: 0.9)
        case .cooldownMine:
            tint = SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 0.9)
        default:
            tint = SKColor(red: 1, green: 0.7, blue: 0.3, alpha: 0.9)
        }
        recycleSpecial(node)
        spawnExplosion(at: point, image: "explosion", scale: 1.25)
        if FramePacing.currentQuality != .conservative {
            spawnShockwaveRing(
                at: point,
                startScale: 0.15,
                endScale: max(4.0, radius / 32),
                duration: 0.42,
                color: tint,
                lineWidth: 7
            )
        }
        AudioManager.play(.explosion)
        HapticManager.enemyDestroyed()
        let radius2 = radius * radius
        for enemy in liveEnemies where enemy.parent != nil {
            let dx = enemy.position.x - point.x
            let dy = enemy.position.y - point.y
            guard dx * dx + dy * dy <= radius2 else { continue }
            damageObstacle(enemy, blastPoint: enemy.position, amount: damage)
        }
    }

    private func recycleSpecial(_ node: PooledSprite) {
        node.removeAllActions()
        node.childNode(withName: "specialGlow")?.removeFromParent()
        node.childNode(withName: "skyMineRadius")?.removeFromParent()
        untrack(node, from: &liveSpecials)
        specialPool.recycle(node)
    }

    private func refreshSpecialButton() {
        specialButton.configure(weapon: PlayerProgress.equippedSpecial())
        refreshSpecialCooldownUI()
    }

    private func refreshSpecialCooldownUI() {
        let profile = GameRules.specialProfile(for: equippedSpecialID)
        let remaining = max(0, specialReadyAt - runElapsed)
        let progress = profile.cooldown > 0 ? CGFloat(remaining / profile.cooldown) : 0
        specialButton.setCooldownProgress(progress)
    }

    // MARK: - Spawning (pickups / obstacles)

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
        powerUp.physicsBody = nil
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
        pickup.physicsBody = nil
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
        node.texture = TextureCache.texture(
            kind == .clearMine ? GameplayTextures.yellowClearMineName : kind.rawValue
        )
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
            contact: GameConstants.PhysicsCategory.player
        )
        addChild(node)
        liveEnemies.append(node)

        if kind == .mine {
            AudioManager.play(.mine)
            node.run(.repeatForever(.sequence([
                .scale(to: kind.scale * 1.08, duration: 0.45),
                .scale(to: kind.scale, duration: 0.45)
            ])))
        } else if kind == .clearMine {
            AudioManager.play(.mine)
            node.run(.repeatForever(.sequence([
                .scale(to: kind.scale * 1.12, duration: 0.35),
                .scale(to: kind.scale * 0.96, duration: 0.35)
            ])))
            node.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 4.8)))
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

    private func spawnClearMine() {
        guard currentState == .playing, playArea.width > 80 else { return }
        guard !liveEnemies.contains(where: { $0.obstacleKind == .clearMine && $0 !== bossNode }) else { return }

        let kind = GameConstants.ObstacleKind.clearMine
        let inset: CGFloat = 58
        let startX = CGFloat.random(in: playArea.minX + inset...playArea.maxX - inset)
        let endX = CGFloat.random(in: playArea.minX + inset...playArea.maxX - inset)
        let start = CGPoint(x: startX, y: playArea.maxY + 100)
        let end = CGPoint(x: endX, y: playArea.minY - 120)

        let node = obstaclePool.checkout()
        node.texture = TextureCache.texture(GameplayTextures.yellowClearMineName)
        let texSize = node.texture?.size() ?? GameplayTextures.yellowClearMinePixelSize
        node.size = texSize
        node.setScale(kind.scale)
        node.name = GameConstants.NodeName.enemy
        node.position = start
        node.zPosition = GameConstants.Z.enemy + (bossActive ? 1 : 0)
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
            contact: GameConstants.PhysicsCategory.player
        )
        addChild(node)
        liveEnemies.append(node)

        AudioManager.play(.mine)
        node.run(.repeatForever(.sequence([
            .scale(to: kind.scale * 1.12, duration: 0.35),
            .scale(to: kind.scale * 0.96, duration: 0.35)
        ])))
        node.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 4.8)))

        node.run(.sequence([
            .move(to: end, duration: kind.travelDuration),
            .run { [weak self] in
                guard let self, !self.bossActive else { return }
                self.lostALife(fromContact: false)
            },
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

        let profile = GameRules.bossProfile(at: bossesSpawnedCount)
        bossesSpawnedCount += 1
        currentBossMaxHP = profile.maxHP
        currentBossPoints = profile.points

        removeAction(forKey: "spawningEnemies")
        removeAction(forKey: "spawningRockets")
        bossActive = true
        bossVulnerable = false
        bossSpawnedAt = runElapsed

        let kind = GameConstants.ObstacleKind.boss
        let node = obstaclePool.checkout()
        node.texture = TextureCache.texture(profile.sprite)
        let texSize = node.texture?.size() ?? CGSize(width: 160, height: 160)
        node.size = texSize
        node.setScale(profile.scale)
        node.name = GameConstants.NodeName.boss
        node.position = CGPoint(x: playArea.midX, y: playArea.maxY + 180)
        node.zPosition = GameConstants.Z.enemy + 1
        node.alpha = 1
        node.zRotation = 0
        node.color = SKColor(
            red: profile.tintRed,
            green: profile.tintGreen,
            blue: profile.tintBlue,
            alpha: 1
        )
        node.colorBlendFactor = profile.tintBlend
        let radius = GameRules.obstacleHitRadius(for: kind, spriteSize: node.size, scale: node.xScale)
        node.obstacleKind = kind
        node.obstacleHP = profile.maxHP
        node.hitRadius = radius
        if let tex = node.texture {
            node.attachTexturePhysics(
                texture: tex,
                size: node.size,
                category: GameConstants.PhysicsCategory.enemy,
                contact: GameConstants.PhysicsCategory.player
            )
        } else {
            node.attachCirclePhysics(
                radius: radius,
                category: GameConstants.PhysicsCategory.enemy,
                contact: GameConstants.PhysicsCategory.player
            )
        }
        addChild(node)
        liveEnemies.append(node)
        bossNode = node
        activeBossProfile = profile
        bossVolleyIndex = 0

        let accent = SKColor(
            red: profile.bannerRed,
            green: profile.bannerGreen,
            blue: profile.bannerBlue,
            alpha: 1
        )
        bossHealthBar.show(maxHP: profile.maxHP, title: profile.name, accent: accent)
        hud.setStatus("Boss \(bossesSpawnedCount)/\(GameRules.maxBossCount)")
        hud.pulseStatus()
        softGravityUntil = 0
        softTimeWarpUntil = 0
        clearGravityWellFX()

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
            .wait(forDuration: profile.fireInterval),
            .run { [weak self] in self?.fireBossVolley() }
        ])), withKey: "bossFire")

        let banner = SKColor(
            red: profile.bannerRed,
            green: profile.bannerGreen,
            blue: profile.bannerBlue,
            alpha: 1
        )
        showStatusBanner(text: profile.name.uppercased(), color: banner)
        AudioManager.play(.mine)
        refreshParticleRates()
    }

    private func fireBossVolley() {
        guard bossActive, bossVulnerable, let boss = bossNode, boss.parent != nil,
              let profile = activeBossProfile, currentState == .playing else { return }
        guard liveFireballs.count < bossProjectileCap else { return }

        let origin = boss.position
        switch profile.attackPattern {
        case .voidLeviathan:
            fireVoidLeviathanVolley(from: origin)
        case .solarConclave:
            fireSolarConclaveVolley(from: origin)
        case .nexusSentinel:
            fireNexusSentinelVolley(from: origin)
        case .plagueBroodmother:
            firePlagueBroodmotherVolley(from: origin)
        }
    }

    // MARK: - Boss attack patterns (4 attacks each)

    private func fireVoidLeviathanVolley(from origin: CGPoint) {
        let mode = bossVolleyIndex % 4
        bossVolleyIndex += 1
        switch mode {
        case 0: // Void Pulse
            let spreads: [CGFloat] = [-85, 0, 85]
            for spread in spreads {
                spawnBossProjectile(
                    textureName: BossAttackTextures.voidPulse,
                    scale: 0.95,
                    speed: 460,
                    hitboxFactor: 0.36,
                    from: origin,
                    targetX: player.position.x + spread,
                    wobble: true
                )
            }
        case 1: // Tentacle Swipe
            fireDescendingWallWithGap(
                textureName: BossAttackTextures.tentacleOrb,
                fromY: origin.y - 70,
                count: 9,
                gapSlots: 2,
                speed: 540,
                scale: 0.72,
                hitboxFactor: 0.32
            )
        case 2: // Soft Gravity Well
            let well = CGPoint(
                x: GameRules.clampPlayerX(
                    x: player.position.x + CGFloat.random(in: -90...90),
                    playMinX: playArea.minX,
                    playMaxX: playArea.maxX,
                    halfWidth: 40
                ),
                y: max(player.position.y + 70, playArea.minY + 200)
            )
            activateSoftGravity(at: well)
            spawnBossProjectile(
                textureName: BossAttackTextures.voidPulse,
                scale: 0.88,
                speed: 400,
                hitboxFactor: 0.34,
                from: origin,
                targetX: well.x,
                wobble: true
            )
        default: // Minion Spawn (temporary)
            spawnBossMinions(
                textureName: BossAttackTextures.voidMinion,
                from: origin,
                count: 3,
                scale: 0.78,
                speed: 260
            )
        }
    }

    private func fireSolarConclaveVolley(from origin: CGPoint) {
        let mode = bossVolleyIndex % 4
        bossVolleyIndex += 1
        switch mode {
        case 0: // Lava Spit
            let spreads: [CGFloat] = [-100, -35, 35, 100]
            for spread in spreads {
                spawnBossProjectile(
                    textureName: BossAttackTextures.solarFlare,
                    scale: 0.92,
                    speed: 620,
                    hitboxFactor: 0.36,
                    from: origin,
                    targetX: player.position.x + spread,
                    wobble: true
                )
            }
        case 1: // Molten Ring
            fireRingWithGap(
                textureName: BossAttackTextures.orbitalSpark,
                center: CGPoint(x: playArea.midX, y: origin.y - 90),
                startRadius: 50,
                endRadius: max(playArea.width, playArea.height) * 0.55,
                segmentCount: 16,
                gapSegments: 3,
                travelDuration: 1.5,
                scale: 0.78,
                hitboxFactor: 0.34,
                expandOutward: true
            )
        case 2: // Lava Fountain
            fireDescendingWallWithGap(
                textureName: BossAttackTextures.coreLaser,
                fromY: origin.y - 40,
                count: 6,
                gapSlots: 2,
                speed: 580,
                scale: 0.82,
                hitboxFactor: 0.30,
                wobble: true
            )
        default: // Magma Rain
            let baseX = player.position.x
            for index in 0..<5 {
                let delay = Double(index) * 0.12
                let spread = CGFloat.random(in: -110...110)
                run(.sequence([
                    .wait(forDuration: delay),
                    .run { [weak self] in
                        guard let self, self.bossActive, self.bossVulnerable else { return }
                        self.spawnBossProjectile(
                            textureName: BossAttackTextures.meteor,
                            scale: 0.92,
                            speed: 360,
                            hitboxFactor: 0.40,
                            from: origin,
                            targetX: baseX + spread,
                            wobble: true
                        )
                    }
                ]))
            }
        }
    }

    private func fireNexusSentinelVolley(from origin: CGPoint) {
        let mode = bossVolleyIndex % 4
        bossVolleyIndex += 1
        switch mode {
        case 0: // Reality Shards
            let spreads: [CGFloat] = [-120, -40, 40, 120]
            for spread in spreads {
                spawnBossProjectile(
                    textureName: BossAttackTextures.realityShard,
                    scale: 0.78,
                    speed: 450,
                    hitboxFactor: 0.30,
                    from: origin,
                    targetX: player.position.x + spread
                )
            }
        case 1: // Dimension Slash
            fireDescendingWallWithGap(
                textureName: BossAttackTextures.dimensionSlash,
                fromY: origin.y - 55,
                count: 10,
                gapSlots: 2,
                speed: 420,
                scale: 0.70,
                hitboxFactor: 0.28
            )
        case 2: // Soft Time Warp
            let warpPoint = CGPoint(x: playArea.midX, y: origin.y - 40)
            activateSoftTimeWarp(at: warpPoint)
            let spreads: [CGFloat] = [-70, 0, 70]
            for spread in spreads {
                spawnBossProjectile(
                    textureName: BossAttackTextures.realityShard,
                    scale: 0.72,
                    speed: 320,
                    hitboxFactor: 0.28,
                    from: origin,
                    targetX: player.position.x + spread
                )
            }
        default: // Portal Summon (temporary)
            spawnBossMinions(
                textureName: BossAttackTextures.portalMinion,
                from: origin,
                count: 3,
                scale: 0.76,
                speed: 240
            )
        }
    }

    private func firePlagueBroodmotherVolley(from origin: CGPoint) {
        let mode = bossVolleyIndex % 4
        bossVolleyIndex += 1
        switch mode {
        case 0: // Toxic Spray
            let spreads: [CGFloat] = [-80, -25, 25, 80]
            for spread in spreads {
                spawnBossProjectile(
                    textureName: BossAttackTextures.toxicSpray,
                    scale: 0.78,
                    speed: 520,
                    hitboxFactor: 0.36,
                    from: origin,
                    targetX: player.position.x + spread,
                    wobble: true
                )
            }
        case 1: // Spore Bombs
            let spreads: [CGFloat] = [-60, 60]
            for spread in spreads {
                spawnBossProjectile(
                    textureName: BossAttackTextures.sporeBomb,
                    scale: 1.02,
                    speed: 300,
                    hitboxFactor: 0.42,
                    from: origin,
                    targetX: player.position.x + spread,
                    wobble: true
                )
            }
        case 2: // Swarm Call (temporary)
            spawnBossMinions(
                textureName: BossAttackTextures.swarmMinion,
                from: origin,
                count: 4,
                scale: 0.68,
                speed: 280
            )
        default: // Infected Eggs (temporary; hatch into drips)
            spawnBossMinions(
                textureName: BossAttackTextures.infectedEgg,
                from: origin,
                count: 3,
                scale: 0.72,
                speed: 200
            )
            let baseX = player.position.x
            for index in 0..<3 {
                let delay = 0.85 + Double(index) * 0.15
                run(.sequence([
                    .wait(forDuration: delay),
                    .run { [weak self] in
                        guard let self, self.bossActive, self.bossVulnerable else { return }
                        self.spawnBossProjectile(
                            textureName: BossAttackTextures.toxicSpray,
                            scale: 0.58,
                            speed: 640,
                            hitboxFactor: 0.32,
                            from: CGPoint(x: baseX + CGFloat.random(in: -70...70), y: origin.y - 40),
                            targetX: self.player.position.x + CGFloat.random(in: -40...40)
                        )
                    }
                ]))
            }
        }
    }

    /// Temporary dodgeables that time out and are cleared when the boss dies.
    private func spawnBossMinions(
        textureName: String,
        from origin: CGPoint,
        count: Int,
        scale: CGFloat,
        speed: CGFloat
    ) {
        let capped = min(count, GameRules.bossMinionMaxCount)
        guard liveFireballs.count + capped <= bossProjectileCap else { return }
        for index in 0..<capped {
            let spread = CGFloat(index - (capped - 1) / 2) * 70
            let start = CGPoint(x: origin.x + spread, y: origin.y - 50)
            let end = CGPoint(
                x: GameRules.clampPlayerX(
                    x: player.position.x + spread * 0.4,
                    playMinX: playArea.minX,
                    playMaxX: playArea.maxX,
                    halfWidth: 24
                ),
                y: playArea.minY - 60
            )
            let distance = hypot(end.x - start.x, end.y - start.y)
            let travel = min(
                GameRules.bossMinionLifetime,
                TimeInterval(distance / max(speed, 1))
            )
            spawnBossProjectileAt(
                textureName: textureName,
                scale: scale,
                hitboxFactor: 0.34,
                start: start,
                end: end,
                duration: travel,
                wobble: true,
                faceTravelDirection: false,
                lifetimeCap: GameRules.bossMinionLifetime
            )
        }
    }

    /// Expanding / collapsing ring of projectiles with a missing sector the player must fit through.
    private func fireRingWithGap(
        textureName: String,
        center: CGPoint,
        startRadius: CGFloat,
        endRadius: CGFloat,
        segmentCount: Int,
        gapSegments: Int,
        travelDuration: TimeInterval,
        scale: CGFloat,
        hitboxFactor: CGFloat,
        expandOutward: Bool
    ) {
        guard currentState == .playing, segmentCount > gapSegments else { return }
        let needed = segmentCount - gapSegments
        // Skip the whole signature if we can't fit a complete ring — a truncated ring
        // leaves a broken dodge gap that feels unfair under load.
        guard liveFireballs.count + needed <= bossProjectileCap else { return }

        // Aim the gap roughly toward the player, with a random nudge so they still have to move.
        let dx = player.position.x - center.x
        let dy = player.position.y - center.y
        let playerAngle = atan2(dy, dx)
        let gapWidth = (CGFloat.pi * 2 / CGFloat(segmentCount)) * CGFloat(gapSegments)
        let gapCenter = playerAngle + CGFloat.random(in: -0.55...0.55)

        for index in 0..<segmentCount {
            let angle = (CGFloat.pi * 2 / CGFloat(segmentCount)) * CGFloat(index)
            var delta = abs(angle - gapCenter)
            if delta > .pi { delta = CGFloat.pi * 2 - delta }
            if delta < gapWidth * 0.5 { continue }

            let start = CGPoint(
                x: center.x + cos(angle) * startRadius,
                y: center.y + sin(angle) * startRadius
            )
            let end = CGPoint(
                x: center.x + cos(angle) * endRadius,
                y: center.y + sin(angle) * endRadius
            )
            spawnBossProjectileAt(
                textureName: textureName,
                scale: scale,
                hitboxFactor: hitboxFactor,
                start: start,
                end: end,
                duration: travelDuration,
                wobble: expandOutward,
                faceTravelDirection: true
            )
        }
    }

    /// Horizontal wall of projectiles descending with a safe lane gap.
    private func fireDescendingWallWithGap(
        textureName: String,
        fromY: CGFloat,
        count: Int,
        gapSlots: Int,
        speed: CGFloat,
        scale: CGFloat,
        hitboxFactor: CGFloat,
        wobble: Bool = false
    ) {
        guard count > gapSlots, playArea.width > 80 else { return }
        let needed = count - gapSlots
        guard liveFireballs.count + needed <= bossProjectileCap else { return }

        let margin: CGFloat = 36
        let usable = playArea.width - margin * 2
        let step = usable / CGFloat(max(1, count - 1))
        let preferredSlot = Int(round((player.position.x - playArea.minX - margin) / step))
        let gapStart = max(0, min(count - gapSlots, preferredSlot - gapSlots / 2 + Int.random(in: -1...1)))

        for index in 0..<count {
            if index >= gapStart && index < gapStart + gapSlots { continue }
            let x = playArea.minX + margin + step * CGFloat(index)
            let start = CGPoint(x: x, y: fromY)
            let end = CGPoint(x: x, y: playArea.minY - 80)
            let distance = abs(end.y - start.y)
            let duration = TimeInterval(distance / speed)
            spawnBossProjectileAt(
                textureName: textureName,
                scale: scale,
                hitboxFactor: hitboxFactor,
                start: start,
                end: end,
                duration: duration,
                wobble: wobble,
                faceTravelDirection: true
            )
        }
    }

    private func spawnBossProjectile(
        textureName: String,
        scale: CGFloat,
        speed: CGFloat,
        hitboxFactor: CGFloat,
        from origin: CGPoint,
        targetX: CGFloat,
        wobble: Bool = false
    ) {
        let start = CGPoint(x: origin.x, y: origin.y - 60)
        let clampedTargetX = GameRules.clampPlayerX(
            x: targetX,
            playMinX: playArea.minX,
            playMaxX: playArea.maxX,
            halfWidth: 20
        )
        let end = CGPoint(x: clampedTargetX, y: playArea.minY - 80)
        let distance = hypot(end.x - start.x, end.y - start.y)
        let duration = TimeInterval(distance / max(speed, 1))
        spawnBossProjectileAt(
            textureName: textureName,
            scale: scale,
            hitboxFactor: hitboxFactor,
            start: start,
            end: end,
            duration: duration,
            wobble: wobble,
            faceTravelDirection: false
        )
    }

    private func spawnBossProjectileAt(
        textureName: String,
        scale: CGFloat,
        hitboxFactor: CGFloat,
        start: CGPoint,
        end: CGPoint,
        duration: TimeInterval,
        wobble: Bool,
        faceTravelDirection: Bool,
        lifetimeCap: TimeInterval? = nil
    ) {
        guard currentState == .playing, liveFireballs.count < bossProjectileCap else { return }

        let projectile = fireballPool.checkout()
        projectile.texture = TextureCache.texture(textureName)
        let texSize = projectile.texture?.size() ?? CGSize(width: 64, height: 64)
        projectile.size = texSize
        projectile.setScale(scale)
        projectile.name = GameConstants.NodeName.fireball
        projectile.position = start
        projectile.zPosition = GameConstants.Z.enemyProjectile
        projectile.colorBlendFactor = 0
        projectile.alpha = 1
        projectile.speed = runElapsed < softTimeWarpUntil ? GameRules.softTimeWarpFactor : 1
        if faceTravelDirection {
            projectile.zRotation = atan2(end.y - start.y, end.x - start.x) - .pi / 2
        } else {
            projectile.zRotation = 0
        }
        let radius = min(projectile.size.width, projectile.size.height) * projectile.xScale * hitboxFactor
        projectile.hitRadius = radius
        projectile.attachCirclePhysics(
            radius: radius,
            category: GameConstants.PhysicsCategory.enemyProjectile,
            contact: GameConstants.PhysicsCategory.player
        )
        addChild(projectile)
        liveFireballs.append(projectile)

        if let frames = BossAttackTextures.animationFrames(for: textureName), frames.count > 1 {
            projectile.run(.repeatForever(
                .animate(with: frames, timePerFrame: 0.09, resize: false, restore: false)
            ))
        }

        if wobble {
            projectile.run(.repeatForever(.sequence([
                .scale(to: scale * 1.08, duration: 0.16),
                .scale(to: scale, duration: 0.16)
            ])))
        }

        let moveDuration = max(0.2, duration)
        let effectiveDuration: TimeInterval
        if let lifetimeCap {
            effectiveDuration = max(0.2, min(moveDuration, lifetimeCap))
        } else {
            effectiveDuration = moveDuration
        }
        projectile.run(.sequence([
            .move(to: end, duration: effectiveDuration),
            .run { [weak self, weak projectile] in
                guard let self, let projectile else { return }
                self.recycleFireball(projectile)
            }
        ]))
    }

    private func recycleFireball(_ node: PooledSprite) {
        node.removeAllActions()
        node.speed = 1
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
        bossesDefeatedCount += 1
        if bossesDefeatedCount == 1 {
            GameCenterAchievementService.unlock(.firstBoss)
        }
        if bossesDefeatedCount >= GameRules.maxBossCount {
            GameCenterAchievementService.unlock(.allBosses)
        }
        bossActive = false
        bossVulnerable = false
        bossNode = nil
        activeBossProfile = nil
        bossVolleyIndex = 0
        softGravityUntil = 0
        softTimeWarpUntil = 0
        clearGravityWellFX()
        bossHealthBar.hideBar()
        clearFireballs()
        nextBossSpawnAt = GameRules.nextBossSpawnTime(afterDefeatAt: runElapsed)
        spawnExplosion(at: position, image: "explosion", scale: 1.6)
        showStatusBanner(text: "BOSS DEFEATED", color: SKColor(red: 0.35, green: 0.95, blue: 0.55, alpha: 1))
        HapticManager.upgrade()
        updateHUD()
        scheduleNextObstacle()
        schedulePowerUps()
        scheduleNextRocket()
        scheduleNextClearMine()
        refreshParticleRates()
    }

    private func spawnExplosion(at position: CGPoint, image: String, scale: CGFloat = 1, playSound: Bool = true) {
        let explosion = explosionPool.checkout()
        explosion.texture = TextureCache.texture(image)
        explosion.size = explosion.texture?.size() ?? CGSize(width: 160, height: 160)
        explosion.position = position
        explosion.zPosition = GameConstants.Z.effect
        explosion.setScale(0)
        explosion.alpha = 1
        addChild(explosion)
        if playSound {
            AudioManager.play(.explosion)
        }

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
            let primary = GameRules.primaryProfile(for: equippedPrimaryID)
            bulletImageName = equippedPrimaryID == .pulseLaser
                ? GameConstants.poweredBulletImage
                : primary.textureName
            fireDelay = primary.boostedFireDelay
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
        if lives >= GameRules.maxLives {
            GameCenterAchievementService.unlock(.fiveLives)
        }
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

    private func damageObstacle(_ node: SKNode, blastPoint: CGPoint, amount: Int = 1) {
        let sprite = node as? PooledSprite
        let kind = sprite?.obstacleKind ?? .asteroid

        if kind == .clearMine {
            detonateClearMine(node, at: blastPoint)
            return
        }

        if kind == .boss && !bossVulnerable {
            spawnExplosion(at: blastPoint, image: "mini_explosion", scale: 0.35)
            return
        }

        let hp = max(0, (sprite?.obstacleHP ?? 1) - max(1, amount))
        sprite?.obstacleHP = hp

        if kind == .boss {
            bossHealthBar.setHP(current: hp, maximum: currentBossMaxHP)
            bossHealthBar.pulseDamage()
        }

        if hp > 0 {
            let baseScale = (kind == .boss)
                ? (sprite?.xScale ?? GameRules.bossScale)
                : kind.scale
            node.run(.sequence([
                .scale(to: baseScale * 1.08, duration: 0.06),
                .scale(to: baseScale, duration: 0.08)
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
            addScore(currentBossPoints)
            registerKillCombo()
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
        registerKillCombo()
    }

    // MARK: - Yellow clear mine

    private func detonateClearMine(_ node: SKNode, at blastPoint: CGPoint) {
        if let sprite = node as? PooledSprite {
            untrack(sprite, from: &liveEnemies)
            obstaclePool.recycle(sprite)
        } else {
            node.removeFromParent()
        }
        addScore(GameRules.clearMinePoints)
        registerKillCombo()
        HapticManager.upgrade()
        AudioManager.play(.explosion)

        if bossActive {
            playClearMineBossBurst(at: blastPoint)
            applyClearMineBossDamage(blastPoint: blastPoint)
        } else {
            obstacleSpawnPausedUntil = runElapsed + GameRules.clearMineSpawnPauseDuration
            removeAction(forKey: "spawningEnemies")
            playClearMineScreenDetonation(at: blastPoint)
            scheduleNextObstacle()
        }
    }

    private func applyClearMineBossDamage(blastPoint: CGPoint) {
        guard let boss = bossNode else { return }
        let damage = GameRules.clearMineBossDamage

        if !bossVulnerable {
            spawnExplosion(at: blastPoint, image: "mini_explosion", scale: 0.55)
            return
        }

        let hp = max(0, boss.obstacleHP - damage)
        boss.obstacleHP = hp
        bossHealthBar.setHP(current: hp, maximum: currentBossMaxHP)
        bossHealthBar.pulseDamage()
        spawnExplosion(at: blastPoint, image: "explosion", scale: 1.15)
        showStatusBanner(
            text: "-\(damage) BOSS HP",
            color: SKColor(red: 1.0, green: 0.78, blue: 0.18, alpha: 1)
        )

        if hp <= 0 {
            let defeatPoint = boss.position
            untrack(boss, from: &liveEnemies)
            obstaclePool.recycle(boss)
            bossNode = nil
            spawnExplosion(at: defeatPoint, image: "explosion", scale: 1.45)
            HapticManager.enemyDestroyed()
            addScore(currentBossPoints)
            registerKillCombo()
            onBossDefeated(at: blastPoint)
        }
    }

    private func playClearMineBossBurst(at origin: CGPoint) {
        spawnExplosion(at: origin, image: "explosion", scale: 1.35)
        spawnShockwaveRing(
            at: origin,
            startScale: 0.25,
            endScale: 5.5,
            duration: 0.42,
            color: SKColor(red: 1, green: 0.82, blue: 0.15, alpha: 0.85),
            lineWidth: 7
        )
    }

    private func playClearMineScreenDetonation(at origin: CGPoint) {
        spawnExplosion(at: origin, image: "explosion", scale: 1.85)

        spawnShockwaveRing(
            at: origin,
            startScale: 0.15,
            endScale: 14,
            duration: 0.62,
            color: SKColor(red: 1, green: 0.88, blue: 0.25, alpha: 0.95),
            lineWidth: 10
        )
        run(.sequence([
            .wait(forDuration: 0.08),
            .run { [weak self] in
                self?.spawnShockwaveRing(
                    at: origin,
                    startScale: 0.2,
                    endScale: 10,
                    duration: 0.48,
                    color: SKColor(red: 1, green: 0.98, blue: 0.65, alpha: 0.9),
                    lineWidth: 5
                )
            }
        ]))

        let flash = SKSpriteNode(
            color: SKColor(red: 1, green: 0.92, blue: 0.45, alpha: 0.38),
            size: CGSize(width: size.width * 1.15, height: size.height * 1.15)
        )
        flash.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        flash.zPosition = GameConstants.Z.effect + 3
        flash.alpha = 0
        addChild(flash)
        flash.run(.sequence([
            .fadeAlpha(to: 1, duration: 0.05),
            .fadeOut(withDuration: 0.38),
            .removeFromParent()
        ]))

        let burstCount: Int
        switch FramePacing.currentQuality {
        case .high: burstCount = 10
        case .balanced: burstCount = 6
        case .conservative: burstCount = 4
        }
        for index in 0..<burstCount {
            let angle = CGFloat(index) * (.pi * 2 / CGFloat(burstCount))
            let offset = CGPoint(x: cos(angle) * 72, y: sin(angle) * 72)
            run(.sequence([
                .wait(forDuration: 0.03 * Double(index)),
                .run { [weak self] in
                    self?.spawnExplosion(
                        at: CGPoint(x: origin.x + offset.x, y: origin.y + offset.y),
                        image: "mini_explosion",
                        scale: 0.75,
                        playSound: false
                    )
                }
            ]))
        }

        showStatusBanner(text: "CHAIN CLEAR!", color: SKColor(red: 1.0, green: 0.86, blue: 0.2, alpha: 1))
        clearObstaclesFromClearMine(origin: origin)
    }

    /// Sprite-batched expanding ring — avoids SKShapeNode tessellation hitches.
    private func spawnShockwaveRing(
        at origin: CGPoint,
        startScale: CGFloat,
        endScale: CGFloat,
        duration: TimeInterval,
        color: SKColor,
        lineWidth: CGFloat
    ) {
        let ring = SKSpriteNode(texture: shockwaveRingTexture(lineWidth: lineWidth))
        ring.size = CGSize(width: 88, height: 88)
        ring.position = origin
        ring.zPosition = GameConstants.Z.effect + 2
        ring.setScale(startScale)
        ring.color = color
        ring.colorBlendFactor = 1
        ring.blendMode = .add
        addChild(ring)
        ring.run(.sequence([
            .group([
                .scale(to: endScale, duration: duration),
                .fadeOut(withDuration: duration)
            ]),
            .removeFromParent()
        ]))
    }

    private func shockwaveRingTexture(lineWidth: CGFloat) -> SKTexture {
        let key = String(format: "__shockwave_ring_%.0f", lineWidth)
        if let cached = TextureCache.optional(key) {
            return cached
        }
        let size = CGSize(width: 96, height: 96)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            let inset = lineWidth * 0.5 + 1
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            let path = UIBezierPath(ovalIn: rect)
            UIColor.white.setStroke()
            path.lineWidth = lineWidth
            path.stroke()
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        TextureCache.store(key, texture: texture)
        return texture
    }

    private func clearObstaclesFromClearMine(origin: CGPoint) {
        let targets = liveEnemies.filter { enemy in
            enemy !== bossNode && enemy.obstacleKind != .clearMine
        }
        let sorted = targets.sorted {
            hypot($0.position.x - origin.x, $0.position.y - origin.y)
                < hypot($1.position.x - origin.x, $1.position.y - origin.y)
        }

        for (index, enemy) in sorted.enumerated() {
            let delay = 0.06 + Double(index) * 0.038
            run(.sequence([
                .wait(forDuration: delay),
                .run { [weak self, weak enemy] in
                    guard let self, let enemy, enemy.parent != nil else { return }
                    let pos = enemy.position
                    let points = enemy.obstacleKind?.points ?? 1
                    enemy.removeAllActions()
                    self.untrack(enemy, from: &self.liveEnemies)
                    self.obstaclePool.recycle(enemy)
                    self.spawnExplosion(at: pos, image: "mini_explosion", scale: 0.92, playSound: index == 0)
                    self.addScore(points)
                    self.registerKillCombo()
                    if index % 3 == 0 {
                        HapticManager.enemyDestroyed()
                    }
                }
            ]))
        }
    }

    // MARK: - Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        guard currentState == .playing, !gameplayFrozen, !isPausedBySystem else { return }

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
            if let pooled = enemyNode as? PooledSprite, pooled.obstacleKind == .clearMine {
                let point = pooled.position
                detonateClearMine(pooled, at: point)
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
                if fireball.name == GameConstants.NodeName.rocket {
                    recycleRocket(fireball)
                } else {
                    recycleFireball(fireball)
                }
            } else {
                fireballNode?.removeFromParent()
            }
            lostALife(fromContact: true)
            return
        }

        // Bullets and pickups use swept hit tests in didFinishUpdate — no physics pairs.
    }

    // MARK: - Controls

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard currentState == .playing, !isPausedBySystem, !gameplayFrozen else { return }
        for touch in touches {
            steeringTouchX = touch.location(in: self).x
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        steeringTouchX = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        steeringTouchX = nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if currentState == .paused {
            let overlayPoint = CGPoint(
                x: point.x - (pauseOverlay?.position.x ?? 0),
                y: point.y - (pauseOverlay?.position.y ?? 0)
            )
            if let resumeButton, resumeButton.containsTouch(overlayPoint) {
                resumeButton.pulse()
                AudioManager.play(.uiTap)
                HapticManager.fire()
                resumeFromPause()
                return
            }
            if let menuButton, menuButton.containsTouch(overlayPoint) {
                menuButton.pulse()
                exitToTitleFromPause()
            }
            return
        }

        guard currentState == .playing, !isPausedBySystem, !gameplayFrozen else { return }

        if hud.containsPauseTouch(point) {
            enterPause(showOverlay: true)
            return
        }
        if specialButton.containsTouch(point) {
            fireSpecial()
            return
        }

        steeringTouchX = point.x
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
        let projectileRadius = bullet.hitRadius > 0 ? bullet.hitRadius : GameRules.bulletHitRadius
        let dx = end.x - start.x
        let dy = end.y - start.y
        let moveSquared = dx * dx + dy * dy
        let usePointOnly = moveSquared < 0.25

        for enemy in liveEnemies {
            guard enemy.parent != nil else { continue }
            let enemyID = ObjectIdentifier(enemy)
            if bullet.piercedEnemyIDs.contains(enemyID) { continue }
            let radius = colliderRadius(forEnemy: enemy)
            guard isColliderOnscreen(enemy, radius: radius) else { continue }
            if !usePointOnly,
               !GameRules.segmentMayHitTarget(
                   start: start,
                   end: end,
                   projectileRadius: projectileRadius,
                   target: enemy.position,
                   targetRadius: radius
               ) {
                continue
            }
            if GameRules.projectileHitsTarget(
                start: usePointOnly ? end : start,
                end: end,
                projectileRadius: projectileRadius,
                target: enemy.position,
                targetRadius: radius
            ) {
                let damage = max(1, bullet.projectileDamage)
                if bullet.pierceRemaining > 0 {
                    bullet.pierceRemaining -= 1
                    bullet.piercedEnemyIDs.insert(enemyID)
                    damageObstacle(enemy, blastPoint: enemy.position, amount: damage)
                    return false
                }
                recycleProjectile(bullet)
                damageObstacle(enemy, blastPoint: enemy.position, amount: damage)
                return true
            }
        }

        for pickup in livePickups {
            guard pickup.parent != nil else { continue }
            let radius = colliderRadius(forPickup: pickup)
            if !usePointOnly,
               !GameRules.segmentMayHitTarget(
                   start: start,
                   end: end,
                   projectileRadius: projectileRadius,
                   target: pickup.position,
                   targetRadius: radius
               ) {
                continue
            }
            if GameRules.projectileHitsTarget(
                start: usePointOnly ? end : start,
                end: end,
                projectileRadius: projectileRadius,
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
