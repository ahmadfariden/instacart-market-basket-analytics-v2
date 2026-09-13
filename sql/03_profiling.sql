-- ============================================================
-- Milestone: 03_profiling.sql
-- Structure Analysis, Missing Values, Duplicates, Data Quality Assessment
-- Depends on: 02_data_collection.sql (tabel harus sudah ada di sesi ini)
-- ATURAN WAJIB: cardinality pakai COUNT(DISTINCT ...) exact, JANGAN SUMMARIZE
-- (SUMMARIZE DuckDB terbukti meleset: aisles 131 vs 134, departments 19 vs 21,
--  product_id 45,031 vs 49,677 -- lihat evidence di docs/assumptions.md)
-- ============================================================

-- ---------- 1. [EVIDENCE, sudah dieksekusi] Missing values check ----------
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(days_since_prior_order) AS missing_days_since_prior,
    ROUND(100.0 * (COUNT(*) - COUNT(days_since_prior_order)) / COUNT(*), 2) AS pct_missing
FROM orders;

-- Cross-check: missing days_since_prior_order HARUS cuma terjadi di order_number = 1
-- (dicatat di roadmap sebagai 🔲 belum divalidasi -- dieksekusi sekarang)
SELECT
    COUNT(*) AS rows_with_null_days_since_prior,
    COUNT(*) FILTER (WHERE order_number = 1) AS null_at_order_number_1,
    COUNT(*) FILTER (WHERE order_number != 1) AS null_at_other_order_number  -- harus 0
FROM orders
WHERE days_since_prior_order IS NULL;


-- ---------- 2. [EVIDENCE, sudah dieksekusi] Duplicate check (grain order_id+product_id) ----------
SELECT
    (SELECT COUNT(*) FROM order_products_prior) AS total_rows_prior,
    (SELECT COUNT(*) FROM (SELECT DISTINCT order_id, product_id FROM order_products_prior)) AS distinct_grain_prior;

SELECT
    (SELECT COUNT(*) FROM order_products_train) AS total_rows_train,
    (SELECT COUNT(*) FROM (SELECT DISTINCT order_id, product_id FROM order_products_train)) AS distinct_grain_train;


-- ---------- 3. [EVIDENCE, sudah dieksekusi] eval_set validation ----------
SELECT
    eval_set,
    COUNT(*) AS n_orders,
    COUNT(*) FILTER (WHERE order_id IN (SELECT DISTINCT order_id FROM order_products_prior)) AS in_prior,
    COUNT(*) FILTER (WHERE order_id IN (SELECT DISTINCT order_id FROM order_products_train)) AS in_train
FROM orders
GROUP BY eval_set;


-- ---------- 4. [BELUM DIEKSEKUSI] Cardinality exact check (bukan SUMMARIZE) ----------
SELECT
    (SELECT COUNT(DISTINCT aisle_id) FROM aisles) AS exact_aisles,
    (SELECT COUNT(*) FROM aisles) AS exact_aisles_rowcount,
    (SELECT COUNT(DISTINCT department_id) FROM departments) AS exact_departments,
    (SELECT COUNT(*) FROM departments) AS exact_departments_rowcount,
    (SELECT COUNT(DISTINCT product_id) FROM products) AS exact_product_id;


-- ---------- 5. [BELUM DIEKSEKUSI] Outlier investigation: add_to_cart_order ----------
SELECT
    'prior' AS source,
    MIN(add_to_cart_order) AS min_val,
    MAX(add_to_cart_order) AS max_val,
    ROUND(AVG(add_to_cart_order), 2) AS avg_val,
    MEDIAN(add_to_cart_order) AS median_val,
    APPROX_QUANTILE(add_to_cart_order, 0.99) AS p99_val
FROM order_products_prior
UNION ALL
SELECT
    'train',
    MIN(add_to_cart_order),
    MAX(add_to_cart_order),
    ROUND(AVG(add_to_cart_order), 2),
    MEDIAN(add_to_cart_order),
    APPROX_QUANTILE(add_to_cart_order, 0.99)
FROM order_products_train;

-- Distribusi basket size (jumlah produk per order) -- basis untuk EDA & outlier context
WITH basket_size AS (
    SELECT order_id, COUNT(*) AS n_items
    FROM order_products_prior
    GROUP BY order_id
)
SELECT
    MIN(n_items) AS min_basket,
    MAX(n_items) AS max_basket,
    ROUND(AVG(n_items), 2) AS avg_basket,
    MEDIAN(n_items) AS median_basket,
    APPROX_QUANTILE(n_items, 0.95) AS p95_basket,
    APPROX_QUANTILE(n_items, 0.99) AS p99_basket
FROM basket_size;

-- Berapa banyak order dengan basket size ekstrem besar (calon investigasi outlier)
WITH basket_size AS (
    SELECT order_id, COUNT(*) AS n_items
    FROM order_products_prior
    GROUP BY order_id
)
SELECT
    COUNT(*) FILTER (WHERE n_items = (SELECT MAX(add_to_cart_order) FROM order_products_prior)) AS orders_at_max_cart_order,
    COUNT(*) FILTER (WHERE n_items > 50) AS orders_basket_over_50,
    COUNT(*) FILTER (WHERE n_items > 100) AS orders_basket_over_100
FROM basket_size;


-- ---------- 6. [BELUM DIEKSEKUSI] Profil products/aisle_id/department_id ----------
-- Cek referential integrity: apakah semua aisle_id/department_id di products valid
SELECT
    COUNT(*) AS total_products,
    COUNT(*) FILTER (WHERE aisle_id NOT IN (SELECT aisle_id FROM aisles)) AS products_invalid_aisle,
    COUNT(*) FILTER (WHERE department_id NOT IN (SELECT department_id FROM departments)) AS products_invalid_department
FROM products;

-- TODO setelah profiling lengkap:
-- 1. Tentukan keputusan penanganan outlier add_to_cart_order/basket size (-> milestone 04)
-- 2. Catat semua angka final di docs/assumptions.md
