# KitchenOps Pro

Base project assets for a B2B kitchen operations platform with FEFO/FIFO inventory control, HACCP compliance workflows, purchasing approvals, and forecast-driven prep planning.

## Included in this repository
- `db/schema.sql`: multi-tenant PostgreSQL schema for MVP domains.
- `db/seed.sql`: demo seed data for one org/location.
- `i18n/en.json` and `i18n/el.json`: GR/EN translation baseline.
- `docs/IMPLEMENTATION_PLAN.md`: implementation workflow and API suggestions.
- `scripts/validate_sql.sh`: validates schema/seed using local `psql` or Docker fallback.
- `docker-compose.yml`: local PostgreSQL + one-command SQL validation workflow.

## Quick start (database)
```bash
psql "$DATABASE_URL" -f db/schema.sql
psql "$DATABASE_URL" -f db/seed.sql
```

## SQL validation helper
```bash
DATABASE_URL="postgresql://user:pass@host:5432/dbname" ./scripts/validate_sql.sh
```

The helper does:
1. Use local `psql` if installed.
2. Otherwise, use Docker `postgres:16-alpine` as a fallback client.
3. If both are missing, run static fallback checks on `db/schema.sql` and `db/seed.sql` (structure/pattern checks).

> Static fallback mode is useful in restricted environments, but full SQL execution validation still requires `psql` or Docker.

## One-command end-to-end validation (Docker Compose)
Run schema + seed against local PostgreSQL:
```bash
docker compose up --abort-on-container-exit --exit-code-from sql-validate sql-validate
```

Validate compose config (when Docker is installed):
```bash
docker compose config
```

Optional cleanup:
```bash
docker compose down -v
```


## Compose validation without Docker
If Docker is available, run full validation:
```bash
docker compose config
```

If Docker is **not** installed in your environment, run fallback structural checks:
```bash
./scripts/validate_compose.sh
```

This verifies critical compose structure (`services`, `postgres`, `sql-validate`, health dependency, `DATABASE_URL`, volumes).

## How to fix `psql: command not found`

### Ubuntu / Debian
```bash
sudo apt-get update
sudo apt-get install -y postgresql-client
```

### macOS (Homebrew)
```bash
brew install libpq
brew link --force libpq
```

### Windows (Chocolatey)
```powershell
choco install postgresql
```

Then verify:
```bash
psql --version
```

## Notes
- FEFO is the default lot picking strategy, with FIFO fallback.
- Export and import surfaces are represented in schema/plan and should be implemented in the app/service layer.
