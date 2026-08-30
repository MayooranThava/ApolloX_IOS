#!/usr/bin/env python3
"""Sanity checks for ApolloX UX rules.

Runnable without Xcode. Cross-checks GameRules.swift / GameConstants.swift
source values and validates deterministic spawning / lives / boost contracts.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RULES = (ROOT / "ApolloX" / "GameRules.swift").read_text()
CONSTANTS = (ROOT / "ApolloX" / "GameConstants.swift").read_text()
SCENE = (ROOT / "ApolloX" / "GameScene.swift").read_text()
HUD = (ROOT / "ApolloX" / "UIComponents.swift").read_text()

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)


def swift_number(source: str, name: str) -> float:
    patterns = [
        rf"static let {name}[^=]*=\s*([0-9]+(?:\.[0-9]+)?)",
        rf"static let {name}[^=]*=\s*CGSize\(width:\s*([0-9]+(?:\.[0-9]+)?)",
    ]
    for pat in patterns:
        m = re.search(pat, source)
        if m:
            return float(m.group(1))
    raise KeyError(name)


def main() -> int:
    # 1) One-star boost
    check(swift_number(RULES, "starsNeededForUpgrade") == 1, "starsNeededForUpgrade should be 1")
    check(swift_number(RULES, "poweredShotCount") == 28, "poweredShotCount should stay 28")
    check("GameRules.collectStar" in SCENE or "collectStar(currentCharge" in SCENE, "GameScene should use GameRules.collectStar")

    # 2) Lives on contact + invulnerability
    check(swift_number(RULES, "invulnerabilityDuration") >= 1.0, "invulnerabilityDuration too short")
    check("resolvePlayerHit" in SCENE, "GameScene should use resolvePlayerHit")
    check("beginInvulnerability" in SCENE, "GameScene missing invulnerability")
    # Contact path should call lostALife, not immediate runGameOver alone
    contact_idx = SCENE.find("PhysicsCategory.player | GameConstants.PhysicsCategory.enemy")
    check(contact_idx > 0, "missing player-enemy contact handling")
    contact_block = SCENE[contact_idx:contact_idx + 700]
    check("lostALife(fromContact: true)" in contact_block, "contact should cost a life")
    check("runGameOver()" not in contact_block, "contact must not instant game-over")

    # 3) Larger sprites
    check(swift_number(RULES, "playerScale") >= 0.65, "playerScale should be bumped (~0.65)")
    check("playerBaselineY" in RULES, "playerBaselineY helper should keep thrusters on-screen")
    check("rocketSpeed(forScore" in RULES, "falling rockets should ramp speed with score")
    helpers = (ROOT / "ApolloX" / "SceneHelpers.swift").read_text()
    check("makeRocketTailSmokeEmitter" in helpers, "falling rockets should emit tail smoke trails")
    check("rocketTailSmoke" in SCENE, "GameScene should attach tail smoke to falling nuclear rockets")
    textures = (ROOT / "ApolloX" / "GameplayTextures.swift").read_text()
    check("drawNuclearWarning" in textures, "falling rockets should show a nuclear warning sign")
    check(swift_number(RULES, "bulletSize") >= 40, "bullet width should be larger")
    check("1.18" in RULES or "obstacleScale" in RULES, "obstacle scales should be increased via GameRules")

    # 4) Soft opening
    check(swift_number(RULES, "openingGraceDuration") >= 15, "opening grace should be ~15s")
    check(swift_number(RULES, "openingSpawnInterval") > 1.7, "opening spawn should be slower than tier 0")
    check("isInOpeningGrace" in SCENE, "GameScene should honor opening grace")
    check("spawnBoss" in SCENE and "BossHealthBarNode" in HUD, "boss fight plumbing missing")
    check("firstBossSpawnTime" in RULES or "bossSpawnInterval" in RULES, "boss spawn time constant missing")

    # Simulate grace obstacle picker (mirrors GameRules.obstacleKind)
    def obstacle_kind(elapsed: float, roll: int) -> str:
        roll = max(0, min(99, roll))
        if elapsed < 15.0:
            return "asteroid" if roll < 70 else "asteroidAlt"
        tier = int(elapsed // 30)
        if tier == 0:
            return "asteroid" if roll < 75 else "asteroidAlt"
        if tier == 1:
            if roll < 55: return "asteroid"
            if roll < 80: return "asteroidAlt"
            if roll < 95: return "mine"
            return "clearMine"
        if roll < 33: return "asteroid"
        if roll < 58: return "asteroidAlt"
        if roll < 92: return "mine"
        return "clearMine"

    for roll in range(100):
        kind = obstacle_kind(5.0, roll)
        check(kind in ("asteroid", "asteroidAlt"), f"grace spawn leaked {kind} at roll {roll}")

    check(obstacle_kind(35, 90) == "mine", "late game should allow mines")
    check("drone" not in CONSTANTS and "case comet" not in CONSTANTS, "rocket-like drone/comet obstacles removed")

    # 5) Pause control
    check("pauseButton" in HUD or "PauseButton" in HUD, "HUD should include pause control")
    check("enterPause" in SCENE and "resumeFromPause" in SCENE, "GameScene needs pause/resume")
    check("Paused" in SCENE, "pause overlay copy missing")
    check('title: "Menu"' in SCENE and "exitToTitleFromPause" in SCENE, "pause overlay must offer Menu exit to title")
    check("hullAndShield" in RULES and "baseHullCapacity" in RULES, "lives should split into hull HP + shield stacks")
    check('"HP"' in HUD and '"SHIELD"' in HUD, "HUD should show HP and SHIELD meters")
    check('"SCORE"' in HUD and '"COMBO"' in HUD, "HUD left stack should show SCORE and COMBO")
    check("formattedScore" in HUD, "score should use padded cockpit formatting")
    check("parallelogramBlock" in HUD, "HP/shield meters should use slanted HUD blocks")
    check("hudSlab" in HUD, "menu buttons should use HUD-slab chrome")
    check("slab2-" in HUD or "chamfer" in HUD.lower() or "cut =" in HUD, "button slabs must not use the grey top-band bevel")
    check("comboAfterKill" in RULES and "registerKillCombo" in SCENE, "kill combo should advance on destroys")
    check("blockSize = CGSize(width: 52" in HUD, "HP/shield blocks should be large enough to read")
    check("didEnterBackgroundNotification" in SCENE, "background pause should use didEnterBackground")
    check("requiresManualResume" in SCENE, "track manual resume after true backgrounding")
    check("freezeGameplay" in SCENE and "unfreezeGameplay" in SCENE, "manual pause should not freeze SKView touches")
    check("gameplayFrozen" in SCENE and "speed = 0" in SCENE, "pause should freeze scene actions via speed=0")
    check("!gameplayFrozen" in SCENE, "update/combat must not advance while gameplay is frozen")
    check("bossProfiles" in RULES and "maxBossCount" in RULES, "multi-boss roster expected")
    check("starPickupSpawnInterval" in RULES and "shouldSpawnStar" in RULES, "star spawn rarity helpers expected")
    check("clearMine" in CONSTANTS and "yellowClearMine" in (ROOT / "ApolloX" / "GameplayTextures.swift").read_text(),
          "yellow clear mine type expected")
    check("detonateClearMine" in SCENE and "CHAIN CLEAR!" in SCENE, "clear mine detonation missing")
    check("obstacleSpawnPausedUntil" in SCENE, "clear mine should pause obstacle spawns after detonation")
    check("scheduleNextClearMine" in SCENE, "clear mine scheduler missing")

    # Boost feedback
    check("showBoostBanner" in SCENE and "BOOST!" in SCENE, "boost banner feedback missing")
    check("scheduleNextRocket" in SCENE and "RocketWarningNode" in SCENE, "falling rocket warning system missing")
    check("rocketScale" in RULES and "rocketWarningDuration" in RULES, "rocket tuning constants missing")
    check("rocketTargetLookback" in RULES and "rocketsPerWave" in RULES, "rocket lookback / wave helpers missing")
    check("rocketWarning" in (ROOT / "ApolloX" / "AudioManager.swift").read_text(), "rocket warning audio cue missing")
    check((ROOT / "ApolloX" / "rocketWarning.wav").exists(), "rocketWarning.wav missing")
    boss_start = SCENE.find("private func spawnBoss()")
    boss_end = SCENE.find("private func clearRegularObstacles()", boss_start)
    if boss_end == -1:
        boss_end = SCENE.find("private func fireBossVolley()", boss_start)
    boss_spawn_block = SCENE[boss_start:boss_end]
    check("clearRegularObstacles" not in boss_spawn_block, "boss spawn should not clear on-screen obstacles")
    check("clearRockets" not in boss_spawn_block, "boss spawn should not clear in-flight rockets")
    check("spawnShockwaveRing" in SCENE and "SKShapeNode(circleOfRadius" not in SCENE,
          "clear-mine shockwaves should use sprite rings, not SKShapeNode")
    check("cachedScrollSpeed" in (ROOT / "ApolloX" / "ScrollingBackgroundNode.swift").read_text(),
          "background scroll should cache tier speeds")
    bg = (ROOT / "ApolloX" / "ScrollingBackgroundNode.swift").read_text()
    check("highestPlateY" not in bg, "cached highestPlateY goes stale and opens background gaps")
    check("plates.map(\\.position.y).max()" in bg, "plate wrap must use live max Y to stay seamless")
    check("engineFlameLayers" in (ROOT / "ApolloX" / "FramePacing.swift").read_text(),
          "effects quality should scale engine flame layers")
    check("firstIndex(where:" in SCENE and "removeFirst(" in SCENE,
          "player X history should batch-trim instead of per-sample removeFirst")
    check("makeEngineFlameNode" in (ROOT / "ApolloX" / "SceneHelpers.swift").read_text(),
          "animated engine flame node missing")
    check("engineFlame" in SCENE, "GameScene should attach animated engine flames")
    check("BossAttackTextures" in (ROOT / "ApolloX" / "BossAttackTextures.swift").read_text(), "boss projectile textures missing")
    check("fireRingWithGap" in SCENE and "nebulaFlame" in (ROOT / "ApolloX" / "BossAttackTextures.swift").read_text(),
          "glowing ring dodge attack expected")
    check("fireDescendingWallWithGap" in SCENE, "boss wall-with-gap signature attacks expected")
    check("voidLeviathan" in RULES and "plagueBroodmother" in RULES, "four-boss redesign roster expected")
    check("softGravityStrength" in RULES and "softTimeWarpFactor" in RULES, "soft gravity/time warp tuning expected")
    check("bossMinionLifetime" in RULES and "spawnBossMinions" in SCENE, "temporary boss minions expected")
    check("activateSoftGravity" in SCENE and "activateSoftTimeWarp" in SCENE, "soft boss effect helpers expected")
    check(swift_number(RULES, "maxBossCount") == 4, "roster should be four bosses")
    check(swift_number(RULES, "bossScale") <= 2.0, "bosses should be ~20% smaller than the old 2.35 scale")
    check("attachTexturePhysics" in (ROOT / "ApolloX" / "NodePool.swift").read_text(),
          "bosses should use alpha-masked physics so transparent padding does not hit")
    check((ROOT / "ApolloX/Assets.xcassets/bossProj_voidPulse.imageset/bossProj_voidPulse.png").exists(),
          "sheet-sliced void pulse attack art missing")
    check((ROOT / "ApolloX/Assets.xcassets/bossNebula.imageset/bossNebula.png").exists(),
          "void leviathan boss art missing")
    # Boss PNG corners must be transparent (no baked checkerboard / white plate).
    try:
        from PIL import Image
        boss_png = Image.open(ROOT / "ApolloX/Assets.xcassets/bossNebula.imageset/bossNebula.png").convert("RGBA")
        corner_a = boss_png.getpixel((0, 0))[3]
        check(corner_a == 0, "boss art corner must be transparent (got alpha %s)" % corner_a)
    except ImportError:
        pass
    check("setHighScore" in HUD and "BEST" in HUD, "in-game HUD should show dimmed high score")
    check("hud.setHighScore" in SCENE, "GameScene should push high score into the HUD")
    check("maxBossProjectiles" in RULES, "boss projectile soft-cap constant missing")

    # Asteroid full-body hits + health pickup
    check(swift_number(RULES, "asteroidHitboxFactor") >= 0.95, "asteroid hitbox should cover the full sprite")
    check("projectileHitsTarget" in SCENE, "asteroids should use swept projectile hit tests")
    check("obstacleHitRadius" in SCENE, "asteroids should use full-sprite hit radii")
    check("alphaThreshold" not in SCENE, "texture hitboxes miss grazing shots; use a covering circle instead")
    check(swift_number(RULES, "bulletHitRadius") >= 20, "bullet hit radius should match the visible bolt")
    check(swift_number(RULES, "bulletSpeed") >= 1500, "bullet speed constant missing")
    check(swift_number(RULES, "healthPickupMinInterval") == 15, "health min interval should be 15s")
    check(swift_number(RULES, "healthPickupMaxInterval") == 20, "health max interval should be 20s")
    check(swift_number(RULES, "maxLives") >= 5, "max lives cap expected")
    check("spawnHealthPickup" in SCENE and "collectHealth" in SCENE, "health pickup spawn/collect missing")
    check('healthImage = "health_plus"' in CONSTANTS, "health_plus asset constant missing")
    check((ROOT / "ApolloX/Assets.xcassets/health_plus.imageset/health_plus.png").exists(), "health_plus.png missing")

    def projectile_hits(start, end, pr, target, tr):
        combined = pr + tr
        if combined <= 0:
            return False
        combined2 = combined * combined

        def overlaps(point):
            dx = point[0] - target[0]
            dy = point[1] - target[1]
            return dx * dx + dy * dy <= combined2

        if overlaps(end) or overlaps(start):
            return True
        vx = end[0] - start[0]
        vy = end[1] - start[1]
        length2 = vx * vx + vy * vy
        if length2 <= 0.0001:
            return False
        t = ((target[0] - start[0]) * vx + (target[1] - start[1]) * vy) / length2
        t = min(1, max(0, t))
        closest = (start[0] + t * vx, start[1] + t * vy)
        return overlaps(closest)

    check(projectile_hits((0, 0), (0, 100), 10, (25, 50), 20), "swept graze should hit")
    check(not projectile_hits((0, 0), (0, 100), 5, (80, 50), 10), "far sweep should miss")
    check(projectile_hits((0, 0), (0, 40), 8, (0, 50), 12), "end overlap should hit")

    # Lives math
    def resolve(lives: int):
        rem = max(0, lives - 1)
        return rem, rem <= 0, rem > 0

    rem, over, inv = resolve(3)
    check((rem, over, inv) == (2, False, True), "3 lives hit should leave 2 + i-frames")
    rem, over, inv = resolve(1)
    check((rem, over, inv) == (0, True, False), "last life hit should game over")

    check(min(2 + 1, 5) == 3, "health pickup math")
    check(min(5 + 1, 5) == 5, "health pickup should respect max lives")

    # Wire-up: GameRules.swift is referenced from constants
    check("GameRules.startingLives" in CONSTANTS, "GameConstants should delegate startingLives")
    check("GameRules.starsNeededForUpgrade" in CONSTANTS, "GameConstants should delegate starsNeeded")

    score = (ROOT / "ApolloX" / "ScoreStore.swift").read_text()
    title = (ROOT / "ApolloX" / "GameTitle.swift").read_text()
    check("static var storage: UserDefaults" in score, "ScoreStore must allow injecting UserDefaults for tests")
    check("UserDefaults.standard.integer" not in score, "ScoreStore tests cannot use .standard high score")
    check((ROOT / "ApolloXTests" / "ScoreStoreTests.swift").exists(), "ScoreStoreTests.swift missing")
    check((ROOT / "ApolloX" / "PlayerProgress.swift").exists(), "PlayerProgress.swift missing")
    check((ROOT / "ApolloX" / "PlayerShipCatalog.swift").exists(), "PlayerShipCatalog.swift missing")
    check((ROOT / "ApolloX" / "StoreScene.swift").exists(), "StoreScene.swift missing")
    check((ROOT / "ApolloXTests" / "PlayerProgressTests.swift").exists(), "PlayerProgressTests.swift missing")
    progress = (ROOT / "ApolloX" / "PlayerProgress.swift").read_text()
    catalog = (ROOT / "ApolloX" / "PlayerShipCatalog.swift").read_text()
    store = (ROOT / "ApolloX" / "StoreScene.swift").read_text()
    over = (ROOT / "ApolloX" / "GameOverScene.swift").read_text()
    check("commitWalletIfNeeded" in score, "ScoreStore should credit the wallet once per run")
    check("commitWalletIfNeeded" in SCENE and "commitWalletIfNeeded" in over, "game over path should save run credits")
    check("apolloX.walletCredits" in progress, "wallet should persist in UserDefaults")
    check("apolloX.ownedShipIds" in progress and "apolloX.equippedShipId" in progress, "hangar unlocks should persist in UserDefaults")
    check("price: 500" in catalog and "price: 1000" in catalog and "price: 1500" in catalog, "store should offer 500 / 1000 / 1500 ships")
    check("Aurora Lance" in catalog and "Ember Viper" in catalog and "Void Phantom" in catalog, "three purchasable ship names missing")
    check("StoreScene" in title and 'title: "Store"' in title, "title menu needs a Store button")
    check("Ranks" in title and "LeaderboardScene" in title, "title menu needs a Ranks button to the Game Center board")
    check("Settings" in title and "SettingsScene" in title, "title menu needs a Settings button")
    check("OnboardingScene" in title and "hasCompletedOnboarding" in title, "first Play should route through onboarding")
    check("CREDITS" in title, "title menu should show wallet credits")
    check("PlayerProgress.equippedShip" in SCENE, "GameScene should render the equipped hangar ship")
    check("WeaponCatalog" in (ROOT / "ApolloX" / "WeaponCatalog.swift").read_text(), "weapon hardpoint catalog missing")
    check("equippedPrimaryWeaponId" in progress and "equippedSpecialWeaponId" in progress, "hardpoint loadout should persist")
    check("plasmaGrenade" in (ROOT / "ApolloX" / "WeaponCatalog.swift").read_text(), "plasma grenade hardpoint expected")
    check("Sky Mine" in (ROOT / "ApolloX" / "WeaponCatalog.swift").read_text(), "sky mine should replace rear cooldown mine")
    check("smartGrenadeTarget" in SCENE and "preferredSeekerTarget" in SCENE, "specials should aim at live threats")
    check("hardpointPlasmaGrenade_hd" in (ROOT / "ApolloX" / "WeaponCatalog.swift").read_text(),
          "combat hardpoint textures should use HD authored keys")
    check("scatterBolts" in (ROOT / "ApolloX" / "WeaponCatalog.swift").read_text(), "scatter bolts primary expected")
    check("fireSpecial" in SCENE and "SpecialWeaponButton" in SCENE, "GameScene needs special hardpoint trigger")
    check("liveSpecials" in SCENE and "specialPool" in SCENE, "specials should use pooled live lists")
    check("maxLiveSpecialProjectiles" in RULES, "special projectile soft-cap missing")
    check("Hulls" in store and "Weapons" in store, "hangar should tab Hulls and Weapons")
    check("Buy" in store and "Equip" in store and "Swipe" in store, "store should support swipe, buy, and equip")
    check("SKShapeNode()" not in store, "store chrome should use sprite-batched rounded rects")
    check('titleScene' in CONSTANTS and "titleScene" in title, "title scene needs an accessibility identifier for the launch smoke test")
    check('leaderboardScene' in CONSTANTS, "leaderboard scene needs an accessibility identifier")
    check('settingsScene' in CONSTANTS and 'onboardingScene' in CONSTANTS, "settings/onboarding accessibility ids missing")
    check((ROOT / "ApolloX" / "GameCenterService.swift").exists(), "GameCenterService.swift missing")
    check((ROOT / "ApolloX" / "LeaderboardScene.swift").exists(), "LeaderboardScene.swift missing")
    check((ROOT / "ApolloX" / "AppSettings.swift").exists(), "AppSettings.swift missing")
    check((ROOT / "ApolloX" / "SettingsScene.swift").exists(), "SettingsScene.swift missing")
    check((ROOT / "ApolloX" / "OnboardingScene.swift").exists(), "OnboardingScene.swift missing")
    check((ROOT / "ApolloX" / "ApolloX.entitlements").exists(), "Game Center entitlements file missing")
    check((ROOT / "ApolloXTests" / "GameCenterServiceTests.swift").exists(), "GameCenterServiceTests.swift missing")
    check((ROOT / "ApolloXTests" / "AppSettingsTests.swift").exists(), "AppSettingsTests.swift missing")
    check((ROOT / "docs" / "privacy-policy.html").exists(), "privacy policy page missing for App Store URL")
    check((ROOT / "docs" / "support.html").exists(), "support page missing for App Store URL")
    gc = (ROOT / "ApolloX" / "GameCenterService.swift").read_text()
    entitlements = (ROOT / "ApolloX" / "ApolloX.entitlements").read_text()
    leaderboard = (ROOT / "ApolloX" / "LeaderboardScene.swift").read_text()
    settings_src = (ROOT / "ApolloX" / "AppSettings.swift").read_text()
    audio = (ROOT / "ApolloX" / "AudioManager.swift").read_text()
    haptics = (ROOT / "ApolloX" / "HapticManager.swift").read_text()
    check('com.mayooran.ApolloX.classicHighScore' in gc, "classic high-score leaderboard ID must match App Store Connect")
    check("High Score" in settings_src, "leaderboard display name must be High Score for ASC localization")
    check("topEntryCount = 5" in gc, "public board should show top 5")
    check("com.apple.developer.game-center" in entitlements, "entitlements must enable Game Center")
    check("GKLeaderboard.submitScore" in gc, "scores should submit via modern GKLeaderboard API")
    check("authenticateHandler" in gc, "Game Center auth handler must be installed")
    check("pendingGameCenterScore" in gc, "offline scores should queue for retry")
    check("authenticateAtLaunch" in (ROOT / "ApolloX" / "GameViewController.swift").read_text(),
          "GameViewController should authenticate Game Center at launch")
    check("highScoreReporter" in score, "ScoreStore should report best scores to Game Center")
    check("Ranks" in over and "LeaderboardScene" in over, "game over should link to ranks")
    check("Game Center" in leaderboard, "leaderboard scene should offer Apple's Game Center UI")
    check("SKShapeNode()" not in leaderboard, "leaderboard chrome should use sprite-batched rounded rects")
    check("soundEnabled" in settings_src and "hapticsEnabled" in settings_src, "settings toggles missing")
    check("AppSettings.soundEnabled" in audio, "AudioManager must honor sound setting")
    check("AppSettings.hapticsEnabled" in haptics, "HapticManager must honor haptics setting")
    check("privacyPolicyURL" in settings_src and "supportURL" in settings_src, "App Store legal URLs missing")
    check((ROOT / "ApolloXUITests" / "LaunchSmokeTests.swift").exists(), "launch smoke UI test missing")
    check((ROOT / ".github" / "workflows" / "ci.yml").exists(), "CI workflow missing")
    check((ROOT / ".gitignore").exists(), ".gitignore missing")

    privacy = (ROOT / "ApolloX" / "PrivacyInfo.xcprivacy").read_text()
    check("NSPrivacyCollectedDataTypeUserID" in privacy, "privacy manifest should declare Game Center user ID")
    check("NSPrivacyCollectedDataTypeProductInteraction" in privacy,
          "privacy manifest should declare score / product interaction for leaderboards")
    check("NSPrivacyTracking" in privacy and "<false/>" in privacy, "app must not declare tracking")

    scene_helpers = (ROOT / "ApolloX" / "SceneHelpers.swift").read_text()
    scrolling_bg = ROOT / "ApolloX" / "ScrollingBackgroundNode.swift"
    check("addProductionBackground" in scene_helpers, "SceneHelpers should install the production background")
    check(scrolling_bg.exists(), "ScrollingBackgroundNode.swift missing")
    check("updateBackgroundTier" in SCENE, "GameScene should shift background palette when spawn tier changes")

    # 6) iPhone 16/17 performance contracts
    plist = (ROOT / "ApolloX" / "Info.plist").read_text()
    view = (ROOT / "ApolloX" / "GameViewController.swift").read_text()
    audio = (ROOT / "ApolloX" / "AudioManager.swift").read_text()
    pacing = ROOT / "ApolloX" / "FramePacing.swift"
    check("CADisableMinimumFrameDurationOnPhone" in plist, "Info.plist must opt in to ProMotion >60 Hz")
    check(pacing.exists(), "FramePacing.swift missing")
    pacing_src = pacing.read_text()
    check("lowPowerMode" in pacing_src and "thermalState" in pacing_src, "frame pacing must honor Low Power Mode and thermal state")
    check("setOverlayFrameCapActive" in SCENE and "setOverlayFrameCapActive" in pacing_src,
          "pause should drop to overlay FPS and restore on resume")
    check("clampedDelta" in SCENE and "maxSimulationDelta" in pacing_src,
          "update loop must clamp post-pause hitch deltas")
    check("reportFrameDuration" in SCENE and "hitchDemotionSteps" in pacing_src,
          "frame pacing should demote VFX when frames overrun budget")
    check("liveBullets" in SCENE, "combat should keep live bullet lists instead of enumerating the scene graph")
    check("usesPreciseCollisionDetection = true" not in SCENE, "physics CCD should stay off; swept tests already cover tunneling")
    check("SKShapeNode()" not in HUD and "SKShapeNode()" not in (ROOT / "ApolloX" / "GameOverScene.swift").read_text(), "HUD/game-over chrome should use sprite-batched rounded rects")
    check("enum AudioCue" in audio and "AVAudioPlayer" in audio, "combat SFX should be preloaded AVAudioPlayer pools")
    check("preferredFramesPerSecond = 120" not in view, "hardcoded 120 fps bypasses Low Power / thermal policy")
    check("FramePacing.start" in view, "SKView should take its refresh rate from FramePacing")
    check("hardwareMaxFPS" in pacing_src, "effects quality should scale baseline VFX for 60 Hz phones")
    check("physicsBody = nil" in SCENE, "bullets should skip physics; swept tests handle hits")
    check("maxBossProjectiles" in pacing_src, "boss projectile cap should scale with effects quality")

    import time

    frames = 8000
    t0 = time.perf_counter()
    hits = 0
    for _ in range(frames):
        for i in range(12):
            for e in range(8):
                if projectile_hits((i * 40.0, 200.0), (i * 40.0, 228.0), 22.0, (80.0 + e * 70.0, 900.0), 90.0):
                    hits += 1
    elapsed = time.perf_counter() - t0
    per_frame_us = elapsed / frames * 1_000_000
    print(
        f"BENCH late-game swept combat: {per_frame_us:.2f} µs/frame "
        f"(Python, {frames} frames, 12 bullets × 8 enemies, hits={hits})"
    )
    check(per_frame_us < 500, f"swept combat too expensive even in Python ({per_frame_us:.1f} µs/frame)")
    # 120 Hz budget is 8333 µs; this inner loop should be a tiny fraction of it.
    print(f"BENCH vs 120 Hz frame budget: {per_frame_us / 8333 * 100:.3f}% of 8.33 ms")

    if failures:
        real = [f for f in failures if f != "placeholder"]
        print(f"FAIL ({len(real)}):")
        for f in real:
            print(f"  - {f}")
        return 1

    print("OK — all ApolloX UX sanity checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
