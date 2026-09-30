# Nouri — native iOS app

SwiftUI app for food-trigger detection: photograph a meal → Claude identifies likely ingredients →
log symptoms → a correlation engine surfaces likely triggers → share a **Dine Code** QR with restaurants.
Phase 6 adds skin/fabric reaction tracking and allergy blood test upload (Claude reads the report).

This lives alongside the existing Expo/FastAPI app in this monorepo; it is independent of it.

```
apps/nouri-ios/
  project.yml                 XcodeGen spec (generates Nouri.xcodeproj)
  Nouri/
    App/                      NouriApp (entry, Firebase setup), AppState (single store), RootView
    Models/                   User, MealEntry, SymptomLog, AllergyProfile, SkinLog, BloodworkRecord, DineCode
    Persistence/              LocalDatabase — GRDB/SQLite, offline-first source of truth
    Services/
      ClaudeVisionService     meal photo → ingredient JSON (via Cloud Function) + DemoVisionService
      BloodworkReaderService  lab report PDF/photo → IgE results (via Cloud Function) + DemoBloodworkService
      BloodworkInsights       compares blood test results with the logged patterns
      AllergenDatabase        curated allergen lookup, flags high-risk ingredients offline
      PatternDetectionService correlation engine (food + skin/fabric) + weekly trends
      FirebaseService         Auth, Firestore sync, Storage uploads, Dine Code publishing
      QRCodeService           CoreImage CIQRCodeGenerator
      DineCodeService         token generation + public snapshot
      NotificationService     post-meal check-in reminders
    DesignSystem/             Colors (asset-catalog backed), Typography (serif headings), Components
    Views/                    Onboarding, Home, MealLog, SymptomLog, Skin, Bloodwork, Profile, DineCode
    Resources/Assets.xcassets colour sets with light + dark variants
  NouriTests/                 pattern detection (food + skin), allergen DB, blood work, SQLite round-trip tests
  firebase/
    firestore.rules, storage.rules, firebase.json
    functions/                analyzeMealPhoto + extractBloodworkPanel callables (TypeScript, Anthropic SDK)
    hosting/d/index.html      Dine Code scan page (no app install needed)
```

## Run it

Requirements: Xcode 16+, iOS 17+ target, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd apps/nouri-ios
xcodegen generate
open Nouri.xcodeproj        # Swift packages (Firebase, GRDB) resolve on first open
```

**Without Firebase it runs in demo mode**: data stays on the device, meal photos return a sample
analysis, and Settings → "Load sample history" seeds three weeks of data (a dairy-sensitive user with a
milder shellfish reaction) so the Insights and Dine Code screens have something to show. This is the fastest
way to put it on a phone for a pitch.

### Connect Firebase

1. Create a Firebase project and enable **Authentication → Email/Password**, **Firestore**, **Storage**,
   **Functions** (Blaze plan, needed for outbound calls to the Claude API) and **Hosting**.
2. Add an iOS app with bundle id `com.nouri.app`, download `GoogleService-Info.plist` into
   `apps/nouri-ios/` (a build phase copies it into the app when present; it is git-ignored). The app detects the file and switches out of demo mode.
3. Deploy the backend:
   ```bash
   cd apps/nouri-ios/firebase
   cp .firebaserc.example .firebaserc          # set your project id
   (cd functions && npm install)
   firebase functions:secrets:set ANTHROPIC_API_KEY
   # Push: upload an APNs auth key (.p8) in Firebase console → Project settings → Cloud Messaging.
   firebase deploy --only firestore,storage,functions,hosting
   ```
4. Set `NouriDineCodeBaseURL` in `project.yml` to `https://<project-id>.web.app/d/` and regenerate.
5. Push notifications need a paid Apple Developer account:
   - Set `DEVELOPMENT_TEAM` in `project.yml`. The `aps-environment` entitlement is already declared; switch it to `production` for TestFlight.
   - Create an APNs auth key and upload it to Firebase (step 3).
   - Test on a real device.
   - Post-meal check-ins work without any of this.

## How the pieces work

**Offline-first.** Every write goes to SQLite first and the UI updates immediately. Rows carry a
`needsSync` flag; `FirebaseService.sync` uploads photos to Storage, then writes documents to
`users/{uid}/…`, and clears the flag. Failures leave rows dirty and they retry on the next write or launch.
Signing in on a new device pulls the history down.

**Ingredient recognition.** The app never holds an Anthropic key. It downsizes the photo (≤1568px JPEG)
and calls the `analyzeMealPhoto` callable function. The function checks that the user is signed in, then calls Claude
(`claude-opus-5-5`) with a JSON-schema structured output: `{ dishName, ingredients: [{ name, confidence,
visible }], notes }`. The prompt asks for ingredients that are implied but not visible too (dressings,
oils, butter), since those are often the triggers. It uses server-side refusal fallbacks (`fallbacks: "default"`).
On-device, `AllergenDatabase` tags each ingredient with its allergen groups (the EU 14 major allergens, which include the FDA's 9)
and warns straight away if one matches the user's known allergies. The user edits the list before saving.

**Pattern detection** (`PatternDetectionService`). For each ingredient, and for each allergen group:
- *exposures*: the number of meals that contained it.
- *reactions*: the number of those meals followed by a symptom in the 0–8h window, or linked to the meal explicitly. A
  "no symptoms" log linked to a meal counts as a confirmed negative.
- *baseline*: the reaction rate after meals **without** the ingredient. This stops ingredients that appear everywhere
  (salt, oil) from being flagged.
- **Likely trigger**: ≥3 exposures, a reaction rate of 70% or more, and a rate above the baseline. **Watching**: ≥2 exposures and a rate of 50% or more.
- **Confidence** = rate × specificity (how much of the rate the baseline can't explain) × sample-size
  weight (full weight at 5 exposures) × a small boost for severity.
  Every number is shown to the user on the trigger detail screen. All thresholds are in `Configuration`.

**Dine Code.** The QR holds only `https://<host>/d/<token>`. The token is 22 random base62
characters (~131 bits). It is the id of a public `dineCodes/{token}` document, which contains only a first name
and the list of things to avoid. Firestore rules allow `get` but never `list`, so a code can't be
guessed or enumerated. When the profile changes, the snapshot is rewritten, so a printed QR stays current.
"Create new code" revokes the old token. The scan page is plain HTML that reads the document through the Firestore REST
API, follows the device's light/dark setting, and prints cleanly. In demo mode, the profile goes into the URL fragment
instead, so the same page works with no backend.

**Skin & fabric (phase 6).** A skin log lists what touched the skin that day — products (moisturiser,
detergent), fabrics (wool, polyester) and materials (nickel, latex) — and how the skin reacted, including
"no reaction". Each log is one exposure event, and `PatternDetectionService.analyzeSkin` scores every item with
the same rules as foods (≥3 logs, ≥70% reaction rate, above the baseline of the user's other days). Products
roll up to the `skin` domain, fabrics and materials to `fabric`. Skin triggers are kept separate from food
triggers, so they never appear on the Dine Code. Logs can include a photo, body areas and severity.

**Blood work (phase 6).** The user scans a paper report (VisionKit document camera, multi-page → PDF),
uploads a PDF, or picks a photo. The app sends it to the `extractBloodworkPanel` callable, which passes it
to Claude as a `document` (PDF) or `image` block with a JSON schema: `{ testDate, labName, results: [{ allergen,
value, comparator, unit, reportedClass }], notes }`. The model transcribes values and bounds ("<0.10") exactly
and never computes classes itself. Every row is then shown for the user to check and edit before saving. Classes
the report doesn't state are derived on-device from the standard ImmunoCAP thresholds (`IgEScale`). The original
file is kept on-device and uploaded to `users/{uid}/bloodwork/`. On Insights → Blood work, `BloodworkInsights`
compares the latest result per allergen with the food patterns and shows one of three outcomes:
- **Agrees**: sensitised, and the logs show the pattern.
- **Sensitised only**: sensitised, but the logs don't show it.
- **Pattern, but blood test negative**: often an intolerance, not an IgE allergy.

Food results of class 2 or higher are added to the Dine Code as "Positive blood test".

**Reminders and push.** There are two kinds of notification.
- **Post-meal check-ins are local.** Logging a meal schedules an on-device notification three hours later, asking
  how the user feels. It fires even when the app is closed or the phone is offline. Tapping it opens the symptom log
  linked to that meal.
- **Server pushes use FCM (APNs underneath).**
  - After sign-in, the app registers with APNs, hands the token to Firebase Messaging, and stores the FCM token at
    `users/{uid}/devices/{token}`. That document holds the user's preferences, time zone and UTC offset, and is
    refreshed on every launch so DST and travel are picked up.
  - The `sendScheduledPushes` function runs every hour. It finds the devices whose reminder hour is now (a
    collection-group query on `reminderUtcHour`), then:
    - **Sunday:** sends a weekly summary of meals, reactions and the top likely trigger. Tapping it opens Insights.
    - **Other days:** sends an evening reminder only if nothing at all was logged since local midnight. Tapping it
      opens meal logging.
  - Dead tokens are deleted when FCM rejects them. Sign-out deletes the device document and the FCM token.
  - Users control all of this in Profile → Notifications (on/off toggles and a reminder time).

## Tests

`NouriTests` covers:
- the correlation engine for food and skin
- the allergen matcher
- IgE class thresholds and parsing of the report reader's output
- the blood-test-vs-logs comparison
- a SQLite round trip of the phase 6 tables Run them with ⌘U in Xcode, or:

```bash
xcodebuild test -project Nouri.xcodeproj -scheme Nouri -destination 'platform=iOS Simulator,name=iPhone 16'
```

Functions: `cd firebase/functions && npm run typecheck && npm test`. The tests cover the push scheduling helpers.

## Next

- Read ingredient labels on skin products (a photo of the back of the bottle through the same Claude pipeline).
  That would let fragrance, lanolin or preservatives be tracked across different products.
