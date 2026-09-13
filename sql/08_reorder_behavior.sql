-- ============================================================
-- Milestone: 08_reorder_behavior.sql
-- Reorder Funnel, Product Reorder Ranking, Top Product Pairs
-- Depends on: 06_data_modeling.sql (fact_orders, fact_order_products, dim_product)
-- Catatan: analisis pakai source_set='prior' saja -- itu histori order lengkap per user
-- (train cuma order terakhir per user, di-hold-out untuk keperluan lain, bukan basis
-- perhitungan reorder funnel yang butuh urutan pembelian utuh)
-- ============================================================

-- ---------- 1. Purchase count distribution per product (INVESTIGASI dulu sebelum kunci threshold) ----------
-- Locked decision di roadmap: threshold default 20 pembelian, "disesuaikan setelah lihat
-- distribusi nyata" -- jadi cek dulu di sini, jangan langsung pakai 20 tanpa lihat data
WITH product_purchase_count AS (
    SELECT product_id, COUNT(*) AS n_purchases
    FROM fact_order_products
    WHERE source_set = 'prior'
    GROUP BY product_id
)
SELECT
    MIN(n_purchases) AS min_purchases,
    APPROX_QUANTILE(n_purchases, 0.25) AS p25,
    MEDIAN(n_purchases) AS median_purchases,
    APPROX_QUANTILE(n_purchases, 0.75) AS p75,
    APPROX_QUANTILE(n_purchases, 0.90) AS p90,
    MAX(n_purchases) AS max_purchases,
    COUNT(*) AS total_products
FROM product_purchase_count;

-- Berapa banyak produk yang di bawah threshold kandidat (20)?
WITH product_purchase_count AS (
    SELECT product_id, COUNT(*) AS n_purchases
    FROM fact_order_products
    WHERE source_set = 'prior'
    GROUP BY product_id
)
SELECT
    COUNT(*) FILTER (WHERE n_purchases < 20) AS products_below_20,
    COUNT(*) AS total_products,
    ROUND(100.0 * COUNT(*) FILTER (WHERE n_purchases < 20) / COUNT(*), 2) AS pct_below_20
FROM product_purchase_count;


-- ---------- 2. Reorder Funnel: first purchase -> reorder sekali -> loyal repeat (3x+) ----------
-- Per (user, product): hitung berapa kali user itu beli produk itu (dari data prior)
WITH user_product_purchase AS (
    SELECT
        co.user_id,
        cop.product_id,
        COUNT(*) AS n_purchases
    FROM fact_order_products cop
    JOIN fact_orders co ON cop.order_id = co.order_id
    WHERE cop.source_set = 'prior'
    GROUP BY co.user_id, cop.product_id
)
SELECT
    COUNT(*) AS total_first_purchases,                                  -- level 1: pernah beli
    COUNT(*) FILTER (WHERE n_purchases >= 2) AS total_reordered_once,   -- level 2: reorder minimal 1x
    COUNT(*) FILTER (WHERE n_purchases >= 3) AS total_loyal_repeat,     -- level 3: reorder 2x+ (beli 3x+ total)
    ROUND(100.0 * COUNT(*) FILTER (WHERE n_purchases >= 2) / COUNT(*), 2) AS pct_first_to_reorder,
    ROUND(100.0 * COUNT(*) FILTER (WHERE n_purchases >= 3) / COUNT(*) FILTER (WHERE n_purchases >= 2), 2) AS pct_reorder_to_loyal
FROM user_product_purchase;

-- Funnel yang sama, dipecah per department (top 10 by volume)
WITH user_product_purchase AS (
    SELECT
        co.user_id,
        cop.product_id,
        COUNT(*) AS n_purchases
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
    ROUND(100.0 * COUNT(*) FILTER (WHERE upp.n_purchases >= 2) / COUNT(*), 2) AS pct_first_to_reorder
FROM user_product_purchase upp
JOIN dim_product dp ON upp.product_id = dp.product_id
GROUP BY dp.department
ORDER BY total_first_purchases DESC
LIMIT 10;


-- ---------- 3. Product Reorder Ranking (dengan threshold final -- isi setelah lihat hasil #1) ----------
-- PLACEHOLDER: ganti angka 20 di bawah kalau distribusi #1 menunjukkan threshold lain lebih pas
WITH product_stats AS (
    SELECT
        product_id,
        COUNT(*) AS n_purchases,
        SUM(reordered) AS n_reordered
    FROM fact_order_products
    WHERE source_set = 'prior'
    GROUP BY product_id
)
SELECT
    dp.product_name,
    dp.department,
    ps.n_purchases,
    ps.n_reordered,
    ROUND(100.0 * ps.n_reordered / ps.n_purchases, 2) AS reorder_rate_pct
FROM product_stats ps
JOIN dim_product dp ON ps.product_id = dp.product_id
WHERE ps.n_purchases >= 20  -- LOCKED threshold, sesuaikan kalau perlu
ORDER BY reorder_rate_pct DESC
LIMIT 20;


-- ---------- 4. Top Product Pairs (co-occurrence sederhana, BUKAN full Apriori) ----------
-- REVISI: self-join full ke 33.8M baris ternyata combinatorial-explosive (estimasi >1 jam,
-- 10GB+ RAM) -- kombinasi pasangan per order tumbuh kuadratik terhadap basket size,
-- dikali 3.2 juta order. Solusi: batasi dulu ke top 200 produk paling populer SEBELUM
-- self-join, karena pasangan dari produk long-tail (jarang dibeli) toh kurang berguna
-- untuk insight cross-sell dan menyumbang mayoritas ledakan kombinasi.
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
    SELECT
        a.order_id,
        a.product_id AS product_a,
        b.product_id AS product_b
    FROM filtered_order_products a
    JOIN filtered_order_products b
        ON a.order_id = b.order_id
        AND a.product_id < b.product_id
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
LIMIT 20;

-- TODO:
-- 1. Kunci threshold final product ranking berdasarkan hasil query #1
-- 2. Catat hasil funnel & top pairs di docs/assumptions.md
-- 3. Lanjut ke sql/09_customer_segmentation.sql
