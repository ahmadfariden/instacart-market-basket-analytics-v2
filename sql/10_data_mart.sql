-- ============================================================
-- Milestone: 10_data_mart.sql
-- 8 Mart Tables (untuk 5 halaman dashboard) + Export Parquet
-- Depends on: 06-09 (dim_product, dim_user, fact_orders, fact_order_products,
--             customer_segment harus sudah ada di sesi ini)
-- ============================================================

-- ============================================================
-- MART 1: mart_overview -> Halaman 1 (Overview) -- KPI headline (1 baris)
-- ============================================================
CREATE OR REPLACE TABLE mart_overview AS
SELECT
    (SELECT COUNT(*) FROM fact_orders) AS total_orders,
    (SELECT COUNT(*) FROM dim_user) AS total_users,
    (SELECT COUNT(DISTINCT product_id) FROM dim_product) AS total_products,
    (SELECT ROUND(AVG(n_items), 2) FROM fact_orders WHERE eval_set = 'prior') AS avg_basket_size,
    (SELECT ROUND(100.0 * SUM(reordered) / COUNT(*), 2) FROM fact_order_products) AS overall_reorder_rate_pct;

COPY mart_overview TO 'data/processed/mart_overview.parquet' (FORMAT PARQUET);


-- ============================================================
-- MART 2: mart_reorder_by_department -> Halaman 2 (Reorder & Behavior)
-- ============================================================
CREATE OR REPLACE TABLE mart_reorder_by_department AS
SELECT
    dp.department,
    COUNT(*) AS n_order_product_rows,
    SUM(fop.reordered) AS n_reordered,
    ROUND(100.0 * SUM(fop.reordered) / COUNT(*), 2) AS reorder_rate_pct
FROM fact_order_products fop
JOIN dim_product dp ON fop.product_id = dp.product_id
GROUP BY dp.department
ORDER BY reorder_rate_pct DESC;

COPY mart_reorder_by_department TO 'data/processed/mart_reorder_by_department.parquet' (FORMAT PARQUET);


-- ============================================================
-- MART 2b: mart_reorder_by_aisle -> Halaman 3 (Product & Aisle Performance)
-- PENTING: dibuat karena dashboard chart "Aisle Reorder Rate" sebelumnya salah --
-- pakai Average(reorder_rate_pct) dari mart_product_performance (data per-produk,
-- sudah di-threshold >=20 purchases), bukan weighted rate dari SEMUA baris pembelian
-- di aisle itu. Ini mart yang benar, metodologi sama persis dengan mart_reorder_by_department.
-- ============================================================
CREATE OR REPLACE TABLE mart_reorder_by_aisle AS
SELECT
    dp.aisle,
    COUNT(*) AS n_order_product_rows,
    SUM(fop.reordered) AS n_reordered,
    ROUND(100.0 * SUM(fop.reordered) / COUNT(*), 2) AS reorder_rate_pct
FROM fact_order_products fop
JOIN dim_product dp ON fop.product_id = dp.product_id
GROUP BY dp.aisle
ORDER BY reorder_rate_pct DESC;

COPY mart_reorder_by_aisle TO 'data/processed/mart_reorder_by_aisle.parquet' (FORMAT PARQUET);


-- ============================================================
-- MART 3: mart_reorder_funnel -> Halaman 2 (Reorder & Behavior)
-- ============================================================
CREATE OR REPLACE TABLE mart_reorder_funnel AS
WITH user_product_purchase AS (
    SELECT co.user_id, cop.product_id, COUNT(*) AS n_purchases
    FROM fact_order_products cop
    JOIN fact_orders co ON cop.order_id = co.order_id
    WHERE cop.source_set = 'prior'
    GROUP BY co.user_id, cop.product_id
)
SELECT
    dp.department,
    COUNT(*) AS total_first_purchases,
    COUNT(*) FILTER (WHERE upp.n_purchases >= 2) AS total_reordered_once,
    COUNT(*) FILTER (WHERE upp.n_purchases >= 3) AS total_loyal_repeat,
    ROUND(100.0 * COUNT(*) FILTER (WHERE upp.n_purchases >= 2) / COUNT(*), 2) AS pct_first_to_reorder,
    ROUND(100.0 * COUNT(*) FILTER (WHERE upp.n_purchases >= 3)
          / NULLIF(COUNT(*) FILTER (WHERE upp.n_purchases >= 2), 0), 2) AS pct_reorder_to_loyal
FROM user_product_purchase upp
JOIN dim_product dp ON upp.product_id = dp.product_id
GROUP BY dp.department
ORDER BY total_first_purchases DESC;

COPY mart_reorder_funnel TO 'data/processed/mart_reorder_funnel.parquet' (FORMAT PARQUET);


-- ============================================================
-- MART 4: mart_product_performance -> Halaman 3 (Product & Aisle Performance)
-- LOCKED threshold: minimum 20 purchases (dekat P25 alami = 17)
-- ============================================================

-- Investigasi tambahan: threshold 20 ternyata masih terlalu rentan small-sample bias untuk
-- RANKING (rate tinggi kebetulan gampang muncul di n kecil). Cek dulu berapa produk tersisa
-- di threshold 50 vs 100 sebelum kunci threshold ranking yang terpisah dari threshold data.
SELECT
    COUNT(*) FILTER (WHERE n_purchases >= 50) AS products_above_50,
    COUNT(*) FILTER (WHERE n_purchases >= 100) AS products_above_100,
    COUNT(*) AS total_products_checked
FROM (
    SELECT product_id, COUNT(*) AS n_purchases
    FROM fact_order_products
    WHERE source_set = 'prior'
    GROUP BY product_id
);

CREATE OR REPLACE TABLE mart_product_performance AS
WITH product_stats AS (
    SELECT product_id, COUNT(*) AS n_purchases, SUM(reordered) AS n_reordered
    FROM fact_order_products
    WHERE source_set = 'prior'
    GROUP BY product_id
),
ranked AS (
    SELECT
        dp.product_id,
        dp.product_name,
        dp.aisle,
        dp.department,
        ps.n_purchases,
        ps.n_reordered,
        ROUND(100.0 * ps.n_reordered / ps.n_purchases, 2) AS reorder_rate_pct
    FROM product_stats ps
    JOIN dim_product dp ON ps.product_id = dp.product_id
    WHERE ps.n_purchases >= 20  -- threshold DATA (dipakai untuk mart secara keseluruhan)
)
SELECT
    *,
    -- ranking_eligible: LOCKED, threshold TERPISAH khusus untuk ranking/ordering (bukan
    -- untuk exclude dari mart). Alasan: produk n<100 pembelian terlalu rentan tampil
    -- "reorder rate ekstrem" secara kebetulan (small-sample bias), bukan bukti performa asli.
    CASE WHEN n_purchases >= 100 THEN 1 ELSE 0 END AS ranking_eligible,
    ROW_NUMBER() OVER (ORDER BY reorder_rate_pct DESC, n_purchases DESC) AS sort_rank
FROM ranked;

COPY mart_product_performance TO 'data/processed/mart_product_performance.parquet' (FORMAT PARQUET);


-- ============================================================
-- MART 5: mart_product_pairs -> Halaman 3 (Product & Aisle Performance)
-- Co-occurrence sederhana, dibatasi top 200 produk populer (lihat catatan performa milestone 8)
-- ============================================================
CREATE OR REPLACE TABLE mart_product_pairs AS
WITH top_products AS (
    SELECT product_id
    FROM fact_order_products
    WHERE source_set = 'prior'
    GROUP BY product_id
    ORDER BY COUNT(*) DESC
    LIMIT 200
),
filtered_order_products AS (
    SELECT fop.order_id, fop.product_id
    FROM fact_order_products fop
    WHERE fop.source_set = 'prior'
      AND fop.product_id IN (SELECT product_id FROM top_products)
),
order_pairs AS (
    SELECT a.order_id, a.product_id AS product_a, b.product_id AS product_b
    FROM filtered_order_products a
    JOIN filtered_order_products b
        ON a.order_id = b.order_id AND a.product_id < b.product_id
)
SELECT
    dp_a.product_name AS product_a_name,
    dp_b.product_name AS product_b_name,
    COUNT(*) AS n_cooccurrence
FROM order_pairs op
JOIN dim_product dp_a ON op.product_a = dp_a.product_id
JOIN dim_product dp_b ON op.product_b = dp_b.product_id
GROUP BY dp_a.product_name, dp_b.product_name
ORDER BY n_cooccurrence DESC
LIMIT 50;

COPY mart_product_pairs TO 'data/processed/mart_product_pairs.parquet' (FORMAT PARQUET);


-- ============================================================
-- MART 6: mart_customer_segment -> Halaman 4 (Customer Behavior & Segmentation)
-- LOCKED: mutually exclusive, threshold P33=7/P66=15
-- ============================================================
CREATE OR REPLACE TABLE mart_customer_segment AS
WITH user_avg_basket AS (
    SELECT user_id, AVG(n_items) AS avg_basket_size
    FROM fact_orders WHERE eval_set = 'prior'
    GROUP BY user_id
),
user_reorder_rate AS (
    SELECT co.user_id, ROUND(100.0 * SUM(cop.reordered) / COUNT(*), 2) AS reorder_rate_pct
    FROM fact_order_products cop
    JOIN fact_orders co ON cop.order_id = co.order_id
    WHERE cop.source_set = 'prior'
    GROUP BY co.user_id
)
SELECT
    cs.segment,
    COUNT(*) AS n_users,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total,
    ROUND(AVG(uab.avg_basket_size), 2) AS avg_basket_size,
    ROUND(AVG(urr.reorder_rate_pct), 2) AS avg_reorder_rate_pct
FROM customer_segment cs
JOIN user_avg_basket uab ON cs.user_id = uab.user_id
JOIN user_reorder_rate urr ON cs.user_id = urr.user_id
GROUP BY cs.segment;

COPY mart_customer_segment TO 'data/processed/mart_customer_segment.parquet' (FORMAT PARQUET);


-- ============================================================
-- MART 7: mart_activity_by_time -> Halaman 4 (Customer Behavior & Segmentation)
-- Long-format: gabung order_dow & order_hour_of_day dalam 1 tabel (dimension_type sebagai pembeda)
-- ============================================================
CREATE OR REPLACE TABLE mart_activity_by_time AS
SELECT 'day_of_week' AS dimension_type, CAST(order_dow AS VARCHAR) AS dimension_value, COUNT(*) AS n_orders
FROM fact_orders GROUP BY order_dow
UNION ALL
SELECT 'hour_of_day', CAST(order_hour_of_day AS VARCHAR), COUNT(*)
FROM fact_orders GROUP BY order_hour_of_day;

COPY mart_activity_by_time TO 'data/processed/mart_activity_by_time.parquet' (FORMAT PARQUET);


-- ============================================================
-- MART 8: mart_data_quality_summary -> Halaman 5 (Data Quality & Methodology)
-- LOCKED: kuantitatif saja, teks assumptions/limitations statis di Power BI
-- ============================================================
CREATE OR REPLACE TABLE mart_data_quality_summary AS
SELECT metric, value FROM (
    VALUES
        ('total_orders', 3421083),
        ('total_users', 206209),
        ('total_order_product_rows', 33819106),
        ('duplicate_rows_removed', 0),
        ('products_invalid_aisle_or_department', 0),
        ('users_with_order_number_gap', 0),
        ('first_purchase_marked_as_reorder_error', 0),
        ('missing_days_since_prior_order_pct', 6.03),
        ('large_basket_orders_flagged', 3081),
        ('product_ranking_threshold_purchases', 20),
        ('segment_p33_threshold_orders', 7),
        ('segment_p66_threshold_orders', 15)
) AS t(metric, value);

COPY mart_data_quality_summary TO 'data/processed/mart_data_quality_summary.parquet' (FORMAT PARQUET);


-- ---------- Final sanity check: semua mart ada isinya ----------
SELECT 'mart_overview' AS mart_name, COUNT(*) AS n_rows FROM mart_overview
UNION ALL SELECT 'mart_reorder_by_department', COUNT(*) FROM mart_reorder_by_department
UNION ALL SELECT 'mart_reorder_funnel', COUNT(*) FROM mart_reorder_funnel
UNION ALL SELECT 'mart_product_performance', COUNT(*) FROM mart_product_performance
UNION ALL SELECT 'mart_product_pairs', COUNT(*) FROM mart_product_pairs
UNION ALL SELECT 'mart_customer_segment', COUNT(*) FROM mart_customer_segment
UNION ALL SELECT 'mart_activity_by_time', COUNT(*) FROM mart_activity_by_time
UNION ALL SELECT 'mart_data_quality_summary', COUNT(*) FROM mart_data_quality_summary;

-- TODO: 8 file parquet siap di data/processed/, lanjut milestone 11 (konsolidasi ke data_mart/)
