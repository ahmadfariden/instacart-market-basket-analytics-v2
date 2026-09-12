-- ============================================================
-- Milestone: 02_data_collection.sql
-- Source Identification, Data Extraction, Data Inventory
-- Source of truth: data/raw/*.csv (dibaca langsung, tidak diubah)
-- ============================================================

-- ---------- 1. Load 6 CSV mentah jadi tabel di DuckDB ----------
CREATE OR REPLACE TABLE orders AS
    SELECT * FROM read_csv_auto('data/raw/orders.csv');

CREATE OR REPLACE TABLE order_products_prior AS
    SELECT * FROM read_csv_auto('data/raw/order_products__prior.csv');

CREATE OR REPLACE TABLE order_products_train AS
    SELECT * FROM read_csv_auto('data/raw/order_products__train.csv');

CREATE OR REPLACE TABLE products AS
    SELECT * FROM read_csv_auto('data/raw/products.csv');

CREATE OR REPLACE TABLE aisles AS
    SELECT * FROM read_csv_auto('data/raw/aisles.csv');

CREATE OR REPLACE TABLE departments AS
    SELECT * FROM read_csv_auto('data/raw/departments.csv');


-- ---------- 2. Data Inventory: row count tiap tabel (checkpoint reproducibility) ----------
SELECT 'orders' AS source, COUNT(*) AS row_count FROM orders
UNION ALL SELECT 'order_products_prior', COUNT(*) FROM order_products_prior
UNION ALL SELECT 'order_products_train', COUNT(*) FROM order_products_train
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'aisles', COUNT(*) FROM aisles
UNION ALL SELECT 'departments', COUNT(*) FROM departments;

-- Expected (evidence dari eksekusi sebelumnya):
-- orders                : 3,421,083
-- order_products_prior  : 32,434,489
-- order_products_train  : 1,384,617
-- products              : 49,688
-- aisles                : 134
-- departments           : 21

-- TODO setelah verifikasi row count cocok:
-- 1. Lanjut ke sql/03_profiling.sql untuk item yang masih 🔲 (outlier, basket size distribution)
