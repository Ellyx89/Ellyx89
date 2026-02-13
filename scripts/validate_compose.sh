#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${1:-docker-compose.yml}"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "[validate_compose] Compose file not found: $COMPOSE_FILE" >&2
  exit 1
fi

if command -v docker >/dev/null 2>&1; then
  echo "[validate_compose] Using docker compose config"
  docker compose -f "$COMPOSE_FILE" config >/dev/null
  echo "[validate_compose] OK (docker compose config)"
  exit 0
fi

# Fallback checks for environments without Docker.
# This is a structural lint, not a full compose engine validation.
echo "[validate_compose] Docker not found; running structural fallback checks"

required_patterns=(
  '^services:'
  '^\s{2}postgres:'
  '^\s{2}sql-validate:'
  'image:\s+postgres:16-alpine'
  'condition:\s+service_healthy'
  'DATABASE_URL:\s+postgresql://'
  '^volumes:'
)

for pattern in "${required_patterns[@]}"; do
  if ! rg -n "$pattern" "$COMPOSE_FILE" >/dev/null; then
    echo "[validate_compose] Missing expected pattern: $pattern" >&2
    exit 2
  fi
done

echo "[validate_compose] OK (fallback structural checks)"
echo "[validate_compose] Note: full runtime validation still requires Docker (docker compose config)."
