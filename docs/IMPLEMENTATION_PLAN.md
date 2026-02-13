# KitchenOps Pro — MVP Technical Plan

## Locked decisions
- Product name: **KitchenOps Pro**.
- Picking strategy: **FEFO first**, with **FIFO fallback** when expiry is missing.
- Audience: B2B kitchen operations teams (Executive Chef, Head Chef, Sous Chef, Storekeeper, Controller, F&B).

## Modules covered
1. Multi-tenant foundation (`org_id` everywhere, optional `location_id`).
2. Inventory + lots + stock movement ledger + lot allocations.
3. Purchasing and PO approval workflow (submit/approve/reject + partial receiving).
4. Recipes, food cost, portion/yield support.
5. HACCP checklists with runs/responses/corrective actions/sign-offs.
6. Fridge/freezer units, temperature logs, out-of-range alerts.
7. Notifications center + daily digest (low stock, missing HACCP, POs awaiting approval).
8. Forecast covers → prep list generation.
9. SOP library with versioning, attachments, sign-offs.
10. Reports + export/import hooks (CSV/PDF in application layer).
11. i18n baseline (Greek/English).

## Backend workflow notes
- **Stock source of truth**: `stock_movements` + `stock_movement_lines` with explicit lot allocations in `lot_allocations`.
- **Auto allocation**:
  - Sort candidate lots by `(expiry_at IS NULL) ASC, expiry_at ASC, received_at ASC`.
  - Decrement `qty_remaining` per lot in a transaction.
  - Allow manual lot override in UI.
- **PO lifecycle rules**:
  - `draft -> submitted` (creator)
  - `submitted -> approved/rejected` (approver roles)
  - `approved -> sent`
  - Receiving only from `approved|sent`, with partial receipts setting `partially_received` until completion.
- **HACCP approval**:
  - Staff submit run.
  - Configured approver roles approve/reject.
  - Rejection can generate corrective actions.

## Suggested API endpoints (MVP)
- `/api/orgs/:orgId/items` CRUD + CSV import
- `/api/orgs/:orgId/purchase-orders` CRUD + status transitions
- `/api/orgs/:orgId/receivings` create receiving against PO + lots
- `/api/orgs/:orgId/stock-movements` create consume/waste/transfer with FEFO/FIFO allocation
- `/api/orgs/:orgId/checklists/templates` CRUD
- `/api/orgs/:orgId/checklists/runs` create/submit/approve/reject
- `/api/orgs/:orgId/notifications` list/read
- `/api/orgs/:orgId/reports/*` (inventory valuation, low stock, purchase summary, waste, HACCP compliance, missing checklists, prep lists)
- `/api/orgs/:orgId/forecasts` CRUD + prep-list generation

## Jobs/automation
- Daily cron per location timezone:
  - missing HACCP checks by frequency
  - low stock checks
  - pending PO approvals
  - send digest + store in notifications

## UI priorities (tablet/mobile kitchen use)
- Big numeric inputs for receiving and temp logging.
- Fast-save pattern for checklist responses.
- Approvals inbox page for PO/checklist approvals.
- Reports page with explicit `Export PDF` and `Export CSV` actions.

