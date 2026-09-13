-- ============================================================
-- Milestone: 07_eda.sql
-- Basket Size Distribution, Reorder Rate, Time Patterns, Days-Since-Prior Distribution
-- Depends on: 06_data_modeling.sql (dim_product, fact_orders, fact_order_products)
-- ============================================================

-- ---------- 1. Basket Size Distribution (formal, dari fact_orders) ----------
SELECT
    MIN(n_items) AS min_basket,
    MAX(n_items) AS max_basket,
    ROUND(AVG(n_items), 2) AS avg_basket,
    MEDIAN(n_items) AS median_basket,
    APPROX_QUANTILE(n_items, 0.25) AS q1_basket,
    APPROX_QUANTILE(n_items, 0.75) AS q3_basket
FROM fact_orders
WHERE eval_set = 'prior';  -- basket size cuma valid untuk prior (lihat catatan milestone 6)


-- ---------- 2. Reorder Rate Keseluruhan ----------
SELECT
    COUNT(*) AS total_order_product_rows,
    SUM(reordered) AS total_reordered,
    ROUND(100.0 * SUM(reordered) / COUNT(*), 2) AS overall_reorder_rate_pct
FROM fact_order_products;


-- ---------- 3. Reorder Rate per Department ----------
SELECT
    dp.department,
    COUNT(*) AS n_order_product_rows,
    SUM(fop.reordered) AS n_reordered,
    ROUND(100.0 * SUM(fop.reordered) / COUNT(*), 2) AS reorder_rate_pct
FROM fact_order_products fop
JOIN dim_product dp ON fop.product_id = dp.product_id
GROUP BY dp.department
ORDER BY reorder_rate_pct DESC;


-- ---------- 4. Reorder Rate per Aisle (Top 15 by volume) ----------
SELECT
    dp.aisle,
    COUNT(*) AS n_order_product_rows,
    SUM(fop.reordered) AS n_reordered,
    ROUND(100.0 * SUM(fop.reordered) / COUNT(*), 2) AS reorder_rate_pct
FROM fact_order_products fop
JOIN dim_product dp ON fop.product_id = dp.product_id
GROUP BY dp.aisle
ORDER BY n_order_product_rows DESC
LIMIT 15;


-- ---------- 5. Pola Waktu: volume order per day-of-week ----------
-- order_dow: 0-6 (Instacart tidak dokumentasikan mana yang Minggu/Senin -- treat sebagai label siklikal)
SELECT
    order_dow,
    COUNT(*) AS n_orders
FROM fact_orders
GROUP BY order_dow
ORDER BY order_dow;


-- ---------- 6. Pola Waktu: volume order per jam ----------
SELECT
    order_hour_of_day,
    COUNT(*) AS n_orders
FROM fact_orders
GROUP BY order_hour_of_day
ORDER BY order_hour_of_day;


-- ---------- 7. Distribusi days_since_prior_order (cari pola siklus belanja) ----------
SELECT
    days_since_prior_order,
    COUNT(*) AS n_orders
FROM fact_orders
WHERE days_since_prior_order IS NOT NULL
GROUP BY days_since_prior_order
ORDER BY days_since_prior_order;

-- Ringkasan: apakah ada lonjakan di angka siklikal umum (7, 14, 30)?
SELECT
    days_since_prior_order,
    COUNT(*) AS n_orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM fact_orders
WHERE days_since_prior_order IN (7, 14, 30)
GROUP BY days_since_prior_order
ORDER BY days_since_prior_order;

-- ---------- 7b. Cek apakah days_since_prior_order = 30 itu CAPPED VALUE, bukan pola alami ----------
-- Kalau ini cap, distribusi di angka 29 harusnya jauh lebih kecil dari 30 (drop tajam),
-- bukan penurunan gradual seperti angka 25-29 lainnya
SELECT
    days_since_prior_order,
    n_orders
FROM (
    SELECT days_since_prior_order, COUNT(*) AS n_orders
    FROM fact_orders
    WHERE days_since_prior_order BETWEEN 25 AND 30
    GROUP BY days_since_prior_order
)
ORDER BY days_since_prior_order;
-- Kalau 30 jauh lebih tinggi dari 29 (bukan kelipatan wajar dari tren 25->29),
-- itu konfirmasi capped value -> WAJIB dicatat sebagai limitation di assumptions.md,
-- JANGAN diinterpretasikan sebagai "banyak orang belanja tiap 30 hari"

-- TODO:
-- 1. Hasil EDA ini basis untuk milestone 8 (Reorder & Behavior) dan 9 (Segmentation)
-- 2. Perhatikan pola waktu & siklus untuk insight actionable nanti
-- 3. [PENTING] Konfirmasi apakah days_since_prior_order=30 adalah capped value sebelum
--    membuat klaim "siklus belanja bulanan" di insight manapun
