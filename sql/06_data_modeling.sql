-- ============================================================
-- Milestone: 06_data_modeling.sql
-- Dim_Product, Dim_User, Fact_Order_Products, Fact_Orders
-- Depends on: 04_cleaning.sql (clean_orders, clean_order_products, clean_products, basket_size)
-- Catatan: Instacart sudah relational/wide sejak awal -- tidak perlu EAV-to-Wide atau
-- Category Tree Flattening seperti Retail Rocket (aisle->department cuma 2 level datar)
-- ============================================================

-- ---------- 1. Dim_Product: flatten products + aisles + departments ----------
CREATE OR REPLACE TABLE dim_product AS
SELECT
    p.product_id,
    p.product_name,
    p.aisle_id,
    a.aisle,
    p.department_id,
    d.department
FROM clean_products p
LEFT JOIN aisles a ON CAST(a.aisle_id AS VARCHAR) = p.aisle_id
LEFT JOIN departments d ON CAST(d.department_id AS VARCHAR) = p.department_id;

SELECT COUNT(*) AS dim_product_rows FROM dim_product;
-- Sanity check: harus 0 (referential integrity sudah terbukti bersih di milestone 3)
SELECT COUNT(*) FILTER (WHERE aisle IS NULL OR department IS NULL) AS rows_with_missing_lookup FROM dim_product;


-- ---------- 2. Dim_User: agregat perilaku order per user ----------
-- Catatan: is_frequent_shopper TIDAK dibuat di sini -- threshold segmentasi (persentil 33/66)
-- baru ditentukan di milestone 9 berdasarkan distribusi aktual, bukan angka tebakan sekarang.
-- Di sini cuma disiapkan raw ingredient-nya.
CREATE OR REPLACE TABLE dim_user AS
SELECT
    user_id,
    COUNT(*) AS total_orders,
    MAX(order_number) AS max_order_number,
    ROUND(AVG(days_since_prior_order), 2) AS avg_days_since_prior_order,
    SUM(is_first_order) AS n_first_order_flag  -- sanity: harus selalu 1 per user
FROM clean_orders
GROUP BY user_id;

SELECT COUNT(*) AS dim_user_rows FROM dim_user;
-- Sanity check: total_orders harus = max_order_number (tidak ada gap, sudah divalidasi milestone 5)
SELECT COUNT(*) FILTER (WHERE total_orders != max_order_number) AS users_mismatch FROM dim_user;


-- ---------- 3. Fact_Order_Products: grain order-product ----------
CREATE OR REPLACE TABLE fact_order_products AS
SELECT
    order_id,
    product_id,
    add_to_cart_order,
    reordered,
    source_set
FROM clean_order_products;

SELECT COUNT(*) AS fact_order_products_rows FROM fact_order_products;


-- ---------- 4. Fact_Orders: grain 1 order ----------
CREATE OR REPLACE TABLE fact_orders AS
SELECT
    co.order_id,
    co.user_id,
    co.eval_set,
    co.order_number,
    co.order_dow,
    co.order_hour_of_day,
    co.days_since_prior_order,
    co.is_first_order,
    bs.n_items,
    bs.is_large_basket
FROM clean_orders co
LEFT JOIN basket_size bs ON co.order_id = bs.order_id;

SELECT COUNT(*) AS fact_orders_rows FROM fact_orders;
-- Sanity check: n_items harus NULL cuma untuk order_id yang eval_set != 'prior'
-- (karena basket_size dihitung dari order_products_prior saja)
SELECT
    eval_set,
    COUNT(*) AS n_orders,
    COUNT(*) FILTER (WHERE n_items IS NULL) AS n_missing_basket_size
FROM fact_orders
GROUP BY eval_set;

-- TODO:
-- 1. dim_product, dim_user, fact_order_products, fact_orders = basis milestone 7 (EDA) dst
-- 2. Export ke data/processed/06_*.parquet setelah semua sanity check lolos
