# Nouri: App Store and TestFlight kit

Everything App Store Connect asks for, ready to paste in, followed by the release checklist.
`AppIcon.svg` is the source for the app icon. The rendered 1024 px PNG lives in the asset catalog.

## Listing

| Field | Value |
|---|---|
| **Name** (30) | Nouri: Allergy & Food Tracker |
| **Subtitle** (30) | Find what your body reacts to |
| **Category** | Health & Fitness (secondary: Food & Drink) |
| **Age rating** | 4+ (answer "None" to everything; no medical treatment information is given) |
| **Price** | Free |
| **Privacy policy URL** | `https://<project-id>.web.app/privacy` |
| **Support URL** | `https://<project-id>.web.app/support` |

**Promotional text** (170, can be changed without a new build)
> Snap a meal, log how you feel, and Nouri spots the ingredients behind your reactions. Then share a Dine Code so restaurants know what to avoid.

**Keywords** (100, comma-separated, no spaces)
```
allergy,food diary,intolerance,symptom tracker,trigger,eczema,dairy,gluten,IgE,elimination,restaurant
```

**Description**
```
Nouri helps you work out which foods — and which products and fabrics — your body doesn't agree with.

SNAP YOUR MEALS
Take a photo and Nouri identifies the likely ingredients, including hidden ones like sauces, butter and dressings. Common allergens are flagged instantly. You check and edit everything before it's saved.

LOG HOW YOU FEEL
A quick check-in a few hours after each meal: cough, rash, congestion, tiredness — or nothing at all. "I feel fine" days matter just as much.

SEE YOUR PATTERNS
Nouri counts how often each ingredient comes before a reaction, compared with your other meals, and shows you exactly why something is flagged — no black box.

SKIN & FABRIC
Track reactions to moisturisers, detergents, wool, nickel and more, with photos to compare flare-ups over time.

ALLERGY TEST RESULTS
Scan or upload your IgE blood test. Nouri reads the results for you to confirm, then shows where they agree with your logs — and where they don't.

DINE CODE
One QR code that tells restaurant staff what you need to avoid. They scan it with their camera; no app needed. Revoke it any time.

PRIVATE BY DESIGN
Your data is yours: no ads, no tracking, and you can delete your account and everything in it from inside the app.

Nouri shows patterns in what you log. It isn't a medical device and doesn't diagnose allergies — talk to a clinician before changing your diet or treatment.
```

## App privacy (the "nutrition label")

Answer **Yes, we collect data**. For every type below, choose **Linked to the user**, **Not used for tracking**, and **Purpose: App functionality** only. This matches `Nouri/Resources/PrivacyInfo.xcprivacy`.

| App Store category | Data type | What it is |
|---|---|---|
| Contact info | Name, Email address | Account |
| Health & fitness | Health | Symptoms, reactions, allergies, blood test results |
| User content | Photos or videos | Meal and skin photos, scanned reports |
| User content | Other user content | Notes, products and fabrics listed |
| Identifiers | User ID | Firebase account ID |
| Identifiers | Device ID | Push notification token |

No analytics, advertising or crash-reporting SDKs are included. If you add any later, update both this table and the manifest.

## Notes for App Review

App Review signs in with an account you provide, and it should already have data in it.

**Set up the reviewer account (once):**
1. Choose a dedicated email you control, e.g. `appreview@<your-domain>`.
2. Build with that email in `NOURI_REVIEWER_EMAIL`:
   - **TestFlight workflow:** add a repository variable `NOURI_REVIEWER_EMAIL` (Settings → Secrets and variables → Actions → Variables).
   - **Local Xcode build:** set `NOURI_REVIEWER_EMAIL` under `settings.base` in `project.yml`.
3. Install that build, **sign up with the reviewer email**, and finish onboarding.
4. Open Insights → profile icon → **App Review account → Load sample history**. The app adds about three weeks of history (meals, symptoms, skin logs with scanned labels, and an allergy panel) and syncs it to Firebase, so the reviewer sees it on any device.

The button appears only for that exact email, and only while the account is empty. Nobody else sees it, and it can't load the data twice. The sample dates count back from the day you load them, so do this shortly before submitting. That way the weekly chart looks current when the reviewer opens it.

**Paste into App Store Connect → App Review Information:**
```
Sign-in: appreview@<your-domain> / <password>

Nouri is a symptom and food diary. It shows correlations between what the user logs and how they feel, and it does not diagnose. A disclaimer is shown on the welcome screen and in Profile.

The demo account already has about three weeks of history, so Insights (Food, Skin, Blood work) is populated.
Meal photos, product labels and uploaded allergy reports are analysed by the Claude API (Anthropic) via our Firebase backend; users review all extracted data before saving.
Account deletion: Insights → profile icon → Delete account.
Dine Code: Dine Code tab → Create; scanning the QR opens a web page listing foods to avoid.
```

Don't delete the reviewer account. If it's ever reset, sign up again and reload the sample history.

## Screenshots

App Store Connect needs **6.9" iPhone** screenshots, 1320 × 2868 (iPhone 16 Pro Max / 17 Pro Max). One size is enough; smaller devices reuse them. Use 3 to 10 of them. Suggested order:
1. Today, with meals and a check-in card
2. Ingredient confirmation after a photo, showing allergen flags
3. Insights → Food, with likely triggers and confidence
4. Trigger detail ("the numbers")
5. Insights → Blood work comparison
6. Dine Code QR
7. Insights → Skin

Easiest route: run the demo build in the iPhone 16 Pro Max simulator, load the sample history, and press ⌘S in Simulator to save each screen.

## Release checklist

**One-time setup**
- [ ] Apple Developer Program membership is active. Set `DEVELOPMENT_TEAM` in `project.yml` (or pass it to the workflow as a secret).
- [ ] Choose the final bundle ID (`com.nouri.app` may be taken). Use it in `project.yml`, in Firebase (iOS app), and in App Store Connect.
- [ ] In App Store Connect → Apps → **+ New App**: iOS, name, primary language, bundle ID, SKU (e.g. `nouri-ios`).
- [ ] APNs key uploaded to Firebase (Cloud Messaging). See the main README.
- [ ] Replace `[contact email]` in `firebase/hosting/privacy/` and `support/`, have the privacy policy reviewed, and deploy with `firebase deploy --only hosting,functions`.
- [ ] Set `NouriDineCodeBaseURL` in `project.yml` to your real hosting URL. The privacy and support links in the app are built from it.
- [ ] Create an App Store Connect API key: Users and Access → Integrations → Team keys, role **Admin**. Add these GitHub secrets: `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` and `GOOGLE_SERVICE_INFO_PLIST_B64`. The workflow header explains each one.

**Every TestFlight build**
- [ ] On GitHub: Actions → **Nouri TestFlight** → Run workflow. The build number is the run number, so every upload is unique.
- [ ] Wait for processing (5–30 min). The build then appears under TestFlight in App Store Connect.
- [ ] Internal testers (up to 100 people on your team) can install it right away. External testers (up to 10,000, via a public link) need a one-time beta review of about a day.

**App Store submission**
- [ ] Fill in the listing, privacy answers, age rating and review notes above, and upload the screenshots.
- [ ] Pick the processed build under the version, then **Add for Review**.
- [ ] Health apps get a close look. Expect questions about the disclaimer and the AI analysis; the review notes above answer them.
