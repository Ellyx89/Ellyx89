#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA_FILE="$ROOT_DIR/db/schema.sql"
SEED_FILE="$ROOT_DIR/db/seed.sql"

if [[ ! -f "$SCHEMA_FILE" ]]; then
  echo "Schema file not found: $SCHEMA_FILE" >&2
  exit 1
fi

if command -v psql >/dev/null 2>&1; then
  : "${DATABASE_URL:?DATABASE_URL is required when using local psql}"
  echo "[validate_sql] Using local psql against DATABASE_URL"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$SCHEMA_FILE"
  if [[ -f "$SEED_FILE" ]]; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$SEED_FILE"
  fi
  echo "[validate_sql] Schema + seed applied successfully"
  exit 0
fi

if command -v docker >/dev/null 2>&1; then
  echo "[validate_sql] psql not found. Falling back to Dockerized postgres client"
  : "${DATABASE_URL:?DATABASE_URL is required for dockerized psql fallback}"
  docker run --rm \
    -v "$ROOT_DIR:/workspace" \
    --network host \
    -e DATABASE_URL="$DATABASE_URL" \
    postgres:16-alpine \
    sh -lc 'psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f /workspace/db/schema.sql && psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f /workspace/db/seed.sql'
  echo "[validate_sql] Schema + seed applied successfully via Docker"
  exit 0
fi

echo "[validate_sql] Neither psql nor docker is available." >&2
echo "Install PostgreSQL client tools (psql) or Docker, then run again." >&2
exit 2
