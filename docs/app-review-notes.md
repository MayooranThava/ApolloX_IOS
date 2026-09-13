# App Review notes (Void Runner)

Paste the sections below into **App Store Connect → App Review Information → Notes** when submitting.

## Game overview

Void Runner is a portrait space shooter. The player drags to steer, auto-fires at asteroids, collects stars for a fire boost, dodges mines (two hits), and fights four rotating bosses. Credits earned each run unlock ships and weapons in the Hangar (Store).

The Xcode target and bundle ID remain `com.mayooran.ApolloX`. The App Store name and on-device display name are **Void Runner**.

No login beyond optional **Game Center** for global high scores and achievements. No IAP, ads, or third-party analytics in v2.0.

## Game Center testing

1. Sign in on the test device: **Settings → Game Center** (sandbox Apple ID for TestFlight).
2. Launch Void Runner → **Play** → finish onboarding (or **Settings → How to Play** to replay).
3. Play a short run and die → **Game Over** shows score and credits.
4. Tap **Ranks** — top 5 global scores load, or a signed-out message if Game Center is unavailable.
5. Tap **Game Center** on the Ranks screen to open Apple’s dashboard (leaderboard ID `com.mayooran.ApolloX.classicHighScore`, localized name **High Score**).
6. After a run with a new personal best, the score submits automatically when signed in.

### Achievements (create in App Store Connect → Game Center → Achievements)

| Achievement ID | Suggested title | How to trigger |
|---|---|---|
| `com.mayooran.ApolloX.firstBoss` | First Boss Down | Defeat any boss (yellow clear mine breaks invulnerability) |
| `com.mayooran.ApolloX.score50` | Rising Pilot | Reach score 50 in one run |
| `com.mayooran.ApolloX.score100` | Ace in Training | Reach score 100 |
| `com.mayooran.ApolloX.score500` | Void Veteran | Reach score 500 |
| `com.mayooran.ApolloX.score1000` | Legend of Void Runner | Reach score 1000 |
| `com.mayooran.ApolloX.fiveLives` | Full Hull | Reach 5 lives (health pickups) |
| `com.mayooran.ApolloX.buyShip` | Hangar Upgrade | Purchase any ship in Store → Hulls |
| `com.mayooran.ApolloX.allBosses` | Boss Slayer | Defeat all 4 bosses in one run |
| `com.mayooran.ApolloX.wallet500` | Credit Hoarder | Hold 500+ credits in wallet |
| `com.mayooran.ApolloX.ranksTop5` | Top Five | Reach global rank 5 or better |

Attach achievements to the app version alongside the leaderboard before submit.

## Settings & legal

- **Settings** (title menu): Sound, Music, SFX/Music volume, Haptics, How to Play, Privacy Policy, Support.
- Privacy Policy: `https://mayooranthava.github.io/ApolloX_IOS/privacy-policy.html`
- Support: `https://mayooranthava.github.io/ApolloX_IOS/support.html`
- App Store Connect fill-in (privacy label, age rating, category, content rights): `docs/app-store-connect.md`

## Demo account

**Not required.** No server-side accounts. Game Center is optional.

## Encryption

Standard HTTPS only (`ITSAppUsesNonExemptEncryption = NO`).

## Crash reporting

Apple Organizer / TestFlight crash reports only — no third-party SDK.

## What App Review will tap (2.1)

Reviewers typically:

1. Cold-launch to the **Void Runner** title (not ApolloX).
2. First launch: **Play** → 3-card How to Play → into a run. Later: **How to Play** from title / Settings without starting a run.
3. Drag to steer, die, **Restart** / **Ranks** / **Menu**.
4. Pause with the in-game button, then Home / app switcher during a run — game must stay paused with **Resume** / **Menu** (physics frozen).
5. Control Center / incoming notification during a run — player must not die while the system overlay is up.
6. **Settings**: Sound / Music / volumes / Haptics; **Privacy Policy** and **Support** open HTTPS pages.
7. **Ranks** signed out: clear message, no crash. Signed in: top 5 + **Game Center** dashboard named **High Score**.
8. **Store**: browse Hulls / Weapons; purchase is optional (credits from runs). No IAP.
9. Rotate / iPad: portrait-only iPhone app. Low Power Mode: still playable.

Demo account: **not required**. Game Center is optional.
