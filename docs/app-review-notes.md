# App Review notes (ApolloX / Void Runner)

Paste the sections below into **App Store Connect → App Review Information → Notes** when submitting.

## Game overview

ApolloX is a portrait space shooter. The player drags to steer, auto-fires at asteroids, collects stars for a fire boost, dodges mines (two hits), and fights four rotating bosses. Credits earned each run unlock ships and weapons in the Hangar (Store).

No login beyond optional **Game Center** for global high scores and achievements. No IAP, ads, or third-party analytics in v1.0.

## Game Center testing

1. Sign in on the test device: **Settings → Game Center** (sandbox Apple ID for TestFlight).
2. Launch ApolloX → **Play** → finish onboarding (or **Settings → How to Play** to replay).
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
| `com.mayooran.ApolloX.score1000` | Legend of ApolloX | Reach score 1000 |
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

## Demo account

**Not required.** No server-side accounts. Game Center is optional.

## Encryption

Standard HTTPS only (`ITSAppUsesNonExemptEncryption = NO`).

## Crash reporting

Apple Organizer / TestFlight crash reports only — no third-party SDK.
