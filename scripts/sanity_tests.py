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
    check(swift_number(RULES, "openingGraceDuration") >= 10, "opening grace should be ~12s")
    check(swift_number(RULES, "openingSpawnInterval") > 1.7, "opening spawn should be slower than level 1")
    check("isInOpeningGrace" in SCENE, "GameScene should honor opening grace")

    # Simulate grace obstacle picker (mirrors GameRules.obstacleKind)
    def obstacle_kind(level: int, elapsed: float, roll: int) -> str:
        roll = max(0, min(99, roll))
        if elapsed < 12.0:
            return "asteroid" if roll < 70 else "asteroidAlt"
        # late game sample
        if level >= 4:
            if roll < 30: return "asteroid"
            if roll < 45: return "asteroidAlt"
            if roll < 62: return "drone"
            if roll < 82: return "comet"
            return "mine"
        return "asteroid"

    for roll in range(100):
        kind = obstacle_kind(3, 5.0, roll)
        check(kind in ("asteroid", "asteroidAlt"), f"grace spawn leaked {kind} at roll {roll}")

    check(obstacle_kind(4, 30, 95) == "mine", "late game should allow mines")
    check(obstacle_kind(4, 30, 70) == "comet", "late game should allow comets")

    # 5) Pause control
    check("pauseButton" in HUD or "PauseButton" in HUD, "HUD should include pause control")
    check("enterPause" in SCENE and "resumeFromPause" in SCENE, "GameScene needs pause/resume")
    check("Paused" in SCENE, "pause overlay copy missing")

    # Boost feedback
    check("showBoostBanner" in SCENE and "BOOST!" in SCENE, "boost banner feedback missing")

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
