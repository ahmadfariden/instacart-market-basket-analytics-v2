-- ============================================================
-- Milestone: 05_validation.sql
-- Data Completeness Check, Internal Consistency Validation
-- Depends on: 04_cleaning.sql (clean_orders, clean_order_products harus ada di sesi ini)
-- ============================================================

-- ---------- 1. Completeness re-check: row count masih utuh setelah cleaning ----------
SELECT
    (SELECT COUNT(*) FROM clean_orders) AS clean_orders_rows,
    (SELECT COUNT(*) FROM orders) AS raw_orders_rows,
    (SELECT COUNT(*) FROM clean_order_products) AS clean_order_products_rows,
    (SELECT COUNT(*) FROM order_products_prior) + (SELECT COUNT(*) FROM order_products_train) AS raw_order_products_rows;


-- ---------- 2. order_number harus berurutan tanpa gap per user ----------
-- Cek: untuk tiap user, urutan order_number harus 1,2,3,...,N tanpa lompat
WITH user_order_check AS (
    SELECT
        user_id,
        COUNT(*) AS n_orders,
        MAX(order_number) AS max_order_number,
        MIN(order_number) AS min_order_number
    FROM clean_orders
    GROUP BY user_id
)
SELECT
    COUNT(*) AS total_users,
    COUNT(*) FILTER (WHERE min_order_number != 1) AS users_not_starting_at_1,
    COUNT(*) FILTER (WHERE max_order_number != n_orders) AS users_with_gap  -- kalau max != count, berarti ada gap/duplikat
FROM user_order_check;


-- ---------- 3. reordered=1 harus berarti user pernah beli produk itu sebelumnya ----------
-- Logika: untuk tiap (user, product) pair, urutkan order berdasarkan order_number.
-- Baris pertama munculnya product itu untuk user tsb HARUS reordered=0.
-- Kalau reordered=1 muncul di baris pertama, itu inkonsistensi.
WITH user_product_orders AS (
    SELECT
        co.user_id,
        cop.product_id,
        co.order_number,
        cop.reordered,
        ROW_NUMBER() OVER (
            PARTITION BY co.user_id, cop.product_id
            ORDER BY co.order_number
        ) AS purchase_sequence
    FROM clean_order_products cop
    JOIN clean_orders co ON cop.order_id = co.order_id
    WHERE cop.source_set = 'prior'  -- fokus ke data yang punya order_number lengkap per user
)
SELECT
    COUNT(*) AS total_first_purchases,
    COUNT(*) FILTER (WHERE reordered = 1) AS first_purchase_marked_as_reorder  -- harus 0 / mendekati 0
FROM user_product_orders
WHERE purchase_sequence = 1;

-- TODO setelah validasi:
-- 1. Kalau users_with_gap / first_purchase_marked_as_reorder > 0, investigasi lebih lanjut
-- 2. Catat hasil di docs/assumptions.md
-- 3. Lanjut ke sql/06_data_modeling.sql
