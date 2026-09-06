# Demo Status — as of 5 Sept 2026 (overnight pass)

Read this first. It covers what actually works right now, what's mocked and
why, what still needs a real key, and the exact boot commands for tomorrow's
demo.

## TL;DR for tomorrow

Everything below works **without any API keys**. The camera scanner shows a
realistic mocked result (clearly logged server-side as DEMO MODE, not hidden)
instead of calling OpenAI. Barcode scanning is 100% real (Open Food Facts,
no key needed). The core differentiator — Bayesian allergen correlation — is
fully real and works end-to-end.

## What works end-to-end right now (verified tonight via curl)

- **Auth**: register / login / refresh / logout / `/auth/me` — all real, Postgres-backed.
- **Onboarding data**: profile, goals, macro recommendation, allergy list (add/list/delete) — all real.
- **Food logging**: manual entry, `/food-log/today` (totals, goal progress, daily scores), history, frequent ingredients, delete — all real.
- **Symptom logging**: `/symptoms` auto-links to food logs in the prior 0–8h window — real.
- **Bayesian allergen correlation (the core differentiator)**: `/insights/trigger-correlation` → `/insights/allergen-candidates` returns a real ranked list with confidence scores and human-readable labels (e.g. "30% likely trigger"). Confirmed working with a shrimp/shellfish scenario.
- **Camera food scanner** (`POST /api/v1/scan/camera`): returns a valid, schema-correct response. **Currently running in DEMO MODE** (see below) because no OpenAI key is configured — see "Mocked" section.
- **Barcode scanner** (`POST /api/v1/scan/barcode`): fully real, hits Open Food Facts (no key required). Verified tonight with a real UPC (Nutella) — returns real nutrition facts, NutriScore, NOVA group, allergens, and correctly cross-references against the user's allergy profile.
- **Allergen cross-referencing + food grading**: verified against both the camera-scan mock and the real barcode lookup — correctly flags confirmed/probable allergens and produces an A–E grade with a breakdown.
- **Coach daily insight** (`/coach/daily-insight`): has a built-in deterministic fallback ("Log at least two meals today…") when no OpenAI key is set — confirmed returns 200, not an error.
- **Mobile app**: typechecks clean (`npx tsc --noEmit`), boots in Expo web preview with no bundling errors (1268 modules). All screens read tonight (welcome, onboarding x6, home dashboard, scan) are wired correctly — no broken imports, no missing components, no placeholder/lorem-ipsum data.
- **`apps/mobile/lib/api.ts` audit**: every endpoint the app calls was cross-checked against every `@router.*` decorator in `services/api/routers/*.py`. All 30+ calls match real backend routes exactly — **no mismatches found**, nothing needed fixing here.

## What's mocked/stubbed, and why

### Camera scanner — DEMO MODE fallback (new tonight)

`services/api/services/ai_scanner.py`: `analyze_food_image()` now checks
`settings.openai_api_key` before calling GPT-4o Vision. If it's empty/unset,
it returns a hardcoded but schema-correct response (`DEMO_MODE_MOCK_RESPONSE`)
— a "grilled chicken salad" with parmesan (dairy) and sesame-ginger dressing
(sesame) flagged as allergen candidates, so the demo has something visually
interesting to show (grade, allergen warnings, macro breakdown all populate).

This is clearly commented as DEMO MODE in the code, and every time it fires
it logs a `logger.warning(...)` that says explicitly this is a hardcoded
fixture, not a real analysis of the uploaded image. It does **not** catch or
mask real OpenAI errors — a configured key that fails (rate limit, timeout,
bad response) still raises/fails normally, it's only the "no key configured"
case that's mocked. Verified tonight end-to-end via curl: register → add
allergies (milk, sesame) → POST a real JPEG to `/scan/camera` → got the mock
dish back → allergen cross-reference correctly flagged both milk and sesame
as "confirmed" → grade calculated (B, 72). Log line confirming the fallback
fired is in `/tmp/allergydetect_api.log`.

**If Ayaan wants the real thing for the demo**: put a real key in
`services/api/.env` under `OPENAI_API_KEY=` and restart the API — no code
changes needed, the real path is untouched and still there.

### Text food search (Nutritionix) — NOT mocked, degrades honestly

`POST /api/v1/scan/text` returns a real `503` with a clear message
("NUTRITIONIX credentials are not configured...") when no key is set. The
mobile UI already catches this and shows an "Unavailable" alert. I left this
as an honest failure rather than mocking it, since the task only asked for
the camera scanner to get a demo fallback — happy to add a similar mock here
if wanted, but wasn't asked to and didn't want to overreach.

### Coach chat (`/coach/chat`, streaming)

Also OpenAI-gated (`services/coach_service.py`). Without a key it 503s; the
mobile `useCoach` hook catches this and shows "Sorry, I couldn't reach the
coach service." — a reasonable degraded UX, left untouched. `/coach/daily-insight`
has its own deterministic fallback already built in (see above), so the home
screen's "coach tip" card always has content even with no key.

## What needs a real key to be fully real

| Feature | Env var(s) | Behavior without key |
|---|---|---|
| Camera food scanner (real vision analysis) | `OPENAI_API_KEY` | DEMO MODE mock (see above) |
| AI coach chat + weekly summary | `OPENAI_API_KEY` | 503 / deterministic fallback tip |
| Text/manual food search | `NUTRITIONIX_APP_ID`, `NUTRITIONIX_API_KEY` | Honest 503 |
| Travel allergy card translation | `GOOGLE_TRANSLATE_API_KEY` | Untested tonight — not in scope, worth a quick check before demo if that screen is shown |
| Scan image storage in S3 (vs local disk) | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `S3_BUCKET` | Falls back to local disk under `/tmp/allergydetect-media` — fine for a demo, images just aren't durable/shared |
| Push notifications | `EXPO_ACCESS_TOKEN` | Registration endpoint still returns 200, just can't actually deliver a push |
| Barcode scan | none | Fully real already (Open Food Facts) |

## Changes made tonight

1. **`services/api/.env`**: already existed but only had the four blank
   external-API keys — was silently relying on the insecure hardcoded
   `dev-insecure-secret-change-me` JWT default in `config.py`. Filled in
   `JWT_SECRET` / `JWT_REFRESH_SECRET` with freshly generated random strings,
   and made `DATABASE_URL` / `REDIS_URL` / `USE_CELERY` explicit (previously
   implicit via defaults) so the file is now self-documenting. All the
   external API keys (`OPENAI_API_KEY`, `NUTRITIONIX_*`, `GOOGLE_TRANSLATE_API_KEY`,
   `USDA_API_KEY`, AWS, `EXPO_ACCESS_TOKEN`) are left blank as instructed.
   **Note**: this rotates the JWT secret, so any access/refresh tokens issued
   before tonight are now invalid — nobody had a real session running, so
   this shouldn't matter, but if something was logged in before, they'll need
   to log in again.
2. **`services/api/services/ai_scanner.py`**: added the DEMO MODE fallback
   described above (`DEMO_MODE_MOCK_RESPONSE`, `_demo_mode_response()`), gated
   at the top of `analyze_food_image()`. Real GPT-4o Vision code path is
   fully intact below it, untouched.
3. Restarted the API process after these changes so they took effect (old
   PID 89913 killed, new PID from `uvicorn`, same log file
   `/tmp/allergydetect_api.log`).
4. Ran the full pytest suite after the change — all 20 tests still pass.
5. Reviewed `apps/mobile/lib/api.ts`, all `hooks/*.ts`, and the key screens
   (`welcome.tsx`, all 6 onboarding screens, `(tabs)/index.tsx`,
   `(tabs)/scan.tsx`, `store/auth.ts`, `store/user.ts`) — no bugs found, no
   changes needed. Everything was already wired correctly.

## Not touched / flagged, not fixed

- Google Translate travel allergy card (`app/travel-card.tsx`,
  `/translation/*` routes) — not read closely tonight, out of the explicit
  scope of screens listed in the task. Worth a 5-minute look before the demo
  if that feature is going to be shown, since it's untested end-to-end.
- Reports (`/reports/weekly`, `/reports/monthly`, `/reports/yearly-wrapped`)
  and community feed/recipes — not exercised tonight, but their endpoint
  wiring in `api.ts` matches the routers 1:1 so they're very likely fine;
  just didn't get a live curl test.
- This project has **no git repository** (confirmed with `git status`
  tonight — "fatal: not a git repository"). Left as-is; not initializing one
  without Ayaan's say-so.

## Exact commands to boot everything for a demo

```bash
# 1. Local Postgres + Redis (already installed, no Docker on this machine)
cd /Users/ayaanmohammed/Projects/AllergyDetect
./scripts/services.sh status   # start them if not already running

# 2. Backend API
cd services/api
export PATH="$HOME/.local/bin:$PATH"
.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
# -> http://localhost:8000/docs for interactive API docs

# 3. Mobile app (Expo web preview — good enough for a browser-based demo)
cd apps/mobile
export PATH="$HOME/.local/node/bin:$PATH"
CI=1 npx expo start --web --port 19006
# -> http://localhost:19006

# (Optional) run the backend test suite to sanity-check before the demo
cd services/api && .venv/bin/python -m pytest tests/ -v
```

Both processes were left running in the background tonight (backend and
Expo web preview) — check with `curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8000/docs`
and same for `:19006` before assuming they're already up.
