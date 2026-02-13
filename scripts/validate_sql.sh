#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA_FILE="$ROOT_DIR/db/schema.sql"
SEED_FILE="$ROOT_DIR/db/seed.sql"

if [[ ! -f "$SCHEMA_FILE" ]]; then
  echo "[validate_sql] Schema file not found: $SCHEMA_FILE" >&2
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
    -v "$ROOT_DIR:/workspace:ro" \
    --network host \
    -e DATABASE_URL="$DATABASE_URL" \
    postgres:16-alpine \
    sh -lc 'psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f /workspace/db/schema.sql && psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f /workspace/db/seed.sql'
  echo "[validate_sql] Schema + seed applied successfully via Docker"
  exit 0
fi

# Fallback checks for environments without psql and without Docker.
# This is static validation and does NOT execute SQL.
echo "[validate_sql] Neither psql nor docker is available; running static fallback checks"

required_schema_patterns=(
  '^CREATE TABLE orgs \('
  '^CREATE TABLE locations \('
  '^CREATE TABLE items \('
  '^CREATE TABLE item_lots \('
  '^CREATE TABLE stock_movements \('
  '^CREATE TABLE stock_movement_lines \('
  '^CREATE TABLE lot_allocations \('
  '^CREATE TABLE purchase_orders \('
  '^CREATE TABLE checklist_runs \('
  '^CREATE TABLE notifications \('
)

for pattern in "${required_schema_patterns[@]}"; do
  if ! rg -n "$pattern" "$SCHEMA_FILE" >/dev/null; then
    echo "[validate_sql] Missing expected schema pattern: $pattern" >&2
    exit 2
  fi
done

if [[ -f "$SEED_FILE" ]]; then
  if ! rg -n '^INSERT INTO org_members' "$SEED_FILE" >/dev/null; then
    echo "[validate_sql] Seed file exists but expected org_members insert not found" >&2
    exit 2
  fi
fi

echo "[validate_sql] OK (static fallback checks)"
echo "[validate_sql] Note: install psql or Docker for full runtime SQL execution validation."
