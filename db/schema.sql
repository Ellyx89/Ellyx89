-- KitchenOps Pro MVP schema (PostgreSQL)
-- Default strategy: FEFO (expiry first) then FIFO fallback.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE role_code AS ENUM (
  'executive_chef', 'head_chef', 'sous_chef', 'storekeeper', 'controller', 'fnb_manager', 'admin'
);

CREATE TYPE storage_type AS ENUM ('dry', 'chill', 'freeze');
CREATE TYPE checklist_input_type AS ENUM ('text', 'number', 'temp', 'yesno', 'option');
CREATE TYPE checklist_run_status AS ENUM ('open', 'submitted', 'approved', 'rejected');
CREATE TYPE corrective_action_status AS ENUM ('open', 'done');
CREATE TYPE signoff_entity_type AS ENUM ('checklist_run', 'sop_version', 'receiving');
CREATE TYPE po_status AS ENUM ('draft', 'submitted', 'approved', 'rejected', 'sent', 'partially_received', 'received', 'closed');
CREATE TYPE movement_type AS ENUM ('receipt', 'consume', 'waste', 'transfer', 'adjustment', 'count');
CREATE TYPE reference_type AS ENUM ('po', 'receiving', 'waste_log', 'recipe', 'stock_count', 'manual');
CREATE TYPE service_period AS ENUM ('breakfast', 'lunch', 'dinner', 'all_day', 'event');
CREATE TYPE notification_type AS ENUM ('LOW_STOCK', 'MISSING_HACCP', 'PO_NEEDS_APPROVAL', 'CHECKLIST_REJECTED');
CREATE TYPE lot_status AS ENUM ('open', 'quarantined', 'closed');

CREATE TABLE orgs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  default_locale TEXT NOT NULL DEFAULT 'en',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  address TEXT,
  timezone TEXT NOT NULL DEFAULT 'Europe/Athens',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  locale TEXT NOT NULL DEFAULT 'en',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE org_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role role_code NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, user_id)
);

CREATE TABLE suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE storage_areas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type storage_type NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT,
  base_unit TEXT NOT NULL,
  yield_pct NUMERIC(6,2) NOT NULL DEFAULT 100,
  storage_type storage_type,
  allergens TEXT,
  barcode TEXT,
  supplier_sku TEXT,
  vat_rate NUMERIC(6,2) DEFAULT 0,
  cost_method TEXT NOT NULL DEFAULT 'moving_avg',
  reorder_point NUMERIC(12,3) NOT NULL DEFAULT 0,
  min_par NUMERIC(12,3) NOT NULL DEFAULT 0,
  max_par NUMERIC(12,3) NOT NULL DEFAULT 0,
  lead_time_days INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE purchase_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  supplier_id UUID NOT NULL REFERENCES suppliers(id),
  po_number TEXT NOT NULL,
  status po_status NOT NULL DEFAULT 'draft',
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  submitted_at TIMESTAMPTZ,
  approved_at TIMESTAMPTZ,
  approved_by UUID REFERENCES users(id),
  rejected_at TIMESTAMPTZ,
  rejected_by UUID REFERENCES users(id),
  rejection_reason TEXT,
  UNIQUE (org_id, po_number)
);

CREATE TABLE purchase_order_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  po_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES items(id),
  qty NUMERIC(12,3) NOT NULL CHECK (qty > 0),
  unit TEXT NOT NULL,
  expected_unit_cost NUMERIC(12,4) NOT NULL,
  notes TEXT
);

CREATE TABLE item_lots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  storage_area_id UUID REFERENCES storage_areas(id),
  item_id UUID NOT NULL REFERENCES items(id),
  lot_code TEXT NOT NULL,
  received_at TIMESTAMPTZ NOT NULL,
  expiry_at TIMESTAMPTZ,
  unit_cost NUMERIC(12,4) NOT NULL,
  qty_received NUMERIC(12,3) NOT NULL CHECK (qty_received >= 0),
  qty_remaining NUMERIC(12,3) NOT NULL CHECK (qty_remaining >= 0),
  supplier_id UUID REFERENCES suppliers(id),
  po_id UUID REFERENCES purchase_orders(id),
  status lot_status NOT NULL DEFAULT 'open',
  UNIQUE (org_id, location_id, item_id, lot_code)
);

CREATE INDEX idx_item_lots_pick ON item_lots (org_id, location_id, item_id, expiry_at, received_at);

CREATE TABLE stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES users(id),
  type movement_type NOT NULL,
  reference_type reference_type NOT NULL,
  reference_id UUID,
  notes TEXT
);

CREATE TABLE stock_movement_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  stock_movement_id UUID NOT NULL REFERENCES stock_movements(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES items(id),
  qty NUMERIC(12,3) NOT NULL,
  unit TEXT NOT NULL,
  unit_cost NUMERIC(12,4),
  from_storage_area_id UUID REFERENCES storage_areas(id),
  to_storage_area_id UUID REFERENCES storage_areas(id)
);

CREATE TABLE lot_allocations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  stock_movement_line_id UUID NOT NULL REFERENCES stock_movement_lines(id) ON DELETE CASCADE,
  item_lot_id UUID NOT NULL REFERENCES item_lots(id),
  qty NUMERIC(12,3) NOT NULL CHECK (qty > 0)
);

CREATE TABLE recipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  output_qty NUMERIC(12,3) NOT NULL DEFAULT 1,
  output_unit TEXT NOT NULL DEFAULT 'portion',
  yield_pct NUMERIC(6,2) NOT NULL DEFAULT 100,
  prep_loss_pct NUMERIC(6,2) NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE recipe_ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES items(id),
  qty NUMERIC(12,3) NOT NULL CHECK (qty > 0),
  unit TEXT NOT NULL
);

CREATE TABLE waste_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES items(id),
  qty NUMERIC(12,3) NOT NULL CHECK (qty > 0),
  unit TEXT NOT NULL,
  reason TEXT,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  recorded_by UUID NOT NULL REFERENCES users(id)
);

CREATE TABLE checklist_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  frequency TEXT NOT NULL,
  applies_to_location BOOLEAN NOT NULL DEFAULT TRUE,
  applies_to_storage_area BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE checklist_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  template_id UUID NOT NULL REFERENCES checklist_templates(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  input_type checklist_input_type NOT NULL,
  min_value NUMERIC(12,3),
  max_value NUMERIC(12,3),
  required BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE checklist_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  template_id UUID NOT NULL REFERENCES checklist_templates(id),
  scheduled_for DATE NOT NULL,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  status checklist_run_status NOT NULL DEFAULT 'open',
  created_by UUID NOT NULL REFERENCES users(id)
);

CREATE TABLE checklist_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  run_id UUID NOT NULL REFERENCES checklist_runs(id) ON DELETE CASCADE,
  checklist_item_id UUID NOT NULL REFERENCES checklist_items(id),
  value_text TEXT,
  value_number NUMERIC(12,3),
  value_bool BOOLEAN,
  option_value TEXT,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  recorded_by UUID NOT NULL REFERENCES users(id)
);

CREATE TABLE corrective_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  run_id UUID NOT NULL REFERENCES checklist_runs(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  severity TEXT NOT NULL,
  assigned_to_user_id UUID REFERENCES users(id),
  due_at TIMESTAMPTZ,
  status corrective_action_status NOT NULL DEFAULT 'open',
  closed_at TIMESTAMPTZ
);

CREATE TABLE signoffs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  entity_type signoff_entity_type NOT NULL,
  entity_id UUID NOT NULL,
  signed_by_user_id UUID NOT NULL REFERENCES users(id),
  signed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  signature_note TEXT
);

CREATE TABLE fridge_units (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  storage_area_id UUID REFERENCES storage_areas(id),
  name TEXT NOT NULL,
  min_temp_c NUMERIC(5,2) NOT NULL,
  max_temp_c NUMERIC(5,2) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE temperature_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  fridge_unit_id UUID NOT NULL REFERENCES fridge_units(id) ON DELETE CASCADE,
  logged_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  temp_c NUMERIC(5,2) NOT NULL,
  recorded_by UUID NOT NULL REFERENCES users(id),
  out_of_range BOOLEAN NOT NULL DEFAULT FALSE,
  notes TEXT
);

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type notification_type NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  link_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  read_at TIMESTAMPTZ
);

CREATE TABLE menu_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  recipe_id UUID REFERENCES recipes(id),
  default_portion_qty NUMERIC(12,3) NOT NULL DEFAULT 1,
  take_rate_pct NUMERIC(6,2) NOT NULL DEFAULT 100,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE forecasts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  service_date DATE NOT NULL,
  service_period service_period NOT NULL,
  covers INTEGER NOT NULL,
  notes TEXT,
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE forecast_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  forecast_id UUID NOT NULL REFERENCES forecasts(id) ON DELETE CASCADE,
  menu_item_id UUID NOT NULL REFERENCES menu_items(id),
  expected_orders INTEGER,
  portion_multiplier NUMERIC(8,3) NOT NULL DEFAULT 1
);

CREATE TABLE sop_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  category TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE sop_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  sop_id UUID NOT NULL REFERENCES sop_documents(id) ON DELETE CASCADE,
  version_number INTEGER NOT NULL,
  content_markdown TEXT,
  attachment_url TEXT,
  effective_from DATE,
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (sop_id, version_number)
);

CREATE VIEW v_stock_on_hand AS
SELECT
  il.org_id,
  il.location_id,
  il.item_id,
  SUM(il.qty_remaining) AS on_hand
FROM item_lots il
WHERE il.status = 'open'
GROUP BY il.org_id, il.location_id, il.item_id;

CREATE VIEW v_low_stock AS
SELECT
  soh.org_id,
  soh.location_id,
  soh.item_id,
  soh.on_hand,
  i.reorder_point,
  i.min_par,
  i.max_par,
  GREATEST(i.max_par - soh.on_hand, 0) AS suggested_order_qty
FROM v_stock_on_hand soh
JOIN items i ON i.id = soh.item_id
WHERE soh.on_hand < i.reorder_point OR soh.on_hand < i.min_par;
