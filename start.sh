#!/bin/bash
# AllergyDetect dev launcher.
# - If Docker is available, uses docker-compose (postgres, redis, api, worker, beat).
# - Otherwise falls back to the local no-Docker setup provisioned under ~/.local
#   (Postgres + Redis binaries managed by scripts/services.sh, API via uv venv).
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo "==> Docker detected — starting full stack via docker-compose"
  cd infra
  docker compose up -d postgres redis
  echo "Waiting for Postgres..."
  sleep 5
  ( cd ../services/api && docker compose -f ../infra/docker-compose.yml run --rm api alembic upgrade head ) || true
  docker compose up -d api worker beat
  echo "==> Backend up at http://localhost:8000 (docs: /docs)"
else
  echo "==> Docker not available — using local services (scripts/services.sh)"
  ./scripts/services.sh start

  export PATH="$HOME/.local/bin:$HOME/.local/node/bin:$PATH"
  cd services/api

  if [ ! -d .venv ]; then
    echo "Creating Python venv..."
    uv venv --python 3.12 .venv
    uv pip install --python .venv/bin/python -r requirements.txt
  fi

  echo "Applying migrations..."
  .venv/bin/alembic upgrade head

  echo "Starting API on http://localhost:8000 ..."
  .venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 &
  API_PID=$!
  cd "$ROOT"
  echo "API PID: $API_PID  (stop with: kill $API_PID && ./scripts/services.sh stop)"
fi

echo "==> Starting Expo (mobile)..."
cd "$ROOT/apps/mobile"
export PATH="$HOME/.local/node/bin:$PATH"
npx expo start
