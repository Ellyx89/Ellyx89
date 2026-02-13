-- Demo seed data for KitchenOps Pro MVP
WITH created_org AS (
  INSERT INTO orgs (name, default_locale) VALUES ('KitchenOps Demo Group', 'el') RETURNING id
),
created_location AS (
  INSERT INTO locations (org_id, name, timezone)
  SELECT id, 'Athens Central Kitchen', 'Europe/Athens' FROM created_org
  RETURNING id, org_id
),
created_users AS (
  INSERT INTO users (email, full_name, locale) VALUES
    ('exec@kitchenops.demo', 'Executive Chef Demo', 'el'),
    ('store@kitchenops.demo', 'Storekeeper Demo', 'en')
  RETURNING id, email
)
INSERT INTO org_members (org_id, user_id, role)
SELECT co.id, cu.id,
  CASE WHEN cu.email LIKE 'exec%' THEN 'executive_chef'::role_code ELSE 'storekeeper'::role_code END
FROM created_org co CROSS JOIN created_users cu;

INSERT INTO suppliers (org_id, name, email)
SELECT o.id, 'Fresh Foods SA', 'orders@freshfoods.demo' FROM orgs o WHERE o.name = 'KitchenOps Demo Group';

INSERT INTO storage_areas (org_id, location_id, name, type)
SELECT l.org_id, l.id, area_name, area_type::storage_type
FROM locations l,
LATERAL (VALUES ('Dry Store', 'dry'), ('Cold Room A', 'chill'), ('Freezer 1', 'freeze')) AS x(area_name, area_type)
WHERE l.name = 'Athens Central Kitchen';

INSERT INTO items (org_id, name, base_unit, category, reorder_point, min_par, max_par, storage_type)
SELECT o.id, i.name, i.base_unit, i.category, i.reorder_point, i.min_par, i.max_par, i.storage_type::storage_type
FROM orgs o,
LATERAL (
  VALUES
    ('Tomatoes', 'kg', 'Produce', 8, 10, 25, 'chill'),
    ('Olive Oil', 'lt', 'Dry Goods', 4, 5, 15, 'dry'),
    ('Chicken Breast', 'kg', 'Protein', 12, 15, 40, 'freeze')
) AS i(name, base_unit, category, reorder_point, min_par, max_par, storage_type)
WHERE o.name = 'KitchenOps Demo Group';
