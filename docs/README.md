# Legal pages (App Store URLs)

Host these files over HTTPS and paste the URLs into App Store Connect.

## Recommended: GitHub Pages

1. Repo **Settings → Pages**
2. Source: Deploy from branch `development` (or `main`), folder `/docs`
3. After it publishes, use:

| App Store Connect field | URL |
|---|---|
| Privacy Policy | `https://mayooranthava.github.io/ApolloX_IOS/privacy-policy.html` |
| Support URL | `https://mayooranthava.github.io/ApolloX_IOS/support.html` |

Those match `AppSettings.privacyPolicyURL` / `supportURL` in the app. If your Pages URL differs, update both App Store Connect and `AppSettings.swift`.

## Game Center localization (fixes “*MISSING TITLE*”)

1. App Store Connect → **Void Runner** → **Features** → **Game Center** → **Leaderboards**
2. Open leaderboard ID `com.mayooran.ApolloX.classicHighScore`
3. **Add Localization** (English):
   - **Name:** `High Score`
   - Optional formatter / score format as needed
4. Save
5. On the **app version** (Distribution): check **Game Center**, attach this leaderboard, then **Save**
6. Submit the version (or next TestFlight build with the component) so the board leaves **Pre-release**

The numeric ID (e.g. `56560239`) is Apple’s internal id — ignore it once the localized name is set.

## Game Center achievements

Create the ten achievement IDs listed in `docs/app-review-notes.md`, then attach them to the app version before submit. The app reports unlocks when signed in to Game Center.

## App Review notes

Copy from `docs/app-review-notes.md` into App Store Connect → App Review Information → Notes.
