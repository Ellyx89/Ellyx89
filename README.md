# KitchenOps Pro

Base project assets for a B2B kitchen operations platform with FEFO/FIFO inventory control, HACCP compliance workflows, purchasing approvals, and forecast-driven prep planning.

## Included in this repository
- `db/schema.sql`: multi-tenant PostgreSQL schema for MVP domains.
- `db/seed.sql`: demo seed data for one org/location.
- `i18n/en.json` and `i18n/el.json`: GR/EN translation baseline.
- `docs/IMPLEMENTATION_PLAN.md`: implementation workflow and API suggestions.

## Quick start (database)
```bash
psql "$DATABASE_URL" -f db/schema.sql
psql "$DATABASE_URL" -f db/seed.sql
```

## Notes
- FEFO is the default lot picking strategy, with FIFO fallback.
- Export and import surfaces are represented in schema/plan and should be implemented in the app/service layer.
