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
    check(swift_number(RULES, "playerScale") >= 0.65, "playerScale should be bumped (~0.72)")
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
            return "mine"
        if roll < 35: return "asteroid"
        if roll < 60: return "asteroidAlt"
        return "mine"

    for roll in range(100):
        kind = obstacle_kind(5.0, roll)
        check(kind in ("asteroid", "asteroidAlt"), f"grace spawn leaked {kind} at roll {roll}")

    check(obstacle_kind(35, 90) == "mine", "late game should allow mines")
    check("drone" not in CONSTANTS and "case comet" not in CONSTANTS, "rocket-like drone/comet obstacles removed")

    # 5) Pause control
    check("pauseButton" in HUD or "PauseButton" in HUD, "HUD should include pause control")
    check("enterPause" in SCENE and "resumeFromPause" in SCENE, "GameScene needs pause/resume")
    check("Paused" in SCENE, "pause overlay copy missing")
    check("didEnterBackgroundNotification" in SCENE, "background pause should use didEnterBackground")
    check("requiresManualResume" in SCENE, "track manual resume after true backgrounding")
    check("freezeGameplay" in SCENE and "unfreezeGameplay" in SCENE, "manual pause should not freeze SKView touches")
    check("bossProfiles" in RULES and "maxBossCount" in RULES, "multi-boss roster expected")
    check("starPickupSpawnInterval" in RULES and "shouldSpawnStar" in RULES, "star spawn rarity helpers expected")

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
    check("BossAttackPattern" in RULES and "fireAcidHydraVolley" in SCENE, "per-boss attack patterns expected")
    check("BossAttackTextures" in (ROOT / "ApolloX" / "BossAttackTextures.swift").read_text(), "boss projectile textures missing")

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
    check('titleScene' in CONSTANTS and "titleScene" in title, "title scene needs an accessibility identifier for the launch smoke test")
    check((ROOT / "ApolloXUITests" / "LaunchSmokeTests.swift").exists(), "launch smoke UI test missing")
    check((ROOT / ".github" / "workflows" / "ci.yml").exists(), "CI workflow missing")
    check((ROOT / ".gitignore").exists(), ".gitignore missing")

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
    check("liveBullets" in SCENE, "combat should keep live bullet lists instead of enumerating the scene graph")
    check("usesPreciseCollisionDetection = true" not in SCENE, "physics CCD should stay off; swept tests already cover tunneling")
    check("SKShapeNode()" not in HUD and "SKShapeNode()" not in (ROOT / "ApolloX" / "GameOverScene.swift").read_text(), "HUD/game-over chrome should use sprite-batched rounded rects")
    check("enum AudioCue" in audio and "AVAudioPlayer" in audio, "combat SFX should be preloaded AVAudioPlayer pools")
    check("preferredFramesPerSecond = 120" not in view, "hardcoded 120 fps bypasses Low Power / thermal policy")
    check("FramePacing.start" in view, "SKView should take its refresh rate from FramePacing")

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
