# ApolloX tests

## Quick sanity checks (no Xcode required)

```bash
python3 scripts/sanity_tests.py
```

Validates UX contracts against source (lives, sprites, opening grace, pause, boost, ProMotion plumbing) and runs a late-game swept-combat microbench.

## XCTest (Mac / CI with Xcode)

```bash
xcodebuild test \
  -project ApolloX.xcodeproj \
  -scheme ApolloX \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ApolloXTests \
  -only-testing:ApolloXUITests
```

| Target | File | Role |
|---|---|---|
| `ApolloXTests` | `GameRulesTests.swift` | Pure gameplay rules |
| `ApolloXTests` | `ScoreStoreTests.swift` | High score persistence (isolated `UserDefaults`) |
| `ApolloXUITests` | `LaunchSmokeTests.swift` | Cold launch shows the title scene |

GitHub Actions runs both the Python gate and `xcodebuild test` on every pull request.
