-- ============================================================
-- Milestone: 09_customer_segmentation.sql
-- Customer Segmentation berbasis frekuensi order (heuristik analitik, bukan ML clustering)
-- Depends on: 06_data_modeling.sql (dim_user, fact_orders, fact_order_products)
-- ============================================================

-- ---------- 1. Investigasi distribusi total_orders per user (SEBELUM kunci threshold) ----------
SELECT
    MIN(total_orders) AS min_orders,
    APPROX_QUANTILE(total_orders, 0.33) AS p33,
    APPROX_QUANTILE(total_orders, 0.50) AS median_orders,
    APPROX_QUANTILE(total_orders, 0.66) AS p66,
    MAX(total_orders) AS max_orders,
    COUNT(*) AS total_users
FROM dim_user;


-- ---------- 2. Build customer_segment (threshold LOCKED: P33=7, P66=15, dari query #1) ----------
CREATE OR REPLACE TABLE customer_segment AS
SELECT
    user_id,
    total_orders,
    CASE
        WHEN total_orders <= 7 THEN 'Occasional'
        WHEN total_orders <= 15 THEN 'Regular'
        ELSE 'Frequent Buyer'
    END AS segment
FROM dim_user;

-- Reconciliation check: total tiap segmen harus = total unique user (206,209)
SELECT
    segment,
    COUNT(*) AS n_users,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM customer_segment
GROUP BY segment
ORDER BY n_users DESC;

SELECT COUNT(*) AS total_users_check FROM customer_segment;


-- ---------- 3. Basket size rata-rata per segmen ----------
WITH user_avg_basket AS (
    SELECT user_id, AVG(n_items) AS avg_basket_size
    FROM fact_orders
    WHERE eval_set = 'prior'
    GROUP BY user_id
)
SELECT
    cs.segment,
    ROUND(AVG(uab.avg_basket_size), 2) AS avg_basket_size_per_segment
FROM customer_segment cs
JOIN user_avg_basket uab ON cs.user_id = uab.user_id
GROUP BY cs.segment
ORDER BY avg_basket_size_per_segment DESC;


-- ---------- 4. Reorder rate rata-rata per segmen ----------
WITH user_reorder_rate AS (
    SELECT
        co.user_id,
        ROUND(100.0 * SUM(cop.reordered) / COUNT(*), 2) AS reorder_rate_pct
    FROM fact_order_products cop
    JOIN fact_orders co ON cop.order_id = co.order_id
    WHERE cop.source_set = 'prior'
    GROUP BY co.user_id
)
SELECT
    cs.segment,
    ROUND(AVG(urr.reorder_rate_pct), 2) AS avg_reorder_rate_pct
FROM customer_segment cs
JOIN user_reorder_rate urr ON cs.user_id = urr.user_id
GROUP BY cs.segment
ORDER BY avg_reorder_rate_pct DESC;

-- TODO:
-- 1. Verifikasi threshold p33/p66 di query #2 sudah sesuai hasil query #1
-- 2. Catat hasil final di docs/assumptions.md
-- 3. Lanjut ke sql/10_data_mart.sql
