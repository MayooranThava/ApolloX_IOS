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
| Unit (`ApolloXTests`) | `GameRules`, `ScoreStore`, pools, frame pacing | `xcodebuild test -scheme ApolloX -only-testing:ApolloXTests` |
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
| Archive scheme | **ApolloX** → Release (`ArchiveAction` in scheme) |

### Apple Developer portal (one-time)

1. Sign in at [developer.apple.com/account](https://developer.apple.com/account) with the paid membership.
2. **Certificates, Identifiers & Profiles → Identifiers → +** → App IDs → App → register **`com.mayooran.ApolloX`** (explicit App ID, no extra capabilities needed).
3. In Xcode → **ApolloX** target → **Signing & Capabilities**: Team = your account, **Automatically manage signing** on. Confirm the team ID is `2YJ478267N`.

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
| 1 | Green CI (`ApolloXTests` + launch smoke) | Repo | In this PR |
| 2 | Register Bundle ID + first archive/upload to TestFlight | Mac / App Store Connect | Next |
| 3 | Internal TestFlight on iPhone 16/17 Pro **and** a 60 Hz iPhone | Device / App Store Connect | After upload |
| 4 | Remove or compress unused `gameBGM.wav` (~6.8 MB) | Repo | Not started |
| 5 | Texture atlas + larger / @3x background | Repo | Not started |
| 6 | App Store Connect: privacy nutrition label, 2026 age rating, 6.7" + 6.1" screenshots, support/privacy URLs | App Store Connect | Not started |
| 7 | 15-minute play session, then check TestFlight / Organizer crashes | Device | After TestFlight |

Do not add Game Center, IAP, or analytics until there is a product reason.

## Ship checklist (TestFlight → App Store)

Do these on a real phone. The simulator cannot prove ProMotion, haptics, or thermal throttling.

- [ ] Internal TestFlight build installs and launches to the title screen
- [ ] Play: steer, pause / resume, background the app, confirm it stays paused
- [ ] Boost, health pickup, mine (two hits), and game-over → Restart / Menu
- [ ] iPhone 16/17 Pro: 120 Hz with `-ApolloXShowStats`; Low Power Mode: 60 Hz
- [ ] A 60 Hz iPhone (non-Pro) still plays smoothly
- [ ] Silent switch mutes SFX (`AVAudioSession` is `.ambient`)
- [ ] Organizer / TestFlight crash reports are empty after a 15-minute session
- [ ] App Store Connect: privacy nutrition label matches `PrivacyInfo.xcprivacy` (UserDefaults only, no tracking)
- [ ] Age rating questionnaire is current (Apple updated this in 2026)
- [ ] Screenshots for 6.7" and 6.1" iPhone match *this* binary
- [ ] Support URL and privacy policy URL load
- [ ] Upload SDK is the one Apple currently requires (iOS 26 SDK as of April 2026)

Leave Game Center, IAP, and analytics out until there is a product reason. Each SDK adds a privacy label and crash surface.

## Repo layout

```
ApolloX/           app target
ApolloXTests/      unit tests (host: ApolloX.app)
ApolloXUITests/    launch smoke only
scripts/           sanity checks + archive-for-testflight.sh
ExportOptions.plist  App Store Connect export settings
demo/              browser art preview (not the shipping game)
```
