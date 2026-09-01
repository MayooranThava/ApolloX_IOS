# ApolloX

Portrait SpriteKit shooter for iPhone. Deployment target **iOS 16**. Bundle ID `com.mayooran.ApolloX`.

## Open and run

1. Open `ApolloX.xcodeproj` in Xcode 16 or later (App Store uploads currently need the iOS 26 SDK / Xcode 26).
2. Select the **ApolloX** scheme, an iPhone simulator or device, then Run.

Launch argument for on-device FPS / node counts:

```
-ApolloXShowStats
```

Product → Scheme → Edit Scheme → Run → Arguments. On an iPhone 16/17 Pro this should read ~120 fps when cool; Low Power Mode should drop to 60.

## Tests

Three layers, on purpose. SpriteKit combat is not a good XCUITest target.

| Layer | What it covers | Command |
|---|---|---|
| Sanity (no Xcode) | UX contracts in source + a swept-combat microbench | `python3 scripts/sanity_tests.py` |
| Unit (`ApolloXTests`) | `GameRules`, `ScoreStore`, `GameCenterService`, `AppSettings`, pools, frame pacing | `xcodebuild test -scheme ApolloX -only-testing:ApolloXTests` |
| UI smoke (`ApolloXUITests`) | Cold launch presents the title scene | `xcodebuild test -scheme ApolloX -only-testing:ApolloXUITests` |

Example simulator run:

```bash
xcodebuild test \
  -project ApolloX.xcodeproj \
  -scheme ApolloX \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ApolloXTests \
  -only-testing:ApolloXUITests
```

CI runs the Python gate on Ubuntu and `xcodebuild test` on macOS.

## Phase 1: First TestFlight upload

Repo-side prep for the first archive is done. Finish the Apple-side steps on your Mac.

### Already configured in the repo

| Item | Value |
|---|---|
| Bundle ID | `com.mayooran.ApolloX` |
| Team ID | `2YJ478267N` |
| Marketing version | `1.0.1` |
| Build number | `1` (increment `CURRENT_PROJECT_VERSION` before each new upload) |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` (standard HTTPS only) |
| Game Center entitlement | `ApolloX/ApolloX.entitlements` (`com.apple.developer.game-center`) |
| Classic leaderboard ID | `com.mayooran.ApolloX.classicHighScore` (top 5 in **Ranks**) |
| Archive scheme | **ApolloX** → Release (`ArchiveAction` in scheme) |

### Apple Developer portal (one-time)

1. Sign in at [developer.apple.com/account](https://developer.apple.com/account) with the paid membership.
2. **Certificates, Identifiers & Profiles → Identifiers → +** → App IDs → App → register **`com.mayooran.ApolloX`** (explicit App ID).
3. Edit the App ID and enable **Game Center**.
4. In Xcode → **ApolloX** target → **Signing & Capabilities**: Team = your account, **Automatically manage signing** on. Confirm the team ID is `2YJ478267N` and **Game Center** is listed (entitlements file is already in the project).

### Game Center leaderboard (App Store Connect)

Do this before TestFlight if you want live ranks. The app stays playable without it; scores queue until Game Center is available.

1. [App Store Connect](https://appstoreconnect.apple.com) → your app → **Services** / **Game Center** (or **Features → Game Center**).
2. Enable Game Center for the app.
3. **Leaderboards → +** and create:

| Field | Value |
|---|---|
| Reference Name | Classic High Score |
| Leaderboard ID | `com.mayooran.ApolloX.classicHighScore` |
| Format | Integer |
| Score Submission Type | Best Score |
| Sort Order | High to Low |
| Score Range (optional) | `0` – leave max blank or set a sane ceiling |

4. Add a localization (required — fixes “*MISSING TITLE*” in Game Center):
   - Language: English
   - **Name:** `High Score` (must match `AppSettings.classicLeaderboardDisplayName`)
5. Save. On your **app version** (Distribution): enable Game Center, **add this leaderboard** as a component, then save.
6. Leaderboards stay **Pre-release** until that version is submitted / the component is attached. Scores can still work in sandbox TestFlight.

**Device testing:** Settings → Game Center → sign in with a sandbox / real Apple ID. Prefer the in-app **Ranks** screen; Apple’s dashboard shows your localized name once step 4–5 are done.

### App Store legal URLs

Host `docs/privacy-policy.html` and `docs/support.html` (GitHub Pages from `/docs` is fine). Then set:

| Field | URL |
|---|---|
| Privacy Policy | `https://mayooranthava.github.io/ApolloX_IOS/privacy-policy.html` |
| Support | `https://mayooranthava.github.io/ApolloX_IOS/support.html` |

See `docs/README.md`. App Review copy: `docs/app-review-notes.md`. If the Pages URL differs, update `AppSettings.swift` to match.

### Archive and upload (each build)

**Option A — Xcode GUI**

1. Open `ApolloX.xcodeproj` in Xcode 16+ (iOS 26 SDK as of April 2026).
2. Select **Any iOS Device (arm64)** as the run destination.
3. **Product → Archive** (Release).
4. In Organizer: **Distribute App → App Store Connect → Upload**.
5. Export compliance: answer **No** to custom encryption (already declared in the app Info.plist).

**Option B — script**

```bash
./scripts/archive-for-testflight.sh
```

Uses `ExportOptions.plist` at the repo root (automatic signing, team `2YJ478267N`, upload symbols).

After upload, open [App Store Connect](https://appstoreconnect.apple.com) → your app → **TestFlight**. Processing usually takes 5–15 minutes. Add yourself as an internal tester to install on device.

## Remaining to ship

| Priority | Item | Owner | Status |
|---|---|---|---|
| P0 | Settings (sound/haptics) + first-run onboarding | Repo | **Done** |
| P0 | Privacy + support HTTPS pages (`docs/`) + App Store Connect URLs | You | Enable GitHub Pages (workflow in `.github/workflows/pages.yml`) |
| P0 | Leaderboard EN localization **High Score** + attach to version (fixes *MISSING TITLE* / Pre-release) | App Store Connect | Do on phone |
| P0 | Privacy nutrition label + 2026 age rating | App Store Connect | Before submit |
| P0 | 6.7" + 6.1" screenshots / preview video | Device / ASC | Before submit |
| P0 | 15–30 min soak on Pro + 60 Hz iPhone; empty crash reports | Device | Before submit |
| P0 | Game Center end-to-end on production build | Device | Verify on TestFlight |
| P1 | Texture atlas + @3x background | Repo | Partial — texture batch preload done; true @3x BG art still needs artist |
| P1 | Music loop + music/SFX volume sliders | Repo | **Done** |
| P1 | Game Center achievements (10) | Repo + ASC | Code done — create IDs in ASC |
| P1 | Run summary (rank delta, credits, new best) | Repo | **Done** |
| P1 | How to Play from title | Repo | **Done** |
| P1 | Crash reports (Apple Organizer only) | Automatic | No third-party SDK |
| P1 | App Review notes | Repo | **Done** (`docs/app-review-notes.md`) |
| P2 | Plasma grenade speed + top-lane clear when no on-screen targets | Repo | **Done** |
| P2 | Preload hangar weapon hardpoint textures at launch | Repo | **Done** |

Do not add IAP or third-party analytics until there is a product reason.

## Ship checklist (TestFlight → App Store)

Do these on a real phone. The simulator cannot prove ProMotion, haptics, thermal throttling, or full Game Center.

- [ ] Internal TestFlight build installs and launches to the title screen
- [ ] First launch: **Play** opens onboarding → Play starts a run
- [ ] **Settings**: Sound / Music / SFX & Music volume / Haptics; How to Play; Privacy / Support open in Safari
- [ ] Title → **How to Play** opens the onboarding cards without starting a run
- [ ] Play: steer, pause / resume, background the app, confirm it stays paused
- [ ] Boost, health pickup, mine (two hits), and game-over → Restart / Ranks / Menu
- [ ] Title → **Ranks** shows top 5 (or a clear signed-out / empty message)
- [ ] Apple Game Center UI shows **High Score** (not *MISSING TITLE*); Pre-release gone after version attach
- [ ] After a run, game over shows credits, **NEW BEST** when applicable, and rank delta when signed in
- [ ] Background music loops on the title screen; volume sliders work in Settings
- [ ] iPhone 16/17 Pro: 120 Hz with `-ApolloXShowStats`; Low Power Mode: 60 Hz
- [ ] A 60 Hz iPhone (non-Pro) still plays smoothly
- [ ] Silent switch mutes SFX (`AVAudioSession` is `.ambient`); Settings Sound Off mutes too
- [ ] Organizer / TestFlight crash reports are empty after a 15-minute session
- [ ] App Store Connect: privacy nutrition label matches `PrivacyInfo.xcprivacy` (UserDefaults + Game Center User ID / Product Interaction, no tracking)
- [ ] Age rating questionnaire is current (Apple updated this in 2026)
- [ ] Screenshots for 6.7" and 6.1" iPhone match *this* binary
- [ ] Support URL and privacy policy URL load
- [ ] Upload SDK is the one Apple currently requires (iOS 26 SDK as of April 2026)

Leave IAP and third-party analytics out until there is a product reason.

## Repo layout

```
ApolloX/           app target
ApolloXTests/      unit tests (host: ApolloX.app)
ApolloXUITests/    launch smoke only
scripts/           sanity checks + archive-for-testflight.sh
docs/              privacy + support pages for App Store URLs
ExportOptions.plist  App Store Connect export settings
demo/              browser art preview (not the shipping game)
```
