# ApolloX tests

## Quick sanity checks (no Xcode required)

```bash
python3 scripts/sanity_tests.py
```

Validates the five UX contracts against source:
lives-on-contact, larger sprites, opening grace, pause wiring, boost feedback.

## XCTest (Mac / CI with Xcode)

```bash
xcodebuild test \
  -project ApolloX.xcodeproj \
  -scheme ApolloX \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ApolloXTests
```

`ApolloXTests/GameRulesTests.swift` covers pure `GameRules` logic used by `GameScene`.
