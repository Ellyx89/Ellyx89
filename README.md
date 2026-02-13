# KitchenOps Pro

Base project assets for a B2B kitchen operations platform with FEFO/FIFO inventory control, HACCP compliance workflows, purchasing approvals, and forecast-driven prep planning.

## Included in this repository
- `db/schema.sql`: multi-tenant PostgreSQL schema for MVP domains.
- `db/seed.sql`: demo seed data for one org/location.
- `i18n/en.json` and `i18n/el.json`: GR/EN translation baseline.
- `docs/IMPLEMENTATION_PLAN.md`: implementation workflow and API suggestions.
- `scripts/validate_sql.sh`: validates schema/seed using local `psql` or Docker fallback.

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
3. Fail with actionable message if neither is installed.

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
