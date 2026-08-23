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
    private var level = 0
    private var starCharge = 0
    private var poweredShotsRemaining = 0
    private var fireDelay = GameConstants.baseFireDelay
    private var bulletImageName = GameConstants.bulletImage
    private var currentState: State = .playing
    private var playArea = CGRect.zero
    /// True after the app actually enters the background (home switch), not screenshot/Control Center.
    private var requiresManualResume = false
    private var isPausedBySystem = false
    private var isInvulnerable = false
    private var runElapsed: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var bossesSpawnedCount = 0
    private var currentBossMaxHP = GameRules.bossMaxHP
    private var currentBossPoints = GameRules.bossPoints
    private var bossActive = false
    private var bossVulnerable = false
    private var bossSpawnedAt: TimeInterval = 0
    private var nextBossSpawnAt: TimeInterval = GameRules.firstBossSpawnTime()
    private var bossNode: PooledSprite?
    private var activeBossProfile: GameRules.BossProfile?
    private var bossVolleyIndex = 0
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
    private var gameplayFrozen = false

    private var liveBullets: [PooledSprite] = []
    private var liveEnemies: [PooledSprite] = []
    private var livePickups: [PooledSprite] = []
    private var liveFireballs: [PooledSprite] = []
    private var liveRockets: [PooledSprite] = []

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
    private lazy var fireballPool = NodePool(prewarm: 16, maxIdle: 28) {
        PooledSprite(texture: TextureCache.texture(GameConstants.fireballImage))
    }
    private lazy var rocketPool = NodePool(prewarm: 6, maxIdle: 12) {
        PooledSprite(texture: TextureCache.texture(GameConstants.rocketImage))
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

        scrollingBackground = addProductionBackground()
        GameplayTextures.registerProceduralTextures()
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
        refreshParticleRates()
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
            let delta = currentTime - lastUpdateTime
            runElapsed += delta
            scrollingBackground?.tick(deltaTime: delta)

            let tier = GameRules.spawnTier(elapsed: runElapsed)
            if tier != backgroundTier {
                backgroundTier = tier
                updateBackgroundTier(tier, animated: tier > 0)
            }
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
        recordPlayerXHistory()
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
        guard currentState == .playing, !isPausedBySystem else { return }
        resolveSweptProjectileHits()
    }

    // MARK: - Layout

    private func relayoutForSafeArea() {
        let layout = playfield
        playArea = layout.safeRect
        visibleMaxY = layout.visibleRect.maxY
        relayoutProductionBackground()
        hud.layout(in: layout.safeRect)
        bossHealthBar.layout(in: layout.safeRect, below: 108)

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
        engineEmitter?.isPaused = quality.engineBirthRate <= 0
        let dustRate = bossActive ? 0 : FramePacing.scaledBirthRate(quality.starDustBirthRate)
        applyPerformanceQuality(starDustRate: dustRate)
        if let dust = childNode(withName: GameConstants.NodeName.starDust) as? SKEmitterNode {
            dust.isPaused = dustRate <= 0
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
            return
        }
        if currentState == .playing {
            unfreezeGameplay()
            lastUpdateTime = 0
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
        engineFlame?.isHidden = true
        engineFlame?.removeAllActions()

        removeAllActions()
        for sprite in liveBullets + liveEnemies + livePickups + liveFireballs + liveRockets {
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
        lastUpdateTime = 0
        AudioManager.play(.uiTap)
        HapticManager.fire()
    }

    private func freezeGameplay() {
        guard !gameplayFrozen else { return }
        gameplayFrozen = true
        removeAction(forKey: "spawningEnemies")
        removeAction(forKey: "spawningPowerUp")
        removeAction(forKey: "spawningHealth")
        removeAction(forKey: "spawningRockets")
        removeAction(forKey: "spawningClearMine")
        removeAction(forKey: "fireBullets")
        player.isPaused = true
        engineEmitter?.isPaused = true
        for node in liveBullets + liveEnemies + livePickups + liveFireballs + liveRockets {
            node.isPaused = true
        }
        bossNode?.isPaused = true
    }

    private func unfreezeGameplay() {
        guard gameplayFrozen else { return }
        gameplayFrozen = false
        player.isPaused = false
        engineEmitter?.isPaused = false
        for node in liveBullets + liveEnemies + livePickups + liveFireballs + liveRockets {
            node.isPaused = false
        }
        bossNode?.isPaused = false
        guard currentState == .playing else { return }
        schedulePowerUps()
        scheduleHealthPickups()
        scheduleNextClearMine()
        if !bossActive {
            scheduleNextObstacle()
            scheduleNextRocket()
        }
        restartFiring()
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
        bullet.physicsBody = nil
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
        node.attachCirclePhysics(
            radius: radius,
            category: GameConstants.PhysicsCategory.enemy,
            contact: GameConstants.PhysicsCategory.player
        )
        addChild(node)
        liveEnemies.append(node)
        bossNode = node
        activeBossProfile = profile
        bossVolleyIndex = 0

        bossHealthBar.show(maxHP: profile.maxHP, title: profile.name)
        hud.setStatus("Boss \(bossesSpawnedCount)/\(GameRules.maxBossCount)")
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
        case .nebulaCyclops:
            fireNebulaVolley(from: origin)
        case .crimsonClawfiend:
            fireClawVolley(from: origin)
        case .acidHydra:
            fireAcidHydraVolley(from: origin)
        case .frostMaw:
            fireFrostVolley(from: origin)
        case .magmaBehemoth:
            fireMagmaVolley(from: origin)
        case .voidEmperor:
            fireVoidVolley(from: origin)
        }
    }

    // MARK: - Boss attack patterns

    private func fireNebulaVolley(from origin: CGPoint) {
        // Signature every other volley: purple ring of fire with a dodge gap.
        if bossVolleyIndex % 2 == 0 {
            fireRingWithGap(
                textureName: BossAttackTextures.nebulaFlame,
                center: CGPoint(x: playArea.midX, y: origin.y - 90),
                startRadius: 55,
                endRadius: max(playArea.width, playArea.height) * 0.55,
                segmentCount: 16,
                gapSegments: 3,
                travelDuration: 1.55,
                scale: 0.78,
                hitboxFactor: 0.36,
                expandOutward: true
            )
        } else {
            spawnBossProjectile(
                textureName: BossAttackTextures.cosmicBolt,
                scale: 1.02,
                speed: 440,
                hitboxFactor: 0.38,
                from: origin,
                targetX: player.position.x,
                wobble: true
            )
        }
        bossVolleyIndex += 1
    }

    private func fireClawVolley(from origin: CGPoint) {
        if bossVolleyIndex % 2 == 0 {
            // Descending claw wall — leave one safe lane for the player to slip through.
            fireDescendingWallWithGap(
                textureName: BossAttackTextures.clawShard,
                fromY: origin.y - 70,
                count: 9,
                gapSlots: 2,
                speed: 620,
                scale: 0.74,
                hitboxFactor: 0.30
            )
        } else {
            let spreads: [CGFloat] = [-95, 0, 95]
            for spread in spreads {
                spawnBossProjectile(
                    textureName: BossAttackTextures.clawShard,
                    scale: 0.82,
                    speed: 680,
                    hitboxFactor: 0.32,
                    from: origin,
                    targetX: player.position.x + spread
                )
            }
        }
        bossVolleyIndex += 1
    }

    private func fireAcidHydraVolley(from origin: CGPoint) {
        let mode = bossVolleyIndex % 4
        bossVolleyIndex += 1

        switch mode {
        case 0:
            let spreads: [CGFloat] = [-70, 0, 70]
            for spread in spreads {
                spawnBossProjectile(
                    textureName: BossAttackTextures.acidBall,
                    scale: 0.78,
                    speed: 540,
                    hitboxFactor: 0.36,
                    from: origin,
                    targetX: player.position.x + spread,
                    wobble: true
                )
            }
        case 1:
            let baseX = player.position.x
            for index in 0..<6 {
                let dripDelay = Double(index) * 0.09
                let spread = CGFloat.random(in: -55...55)
                run(.sequence([
                    .wait(forDuration: dripDelay),
                    .run { [weak self] in
                        guard let self, self.bossActive, self.bossVulnerable else { return }
                        self.spawnBossProjectile(
                            textureName: BossAttackTextures.acidDrip,
                            scale: 0.62,
                            speed: 720,
                            hitboxFactor: 0.34,
                            from: origin,
                            targetX: baseX + spread
                        )
                    }
                ]))
            }
        case 2:
            // Acid curtain with one clear corridor.
            fireDescendingWallWithGap(
                textureName: BossAttackTextures.acidBall,
                fromY: origin.y - 60,
                count: 8,
                gapSlots: 2,
                speed: 480,
                scale: 0.70,
                hitboxFactor: 0.34,
                wobble: true
            )
        default:
            spawnBossProjectile(
                textureName: BossAttackTextures.acidSplat,
                scale: 1.05,
                speed: 380,
                hitboxFactor: 0.42,
                from: origin,
                targetX: player.position.x,
                wobble: true
            )
        }
    }

    private func fireFrostVolley(from origin: CGPoint) {
        if bossVolleyIndex % 2 == 0 {
            // Frost gates close from both sides, leaving a drifting center gap.
            fireDescendingWallWithGap(
                textureName: BossAttackTextures.iceShard,
                fromY: origin.y - 55,
                count: 10,
                gapSlots: 2,
                speed: 400,
                scale: 0.72,
                hitboxFactor: 0.28
            )
        } else {
            let spreads: [CGFloat] = [-120, -40, 40, 120]
            for spread in spreads {
                spawnBossProjectile(
                    textureName: BossAttackTextures.iceShard,
                    scale: 0.76,
                    speed: 430,
                    hitboxFactor: 0.30,
                    from: origin,
                    targetX: player.position.x + spread
                )
            }
        }
        bossVolleyIndex += 1
    }

    private func fireMagmaVolley(from origin: CGPoint) {
        if bossVolleyIndex % 2 == 0 {
            // Erupting magma pillars — three columns with one safe lane.
            fireDescendingWallWithGap(
                textureName: BossAttackTextures.magmaBoulder,
                fromY: origin.y - 40,
                count: 7,
                gapSlots: 2,
                speed: 320,
                scale: 0.92,
                hitboxFactor: 0.40,
                wobble: true
            )
        } else {
            let shots = Bool.random() ? 1 : 2
            for index in 0..<shots {
                let spread = CGFloat(index) * 80 - CGFloat(shots - 1) * 40
                spawnBossProjectile(
                    textureName: BossAttackTextures.magmaBoulder,
                    scale: 1.08,
                    speed: 340,
                    hitboxFactor: 0.44,
                    from: origin,
                    targetX: player.position.x + spread,
                    wobble: true
                )
            }
        }
        bossVolleyIndex += 1
    }

    private func fireVoidVolley(from origin: CGPoint) {
        if bossVolleyIndex % 2 == 0 {
            // Collapsing void ring — player must slip through the gap before it closes.
            fireRingWithGap(
                textureName: BossAttackTextures.voidOrb,
                center: CGPoint(x: playArea.midX, y: max(player.position.y + 40, playArea.minY + 220)),
                startRadius: max(playArea.width, playArea.height) * 0.48,
                endRadius: 70,
                segmentCount: 16,
                gapSegments: 3,
                travelDuration: 1.45,
                scale: 0.80,
                hitboxFactor: 0.34,
                expandOutward: false
            )
        } else {
            let spreads: [CGFloat] = [-110, 0, 110]
            for spread in spreads {
                spawnBossProjectile(
                    textureName: BossAttackTextures.voidOrb,
                    scale: 0.88,
                    speed: 500,
                    hitboxFactor: 0.36,
                    from: origin,
                    targetX: player.position.x + spread,
                    wobble: true
                )
            }
        }
        bossVolleyIndex += 1
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
        faceTravelDirection: Bool
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

        if wobble {
            projectile.run(.repeatForever(.sequence([
                .scale(to: scale * 1.08, duration: 0.16),
                .scale(to: scale, duration: 0.16)
            ])))
        }

        projectile.run(.sequence([
            .move(to: end, duration: max(0.2, duration)),
            .run { [weak self, weak projectile] in
                guard let self, let projectile else { return }
                self.recycleFireball(projectile)
            }
        ]))
    }

    private func recycleFireball(_ node: PooledSprite) {
        node.removeAllActions()
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
        activeBossProfile = nil
        bossVolleyIndex = 0
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

        if kind == .clearMine {
            detonateClearMine(node, at: blastPoint)
            return
        }

        if kind == .boss && !bossVulnerable {
            spawnExplosion(at: blastPoint, image: "mini_explosion", scale: 0.35)
            return
        }

        let hp = max(0, (sprite?.obstacleHP ?? 1) - 1)
        sprite?.obstacleHP = hp

        if kind == .boss {
            bossHealthBar.setHP(current: hp, maximum: currentBossMaxHP)
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
            addScore(currentBossPoints)
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

    // MARK: - Yellow clear mine

    private func detonateClearMine(_ node: SKNode, at blastPoint: CGPoint) {
        if let sprite = node as? PooledSprite {
            untrack(sprite, from: &liveEnemies)
            obstaclePool.recycle(sprite)
        } else {
            node.removeFromParent()
        }
        addScore(GameRules.clearMinePoints)
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
                    if index % 3 == 0 {
                        HapticManager.enemyDestroyed()
                    }
                }
            ]))
        }
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
        guard currentState == .playing, !isPausedBySystem else { return }
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
                resumeFromPause()
            }
            return
        }

        guard currentState == .playing, !isPausedBySystem else { return }

        if hud.containsPauseTouch(point) {
            enterPause(showOverlay: true)
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
        let projectileRadius = GameRules.bulletHitRadius
        let dx = end.x - start.x
        let dy = end.y - start.y
        let moveSquared = dx * dx + dy * dy
        let usePointOnly = moveSquared < 0.25

        for enemy in liveEnemies {
            guard enemy.parent != nil else { continue }
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
                recycleProjectile(bullet)
                damageObstacle(enemy, blastPoint: enemy.position)
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
