# App Store Connect — finish “Unable to Add for Review”

Void Runner **iOS App Version 1.0** cannot start review until the five items in the pink banner are filled. None of them require a new binary. Fill them in App Store Connect, then **Save**, then **Add for Review**.

Canonical legal URLs (must match `AppSettings.swift` in the shipped app):

| Field | URL |
|---|---|
| Privacy Policy | `https://mayooranthava.github.io/ApolloX_IOS/privacy-policy.html` |
| Support | `https://mayooranthava.github.io/ApolloX_IOS/support.html` |

**Before pasting the privacy URL:** enable GitHub Pages so the link returns 200 (it currently 404s). See [step 0](#0-one-time-publish-the-privacy-policy).

To apply the dashboard fields from the command line (once you have an Admin/App Manager API key), see [Automate with the App Store Connect API](#automate-with-the-app-store-connect-api). The nutrition label still has to be **Published** in the App Privacy web UI — Apple does not expose that over the API.

---

## 0. One-time: publish the privacy policy

1. Open [GitHub Pages settings](https://github.com/MayooranThava/ApolloX_IOS/settings/pages).
2. **Build and deployment → Source** → **GitHub Actions**.
3. Re-run the **GitHub Pages** workflow: [Actions → GitHub Pages](https://github.com/MayooranThava/ApolloX_IOS/actions/workflows/pages.yml) → **Run workflow** on `development` (or wait for the next `docs/` push).
4. Confirm both pages load in a browser:
   - https://mayooranthava.github.io/ApolloX_IOS/privacy-policy.html
   - https://mayooranthava.github.io/ApolloX_IOS/support.html

Until step 4 works, App Review will reject the privacy URL.

---

## 1. Privacy Policy URL + privacy practices (Admin)

Sidebar: **App Store → App Privacy**.

Apple’s banner *“an Admin must provide information about the app’s privacy practices”* means the nutrition label is still empty / unpublished. Sign in as **Account Holder, Admin, or App Manager**. Developer / Marketing / Customer Support cannot complete this section.

### 1a. Privacy Policy URL

1. At the top of App Privacy, paste:

   `https://mayooranthava.github.io/ApolloX_IOS/privacy-policy.html`

2. Leave **Privacy Choices URL** blank.
3. **Save**.

### 1b. Data collection (nutrition label)

**Published answer: Data Not Collected.** That matches `ApolloX/PrivacyInfo.xcprivacy` (empty `NSPrivacyCollectedDataTypes`, UserDefaults access reason `CA92.1` only, `NSPrivacyTracking = false`). High scores / hangar / settings stay on-device. Optional Game Center is processed by **Apple**, not by the developer.

If you ever have to re-publish the label:

1. Click **Get Started** (or **Edit**).
2. **Do you or your third-party partners collect data from this app?**  
   → **No, we do not collect data from this app**.
3. Confirm **Used for Tracking** is off (no `NSUserTrackingUsageDescription`, no ATT).
4. Click **Publish** (Save alone is not enough). The product page should show **Data Not Collected**.

Do **not** declare User ID or Product Interaction on the nutrition label. Those types would disagree with both this policy and the privacy manifest, which App Review checks.

If your Apple ID cannot Publish, an Account Holder / Admin of team **2YJ478267N** must complete 1a–1b.

---

## 2. Content Rights Information

Sidebar: **General → App Information → Content Rights** (or the Content Rights link in the review banner).

| Question | Answer |
|---|---|
| Does this app contain, show, or access third-party content? | **Yes** |
| Do you have all the necessary rights to that content, or are you otherwise permitted to use it, in every App Store country or region? | **Yes** |

**Why Yes / Yes:** the binary includes a third-party display font (`THEBOLDFONT.ttf`, “The Bold Font”) and stock SFX (for example `Laser Gun - sound effect #20.mp3`). Original SpriteKit art, procedural boss FX, and the code are first-party.

Only answer **Yes** on the rights question if those font/SFX licenses actually cover App Store distribution. If a file is unlicensed, replace it before submit — do not answer **No**.

---

## 3. Age ratings (2026 questionnaire)

Sidebar: **General → App Information → Age Ratings → Set Up Age Ratings**.

Void Runner is a cartoon space shooter: ships fire lasers/rockets at asteroids, mines, and bosses. No blood, no realistic humans, no chat, no ads, no IAP, no web browser.

Expected result after Save: **13+** globally (and **12+** on OS versions earlier than 26) because cartoon/fantasy violence and weapons are **Frequent**.

### In-app controls

Leave **Parental Controls** and **Age Assurance** unchecked. Next.

### Capabilities (presence)

| Item | Select? |
|---|---|
| Unrestricted Web Access | No (Settings only opens the privacy/support pages in Safari) |
| User-Generated Content | No |
| Social Media | No (Game Center ranks are not a social feed) |
| Messaging and Chat | No |
| Advertising | No |

### Content frequency

Use **None / Infrequent / Frequent** (not the old Mild/Intense labels).

| Category | Item | Answer |
|---|---|---|
| Mature Themes | Profanity or Crude Humor | **None** |
| Mature Themes | Horror/Fear Themes | **None** |
| Mature Themes | Alcohol, Tobacco, or Drug Use or References | **None** |
| Medical or Wellness | Medical or Treatment Information | **None** |
| Medical or Wellness | Health or Wellness Topics | **None** |
| Sexuality or Nudity | Mature or Suggestive Themes | **None** |
| Sexuality or Nudity | Sexual Content or Nudity | **None** |
| Sexuality or Nudity | Graphic Sexual Content and Nudity | **None** |
| Violence | Cartoon or Fantasy Violence | **Frequent** |
| Violence | Realistic Violence | **None** |
| Violence | Prolonged Graphic or Sadistic Realistic Violence | **None** |
| Violence | Guns or Other Weapons | **Frequent** (ship cannons, lasers, rockets) |
| Chance-Based | Gambling | **None** / unchecked |
| Chance-Based | Simulated Gambling | **None** |
| Chance-Based | Contests | **Infrequent** (optional Game Center high-score board) |
| Chance-Based | Loot Boxes | **None** / unchecked |

Hangar unlocks are earned credits for known ships/weapons — not loot boxes.

### Age categories and override

**Not Applicable.** Do **not** select Made for Kids. Do **not** override higher.

Age Suitability URL: optional — leave blank.

**Save.**

---

## 4. Primary category

Still on **General → App Information → Category**.

| Field | Value |
|---|---|
| Primary Category | **Games** |
| Primary Games subcategory | **Action** |

Save App Information.

---

## 5. Same-page extras that block “Add for Review” next

The banner you screenshotted does not list these, but iOS 1.0 will bounce again without them.

### Version product page (Distribution → iOS App 1.0)

The localization dropdown in the screenshot is **English (Canada)**. Fill at least that locale (and English (US) if it exists).

| Field | Paste this |
|---|---|
| Support URL | `https://mayooranthava.github.io/ApolloX_IOS/support.html` |
| Marketing URL | optional |
| Description | See below |
| Keywords | `space,shooter,arcade,game,ship,boss,asteroid,galaxy` (100-char cap) |
| What’s New | `Initial release.` |
| Copyright | `2026 Mayooran Thavajogarasa` |

**Description:**

```
Void Runner is a portrait arcade space shooter. Drag to steer, auto-fire at asteroids, grab stars for a fire boost, dodge mines, and take down rotating bosses.

Earn credits each run to unlock hulls and weapons in the Hangar. Optional Game Center ranks your high score globally — the game is fully playable signed out.

No ads. No in-app purchases.
```

**Screenshots:** iPhone 6.7" (required) and 6.1" (required). iPad / Watch tabs can stay empty. First three 6.7" shots are the ones shown on the installation sheet.

### App Review Information

Paste `docs/app-review-notes.md`. Demo account: **Not required.** Contact: your Apple ID email + phone.

Export compliance is already `ITSAppUsesNonExemptEncryption = NO` in the binary — answer **No** to custom encryption if asked.

### Game Center on this version

Distribution → Game Center: enable, attach leaderboard `com.mayooran.ApolloX.classicHighScore` (English name **High Score**), optionally attach the ten achievement IDs in `docs/app-review-notes.md`.

---

## After filling

1. App Information → Save.
2. App Privacy → Publish (**Data Not Collected**).
3. Version page → Save.
4. Pink banner gone → **Add for Review** → Submit.

If the banner remains, click **Show Details**. The leftover row is almost always an unpublished privacy label (needs Admin) or a 404 privacy URL (Pages not enabled).

---

## Version 2.0 — archive, attach, then review

Apple groups uploaded IPAs by **marketing version** (`CFBundleShortVersionString` / `MARKETING_VERSION`). That is why Connect can look empty:

| Train | Builds | Notes |
|---|---|---|
| **1.0.1** | 32–39 | Build **39** was attached to the 1.0 listing that went Waiting for Review |
| **1.0** | 40–41 | Cannot attach to a 2.0 version |
| **2.0** | **42+** | This is the train to put in review |

Do **not** submit 2.0 until build **42** is **VALID**. There is no 2.0 IPA until you archive this repo on a Mac.

1. Merge this change, Archive **ApolloX** → **2.0 (42)**, upload to App Store Connect.
2. Wait until the build is **VALID** (processing often 10–30 minutes).
3. Device soak: 60 Hz iPhone 13, iPhone 13 Pro (90 Hz), and a 15/16/17 Pro (120 Hz). Confirm the plasma grenade button sits above the rocket and the ship cannot park under it.
4. Capture 6.7" and 6.1" screenshots from **this** Void Runner binary.
5. App Store Connect → create iOS version **2.0** (copy listing from 1.0). Attach build **42**. Paste `docs/app-review-notes.md`. Enable Game Center on **2.0** and attach leaderboard `com.mayooran.ApolloX.classicHighScore` (EN name **High Score**) plus the ten achievements.
6. Remove version **1.0** from review first — only one iOS version can be in review.
7. Confirm App Privacy is still **Published → Data Not Collected** and both GitHub Pages URLs return 200.
8. Then **Add for Review**.

---

## Replace the in-review binary (Void Runner on device)

Guideline **2.3.8**: the App Store name, home-screen name, launch screen, and title scene must agree. This repo now ships **Void Runner** in all four. Bundle ID stays `com.mayooran.ApolloX`.

Archive **version `2.0` build `43`** (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in the ApolloX target) to replace the in-review 2.0 binary. Do not upload as 1.0 or 1.0.1 — those trains cannot attach to a 2.0 version.

If version **2.0** is **Waiting for Review**, remove it from review, attach build 43 once processing finishes, paste `docs/app-review-notes.md` again, and resubmit.

Also re-run **Actions → GitHub Pages** so the live privacy policy still says Data Not Collected.

---

## Automate with the App Store Connect API

`scripts/asc_fill_review_blockers.py` sets the fields Apple exposes over the API: privacy policy URL, content rights, age rating questionnaire, Games → Action / Arcade, support URL, and listing copy.

1. In App Store Connect → **Users and Access → Integrations → App Store Connect API**, create a key with **Admin** (or App Manager) access. Download the `.p8` once.
2. Export credentials in your shell — do not commit them:

```bash
export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ASC_KEY_ID="XXXXXXXXXX"
export ASC_PRIVATE_KEY="$(cat AuthKey_XXXXXXXXXX.p8)"
```

3. Status only: `python3 scripts/asc_fill_review_blockers.py`
4. Write: `python3 scripts/asc_fill_review_blockers.py --apply`

Apple still does **not** let the API publish the App Privacy nutrition label. After `--apply`, an Admin must open **App Privacy**, choose **Data Not Collected**, and **Publish** so the label matches `PrivacyInfo.xcprivacy`.
