-- ============================================================
-- Milestone: 04_cleaning.sql
-- Data Type Correction, Missing Value Handling, Outlier Flagging
-- Depends on: 02_data_collection.sql (tabel harus sudah ada di sesi ini)
-- ============================================================

-- ---------- 1. clean_orders: type correction + flags ----------
CREATE OR REPLACE TABLE clean_orders AS
SELECT
    CAST(order_id AS VARCHAR)      AS order_id,
    CAST(user_id AS VARCHAR)       AS user_id,
    eval_set,
    order_number,
    order_dow,
    CAST(order_hour_of_day AS INTEGER) AS order_hour_of_day,
    days_since_prior_order,
    CASE WHEN order_number = 1 THEN 1 ELSE 0 END AS is_first_order
FROM orders;

SELECT COUNT(*) AS clean_orders_rows FROM clean_orders;

-- Sanity check: is_first_order harus persis = jumlah NULL days_since_prior_order
SELECT
    SUM(is_first_order) AS n_first_order,
    COUNT(*) FILTER (WHERE days_since_prior_order IS NULL) AS n_null_days
FROM clean_orders;


-- ---------- 2. basket_size + is_large_basket flag (per order) ----------
CREATE OR REPLACE TABLE basket_size AS
SELECT
    CAST(order_id AS VARCHAR) AS order_id,
    COUNT(*) AS n_items,
    CASE WHEN COUNT(*) > 50 THEN 1 ELSE 0 END AS is_large_basket
FROM order_products_prior
GROUP BY order_id;

SELECT
    COUNT(*) AS total_orders,
    SUM(is_large_basket) AS n_large_basket
FROM basket_size;


-- ---------- 3. clean_order_products: type correction, gabung prior+train ----------
CREATE OR REPLACE TABLE clean_order_products AS
SELECT
    CAST(order_id AS VARCHAR) AS order_id,
    CAST(product_id AS VARCHAR) AS product_id,
    add_to_cart_order,
    reordered,
    'prior' AS source_set
FROM order_products_prior
UNION ALL
SELECT
    CAST(order_id AS VARCHAR),
    CAST(product_id AS VARCHAR),
    add_to_cart_order,
    reordered,
    'train'
FROM order_products_train;

SELECT COUNT(*) AS clean_order_products_rows FROM clean_order_products;
-- Expected: 32,434,489 + 1,384,617 = 33,819,106


-- ---------- 4. clean_products: type correction ----------
CREATE OR REPLACE TABLE clean_products AS
SELECT
    CAST(product_id AS VARCHAR) AS product_id,
    product_name,
    CAST(aisle_id AS VARCHAR) AS aisle_id,
    CAST(department_id AS VARCHAR) AS department_id
FROM products;

SELECT COUNT(*) AS clean_products_rows FROM clean_products;

-- TODO:
-- 1. clean_orders, clean_order_products, clean_products, basket_size = basis milestone 5 & 6
-- 2. Lanjut ke sql/05_validation.sql
