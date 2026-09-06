# AllergyDetect

AI-powered food intelligence and allergy-safety app: a **React Native (Expo) mobile client** and a **FastAPI + PostgreSQL + Redis** backend. Scan food with the camera or a barcode, log meals and symptoms, and get Bayesian allergen-correlation insights, a personal AI coach, daily nutrition scores, streaks, reports, and translated travel allergy cards.

```
┌──────────────────────────────┐        ┌─────────────────────────────────────────┐
│   Expo / React Native app     │        │            FastAPI backend                │
│  (expo-router, RN Reanimated, │ HTTPS  │  routers → services → SQLAlchemy (async)  │
│   React Query, Zustand)       │ ─────► │   auth · scan · food-log · symptoms ·     │
│  camera · barcode · coach SSE │        │   insights · coach(SSE) · reports · …     │
└──────────────────────────────┘        └───────────────┬───────────────┬──────────┘
                                                         │               │
                                              ┌──────────▼───┐   ┌───────▼────────┐
                                              │ PostgreSQL 16 │   │   Redis 7       │
                                              │ (asyncpg)     │   │ tokens/cache/   │
                                              └───────────────┘   │ Celery broker   │
                                                                  └───────┬─────────┘
                                                                  ┌───────▼─────────┐
                                                                  │ Celery worker + │
                                                                  │ beat (jobs)     │
                                                                  └─────────────────┘
        External (key-gated): OpenAI GPT-4o Vision · Open Food Facts · Nutritionix · USDA ·
                              Google Translate · AWS S3 · Expo Push
```

## Prerequisites

- **Node 20+** and **Python 3.12**
- **Docker** (optional — there is a no-Docker local path, see below)
- **Expo CLI** via `npx expo`
- A device/simulator or the **Expo Go** app for the mobile client

## Quick start (Docker)

```bash
cp infra/.env.example infra/.env      # fill in any API keys you have
./start.sh                            # boots postgres, redis, api, worker, beat, then Expo
```

The API is served at `http://localhost:8000` (interactive docs at `/docs`).

## Quick start (no Docker)

`start.sh` automatically falls back to a local, no-sudo setup if Docker is not
available. It uses `scripts/services.sh` to run local Postgres + Redis binaries
and a `uv`-managed Python 3.12 virtualenv:

```bash
./scripts/services.sh start           # start local Postgres (:5432) + Redis (:6379)
cd services/api
uv venv --python 3.12 .venv
uv pip install --python .venv/bin/python -r requirements.txt
.venv/bin/alembic upgrade head
.venv/bin/uvicorn main:app --reload   # http://localhost:8000/docs
```

`./scripts/services.sh {start|stop|status}` manages the datastores.

## Running the mobile app

```bash
cd apps/mobile
npm install
npx expo start                        # press i / a, or scan the QR with Expo Go
```

The API base URL is read from `app.json → expo.extra.apiBaseUrl`
(default `http://localhost:8000/api/v1`). On a physical device, change it to your
machine's LAN IP.

## Environment variables

All live in `infra/.env` (see `infra/.env.example`). Every external integration is
**key-gated** — the app runs without them; features that need a key return a clear
`503` until configured.

| Variable | Used for | Get a key |
| --- | --- | --- |
| `OPENAI_API_KEY` | Camera scanner (GPT-4o Vision), AI coach | https://platform.openai.com |
| `USDA_API_KEY` | USDA food data | https://api.nal.usda.gov |
| `NUTRITIONIX_APP_ID` / `NUTRITIONIX_API_KEY` | Barcode UPC + text search | https://developer.nutritionix.com |
| `GOOGLE_TRANSLATE_API_KEY` | Travel allergy card translation | https://cloud.google.com/translate |
| `AWS_*` / `S3_BUCKET` | Scan image storage (else local disk) | https://aws.amazon.com/s3 |
| `EXPO_ACCESS_TOKEN` | Server-sent push notifications | https://expo.dev |

> Open Food Facts (barcode lookup) needs **no key**.

## Running tests

```bash
cd services/api
.venv/bin/python -m pytest tests/ -v    # macros, grader, correlator, scanner
```

Mobile type-check:

```bash
cd apps/mobile && npx tsc --noEmit
```

## Project structure

```
allergydetect/
├── apps/mobile/        # Expo Router app: screens, components, hooks, stores, lib
├── services/api/       # FastAPI: models, schemas, routers, services, tasks, tests
├── infra/              # docker-compose, .env.example
├── scripts/            # services.sh (no-Docker datastores), seed_food_db.py
├── start.sh            # one-command dev launcher (Docker or local)
└── README.md
```

### Backend layering

- **routers/** — thin HTTP handlers (`/api/v1/...`)
- **services/** — business logic: `macro_calculator`, `food_grader`, `daily_scores`,
  `streak_engine`, `allergen_correlator` (Bayesian), `ai_scanner`, `food_database`,
  `translation_service`, `coach_service`, `report_generator`
- **tasks/** — Celery jobs (correlation, nightly streak validation, weekly reports,
  meal-followup push). When `USE_CELERY=false`, the correlation runs inline.

## Notes & honest caveats

- The reference `infra/docker-compose.yml` is the canonical multi-container setup.
  This repo was also verified end-to-end **without Docker** using local Postgres 16
  and Redis 7 binaries (see `scripts/services.sh`).
- The mobile app uses **Expo-managed equivalents** for a few native modules from the
  original brief (e.g. `expo-camera` for scanning + barcodes instead of
  `react-native-vision-camera`; AsyncStorage instead of MMKV). The HealthKit /
  Google Health hooks are typed wrappers that require a custom dev build on a
  physical device to read real data; they no-op safely in Expo Go.
- The mobile app cannot be exercised in this CI-style environment (no simulator);
  it is verified via `tsc --noEmit`. The backend is verified by a passing pytest
  suite and live smoke tests against real Postgres + Redis.

## License

MIT
