# Nouri — native iOS app

SwiftUI app for food-trigger detection: photograph a meal → Claude identifies likely ingredients →
log symptoms → a correlation engine surfaces likely triggers → share a **Dine Code** QR with restaurants.

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
      AllergenDatabase        curated allergen lookup, flags high-risk ingredients offline
      PatternDetectionService correlation engine + weekly trends
      FirebaseService         Auth, Firestore sync, Storage uploads, Dine Code publishing
      QRCodeService           CoreImage CIQRCodeGenerator
      DineCodeService         token generation + public snapshot
      NotificationService     post-meal check-in reminders
    DesignSystem/             Colors (asset-catalog backed), Typography (serif headings), Components
    Views/                    Onboarding, Home, MealLog, SymptomLog, Profile, DineCode
    Resources/Assets.xcassets colour sets with light + dark variants
  NouriTests/                 pattern detection + allergen DB unit tests
  firebase/
    firestore.rules, storage.rules, firebase.json
    functions/                analyzeMealPhoto callable (TypeScript, Anthropic SDK)
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
   firebase deploy --only firestore,storage,functions,hosting
   ```
4. Set `NouriDineCodeBaseURL` in `project.yml` to `https://<project-id>.web.app/d/` and regenerate.

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

**Reminders.** Logging a meal schedules a local notification three hours later asking how the user feels.
Tapping it opens the symptom log linked to that meal. No server is needed, so remote APNs/FCM can wait until after the MVP.

## Tests

`NouriTests` covers the correlation engine and the allergen matcher. Run them with ⌘U in Xcode, or:

```bash
xcodebuild test -project Nouri.xcodeproj -scheme Nouri -destination 'platform=iOS Simulator,name=iPhone 16'
```

The function: `cd firebase/functions && npm run typecheck`.

## Next (Phase 6)

`SkinLog` and `BloodworkRecord` models and tables are already in place.
- Skin/fabric: reuse `MealLogFlowView`'s capture flow and run `PatternDetectionService` over skin logs with
  `domain: .skin/.fabric`.
- Bloodwork: upload the PDF/photo to Storage, then add an `extractBloodwork` callable that sends it to Claude as
  a `document`/`image` block with a `{ testDate, panelResults: [{ allergen, igeLevel, igeClass }] }` schema.
  Then compare the results with the detected triggers on the Insights screen.
