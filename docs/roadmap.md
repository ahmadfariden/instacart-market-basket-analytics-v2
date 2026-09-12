# Roadmap & Checklist Portofolio Data Analysis
## Instacart Market Basket Analysis — DuckDB + Power BI (v1, adaptasi dari template Retail Rocket v4)

> Roadmap ini mengadaptasi struktur dan metodologi kerja yang sudah terbukti dari project Retail Rocket
> (skeleton-first, mart kecil + parquet per milestone, git checkpoint di tiap tahap, pola kerja iteratif
> 7 langkah, locked methodology decisions, on-canvas insight box). **Fokusnya sengaja dialihkan dari
> ML modeling (roadmap Data Scientist yang ditunda) ke analytics & dashboard** — behavior/reorder pattern,
> basket composition, dan customer segmentation berbasis frekuensi, bukan prediksi.

> ✅ **Sebagian besar Tahap 2-4 SUDAH dieksekusi nyata** lewat profiling DuckDB sebelumnya — roadmap ini
> menandai temuan itu sebagai evidence, bukan mulai dari nol.

> 🔄 **Alur kerja per milestone:** 6 CSV mentah di `data/raw/` adalah **source of truth** dan tidak pernah
> diubah. DuckDB membaca langsung dari CSV (atau `.duckdb` yang sudah dibangun) di tiap milestone, hasilnya
> dibentuk jadi **mart kecil** dan di-**export ke parquet**. File parquet mart itu yang di-push ke GitHub —
> bukan `.duckdb` mentah, bukan CSV besar (`order_products__prior.csv` sendiri ~564 MB terkompresi / puluhan
> juta baris).

> 📌 **Konvensi commit:** setiap tahap besar diakhiri checkpoint git (`git add <sql/parquet mart> && git commit
> -m "..." && git push`). Gunakan `git add` spesifik (bukan `git add .`) supaya `.duckdb` dan CSV besar tidak
> ikut ter-stage. Conventional commits (`feat:`, `fix:`, `docs:`, `refactor:`).

---

## 0. Project Setup

- Init repo & `.gitignore` (exclude `data/raw/*.csv` besar, `*.duckdb`, `__pycache__`)
- README awal (deskripsi project, dataset, tools)
- Struktur folder (`data/raw`, `data/processed`, `sql`, `docs`, `powerbi`)
- **Bangun skeleton project sebelum lanjut** — buat semua file `sql/02_*.sql` sampai `sql/10_*.sql` sebagai stub kosong (komentar/TODO) sesuai urutan roadmap di bawah, supaya struktur akhir kelihatan dari hari pertama.
- ✅ **Checkpoint:** `git commit -m "chore: initial project structure"` → push

> 🔁 **Pola kerja iteratif per milestone (LOCKED METHOD, sama seperti Retail Rocket):**
> 1. Tulis query awal di `sql/0N_*.sql` sesuai tujuan milestone
> 2. Jalankan & lihat hasil mentah — jangan asumsikan benar
> 3. Investigasi kalau ada angka janggal (mis. `approx_unique` DuckDB yang **sudah terbukti meleset** dari exact count — lihat Tahap 3)
> 4. Putuskan secara eksplisit cara menangani temuan itu
> 5. Revisi query, jalankan ulang untuk verifikasi
> 6. Catat keputusan + angka final di `docs/assumptions.md`
> 7. Commit + push sebagai checkpoint milestone selesai

---

## 1. Business Understanding

- Objective: memahami pola reorder, komposisi basket, dan segmentasi customer untuk mendukung strategi retensi & cross-sell — **bukan** membangun model prediksi (itu roadmap Data Scientist terpisah, ditunda).
- **Data Feasibility Check** — inventarisasi apa yang benar-benar tersedia sebelum menentukan KPI:
  - ❌ **Tidak ada data harga/price** di 6 tabel manapun — KPI berbasis revenue/AOV (average order value dalam nilai uang) **tidak bisa dihitung**, hanya AOV dalam jumlah item.
  - ❌ **Tidak ada tanggal kalender absolut** — cuma `order_dow`, `order_hour_of_day`, `order_number` (urutan relatif per user), `days_since_prior_order` (selisih relatif). Analisis tren "bulanan/tahunan" tidak bisa dilakukan, hanya pola siklikal (hari dalam minggu, jam dalam hari).
  - ❌ **Tidak ada demografi customer** (usia, lokasi, dst) — segmentasi hanya bisa berbasis perilaku transaksi (frekuensi, recency, basket size).
  - ✅ Yang tersedia: perilaku order (waktu relatif, frekuensi, komposisi produk), hierarki produk (aisle → department), status reorder per item.
- KPI (disesuaikan feasibility check): reorder rate (keseluruhan & per department/aisle), basket size (item per order), distribusi waktu order, customer segment by purchase frequency, top reordered products.
- Business Questions: Produk/department apa yang paling sering di-reorder? Kapan waktu order paling ramai? Bagaimana perbedaan perilaku customer occasional vs frequent? Produk apa yang sering dibeli bersama?
- Success Criteria: dashboard 5 halaman + minimal 3 insight actionable berbasis bukti.
- **Develop Mart Kecil + Export Parquet** — belum relevan di tahap ini (belum ada data terpakai).
- ✅ **Checkpoint:** `git commit -m "chore: define business objectives, KPI, and feasibility check"` → push

---

## 2. Data Collection ✅ *(SUDAH DIEKSEKUSI)*

- Source: Instacart Market Basket Analysis (Kaggle)
- ✅ **Evidence** — Data Extraction sudah dijalankan via DuckDB CLI:
  ```sql
  CREATE TABLE orders AS SELECT * FROM read_csv_auto('orders.csv');
  CREATE TABLE order_products_prior AS SELECT * FROM read_csv_auto('order_products__prior.csv');
  CREATE TABLE order_products_train AS SELECT * FROM read_csv_auto('order_products__train.csv');
  CREATE TABLE products AS SELECT * FROM read_csv_auto('products.csv');
  CREATE TABLE aisles AS SELECT * FROM read_csv_auto('aisles.csv');
  CREATE TABLE departments AS SELECT * FROM read_csv_auto('departments.csv');
  ```
- ✅ **Data Inventory (Evidence):**

  | Tabel | Baris |
  |---|---:|
  | orders | 3,421,083 |
  | order_products_prior | 32,434,489 |
  | order_products_train | 1,384,617 |
  | products | 49,688 |
  | aisles | 134 |
  | departments | 21 |

- **Develop Mart Kecil + Export Parquet** — belum perlu, tahap ini baru staging.
- ✅ **Checkpoint:** `git commit -m "feat: add data collection scripts (DuckDB ingestion)"` → push

---

## 3. Data Profiling ✅ *(SEBAGIAN BESAR SUDAH DIEKSEKUSI)*

- ✅ **Structure Analysis:** semua kolom & tipe data ter-summarize (`SUMMARIZE <table>`). Ditemukan `order_hour_of_day` ke-detect VARCHAR ("00"–"23"), perlu cast di Tahap 4.
- ✅ **Missing Values:** `days_since_prior_order` 6.03% missing (bermakna — order pertama tiap user, `order_number=1`). Semua kolom lain di 6 tabel: 0% missing.
- ✅ **Duplicates:** grain `order_id`+`product_id` di `order_products_prior`/`train` — 0 duplikat.
- ✅ **Data Quality Assessment — `eval_set` validation:**
  ```
  prior: 3,214,874 order → 100% ada di order_products_prior, 0% di train
  test : 75,000 order    → 0% di keduanya (tanpa isi keranjang)
  train: 131,209 order   → 0% di prior, 100% di order_products_train
  ```
- **Cardinality Approx-vs-Exact Mismatch** *(analog "Anomaly Profiling" Retail Rocket)* — ✅ ditemukan `SUMMARIZE` DuckDB memakai algoritma approximate (meleset signifikan: `aisles` approx 131 vs exact 134; `departments` approx 19 vs exact 21; `product_id` approx 45,031 vs exact 49,677). **Aturan wajib sisa project:** cardinality untuk keputusan apapun harus pakai `COUNT(DISTINCT ...)` exact.
- 🔲 **Belum dieksekusi:** outlier `add_to_cart_order` (max=145 prior, max=80 train) — investigasi domain sebelum Tahap 4; distribusi basket size; profil lengkap `products`/`aisle_id`/`department_id`.
- **Develop Mart Kecil + Export Parquet** — export `data/processed/03_profiling_summary.parquet` (hasil `SUMMARIZE` tiap tabel + row count checkpoint).
- ✅ **Checkpoint:** `git commit -m "feat: add data profiling notebook incl. cardinality mismatch findings"` → push

---

## 4. Data Cleaning

- **Missing Value Handling:** `days_since_prior_order` — retain NA, tambah flag `is_first_order` (bukan diimputasi 0, karena 0 punya makna berbeda: order di hari yang sama).
- **Data Type Correction:** cast `order_hour_of_day` ke INTEGER; `order_id`/`product_id`/`user_id`/`aisle_id`/`department_id` sebagai categorical/string (bukan numeric murni, cegah agregasi tidak sengaja).
- **Outlier Review — Add-to-Cart Investigation** *(analog "Bot/Anomaly Filtering" Retail Rocket)* — investigasi `add_to_cart_order` max=145 (prior)/80 (train): cek apakah order dengan basket ekstrem besar itu legitimate bulk-shopper atau data quality issue, tetapkan threshold/keputusan eksplisit (retain dengan flag, atau exclude dari ranking tertentu — bukan dihapus otomatis).
- **Develop Mart Kecil + Export Parquet** — `data/processed/04_orders_clean.parquet`.
- ✅ **Checkpoint:** `git commit -m "fix: clean data types and flag outliers"` → push

---

## 5. Data Validation

- **Data Completeness Check:** re-run row count checkpoint (Tahap 2) untuk memastikan tidak ada baris hilang setelah cleaning.
- **Internal Consistency Validation** *(tidak ada sumber eksternal, sama prinsip Retail Rocket):*
  - Kalau `reordered=1`, user seharusnya sudah pernah beli produk itu sebelumnya (cek silang ke histori `order_products_prior` user tersebut) — 🔲 belum divalidasi eksplisit.
  - `order_number` harus berurutan tanpa gap per user — 🔲 belum divalidasi.
  - `days_since_prior_order` NA hanya boleh terjadi di `order_number=1` — 🔲 belum divalidasi eksplisit (baru dikonfirmasi proporsi missing-nya, belum cross-check ke `order_number`).
- **Grain Validation** ✅ sudah dilakukan di Tahap 3 (0 duplikat).
- **Develop Mart Kecil + Export Parquet** — `data/processed/05_validation_summary.parquet` (tabel pass/fail tiap rule).
- ✅ **Checkpoint:** `git commit -m "feat: add data validation and internal consistency checks"` → push

---

## 6. Data Modeling

*(Instacart sudah relational/wide sejak awal — tidak perlu EAV-to-Wide atau Category Tree Flattening seperti Retail Rocket, karena `aisle`→`department` cuma 2 level datar, bukan hierarchy dalam.)*

- **Dim_Product:** join `products` + `aisles` + `departments` jadi satu dimension table datar.
- **Dim_User:** agregat dari `orders` — total order per user, rata-rata `days_since_prior_order`, `is_frequent_shopper` (dasar segmentasi Tahap 9).
- **Fact_Order_Products:** grain order-product (`order_products_prior` + `order_products_train` digabung, dengan kolom penanda `eval_set` asalnya).
- **Fact_Orders:** grain 1 order (dari `orders`, dengan `is_first_order` flag hasil Tahap 4).
- **Develop Mart Kecil + Export Parquet** — `data/processed/06_dim_product.parquet`, `06_dim_user.parquet`, `06_fact_order_products.parquet`, `06_fact_orders.parquet`.
- ✅ **Checkpoint:** `git commit -m "feat: build dimensional model (Dim_Product, Dim_User, Fact tables)"` → push

---

## 7. Exploratory Data Analysis

- Distribusi basket size (jumlah produk per order) — min/max/median/outlier.
- Reorder rate keseluruhan & per department/aisle.
- Pola waktu: volume order per `order_dow`/`order_hour_of_day`.
- Distribusi `days_since_prior_order` (siklus belanja tipikal — mingguan? dua-mingguan?).
- **Develop Mart Kecil + Export Parquet** — `data/processed/07_eda_summary.parquet`.
- ✅ **Checkpoint:** `git commit -m "feat: add exploratory data analysis"` → push

---

## 8. Reorder & Behavior Analysis *(analog "Funnel Analysis" Retail Rocket)*

- **Reorder funnel sederhana:** first-purchase → reorder sekali → reorder berulang (loyal repeat) — dihitung per produk dan per department.
- **Product Reorder Ranking** — produk dengan reorder rate tertinggi, **dengan minimum purchase threshold** (lihat Locked Decision #1 di Tahap 10 — analog Item Ranking Threshold Retail Rocket).
- **Top Product Pairs (co-occurrence sederhana)** — pasangan produk yang paling sering muncul bersama dalam 1 order (hitung frekuensi co-occurrence langsung, **bukan** full association rule mining/Apriori dengan support-confidence-lift — itu didalami di roadmap Data Scientist terpisah; di sini cukup level "top pairs by count" untuk insight cross-sell awal).
- **Develop Mart Kecil + Export Parquet** — `data/processed/08_reorder_analysis.parquet`, `08_product_pairs.parquet`.
- ✅ **Checkpoint:** `git commit -m "feat: add reorder behavior and product pair analysis"` → push

---

## 9. Customer Segmentation Analysis *(analog "Visitor Behavior & Segmentation" Retail Rocket)*

- Segmentasi berbasis frekuensi order (bukan ML clustering — heuristik analitik, sesuai locked decision Tahap 10): mis. **Occasional** (total order rendah), **Regular**, **Frequent Buyer** — threshold ditentukan dari distribusi aktual (persentil), bukan angka sembarang.
- Basket size rata-rata per segmen.
- Reorder rate rata-rata per segmen.
- **Develop Mart Kecil + Export Parquet** — `data/processed/09_customer_segments.parquet`.
- ✅ **Checkpoint:** `git commit -m "feat: add customer segmentation analysis"` → push

---

## 10. Data Mart Design (untuk Dashboard)

- Tentukan 5 mart final, dipetakan ke 5 halaman dashboard:
  - `mart_overview` → Halaman 1 (Overview)
  - `mart_reorder_by_department`, `mart_reorder_funnel` → Halaman 2 (Reorder & Behavior)
  - `mart_product_performance`, `mart_product_pairs` → Halaman 3 (Product & Aisle Performance)
  - `mart_customer_segment`, `mart_activity_by_time` → Halaman 4 (Customer Behavior & Segmentation)
  - `mart_data_quality_summary` → Halaman 5 (Data Quality & Methodology)

**📌 Dashboard Methodology Decisions — LOCKED**

1. **Product Ranking Threshold** (`mart_product_performance`)
   - Terapkan minimum jumlah pembelian sebelum produk masuk ranking reorder rate.
   - Default analitik: 20 pembelian (disesuaikan setelah lihat distribusi nyata di Tahap 7 — jangan dikunci di angka ini tanpa validasi).
   - Diperlakukan sebagai aturan analitik, bukan data cleaning — produk di bawah threshold tetap ada di data mentah, cuma di-exclude dari visual ranking tertentu.

2. **Customer Segmentation** (`mart_customer_segment`)
   - Segmen **mutually exclusive**, berdasarkan total jumlah order per user (bukan ML clustering).
   - Kandidat batas: persentil ke-33/66 dari distribusi total order (bukan angka tebakan) — divalidasi ulang di Tahap 9.
   - Total tiap segmen wajib reconcile ke total unique user.

3. **Data Quality & Methodology** (`mart_data_quality_summary`)
   - Isinya hanya metrik kuantitatif (row count, % missing, % outlier flagged) — cocok untuk card/chart.
   - Assumptions, feasibility limitations (tidak ada data harga/tanggal kalender/demografi), dan methodology notes **tidak** ditarik dari mart — disajikan sebagai text box statis di Power BI.

- **Develop Mart Kecil + Export Parquet** — 8 file mart di atas, semua ke `data/processed/`.
- ✅ **Checkpoint:** `git commit -m "feat: build subject-oriented data mart (5 marts for 5 dashboard pages)"` → push

---

## 11. Parquet Export

- Optimized Storage & Reusable Dataset Layer — konsolidasi seluruh mart Tahap 10 ke folder final `data_mart/` (terpisah dari `data_processed/` yang lebih bersifat staging antar-tahap).
- **Develop Mart Kecil + Export Parquet** — final export ke `data_mart/`.
- ✅ **Checkpoint:** `git commit -m "feat: export parquet layer for BI consumption"` → push

---

## 12. Visualization & Dashboard Development

- **5 Halaman Dashboard:**
  1. **Overview** — KPI cards (total order, total customer, avg basket size, overall reorder rate), trend volume per hari-minggu.
  2. **Reorder & Behavior** — reorder rate per department, reorder funnel (first→repeat→loyal), pola waktu order.
  3. **Product & Aisle Performance** — top produk by reorder rate (dengan threshold), top product pairs, performa per aisle/department.
  4. **Customer Behavior & Segmentation** — distribusi segmen (Occasional/Regular/Frequent), basket size per segmen, reorder rate per segmen.
  5. **Data Quality & Methodology** — metrik kuantitatif dari `mart_data_quality_summary` + text box assumptions/limitations (termasuk **ketiadaan data harga & tanggal kalender** sebagai limitation utama, analog "no explicit revenue" di Retail Rocket).
- **On-Canvas Insight Box per Halaman** (format: **Finding → Root Cause → Action → Expected Impact**):
  - **Wajib** di Halaman 2, 3, 4.
  - **Opsional** di Halaman 1.
  - **Tidak diperlukan** di Halaman 5.
  - Insight antar halaman sebaiknya saling terhubung (mis. insight Halaman 4 merujuk balik ke temuan Halaman 3).
- **Develop Mart Kecil + Export Parquet** — tidak ada mart baru, murni konsumsi `data_mart/`.
- ✅ **Checkpoint:** `git commit -m "feat: build power bi dashboard (5 pages)"` → push

---

## 13. Insight & Recommendation

- Findings, Root Cause Analysis, Business Impact, Actionable Recommendation.
- Dokumentasikan insight yang sama dengan on-canvas box (Tahap 12) ke `docs/insights.md` — versi lengkap/lebih detail.
- **Develop Mart Kecil + Export Parquet** — tidak ada mart baru.
- ✅ **Checkpoint:** `git commit -m "docs: add insights and business recommendations"` → push

---

## 14. Documentation

- Methodology.
- Assumptions (termasuk definisi threshold produk, batas segmentasi customer, definisi `is_first_order`).
- Limitations (**tidak ada data harga/revenue, tidak ada tanggal kalender absolut, tidak ada demografi customer** — 3 keterbatasan utama yang membatasi scope KPI sejak Tahap 1).
- Data Dictionary (6 tabel asli + 4 dimensional table Tahap 6 + 8 mart Tahap 10).
- **Develop Mart Kecil + Export Parquet** — tidak ada mart baru.
- ✅ **Checkpoint:** `git commit -m "docs: add methodology, assumptions, limitations, data dictionary"` → push

---

## 15. Final Publishing

- Review commit history (rapikan dengan `rebase -i` kalau perlu).
- Finalisasi README (ringkasan project, cara reproduce, screenshot dashboard).
- Tag release (`v1.0`) di GitHub.
- Portfolio Publication (LinkedIn/blog merujuk ke repo).
- ✅ **Checkpoint akhir:** `git commit -m "docs: finalize README and release v1.0"` → push + tag

---

### Ringkasan Adaptasi dari Template Retail Rocket

| Elemen Retail Rocket | Analog Instacart | Alasan Beda |
|---|---|---|
| EAV-to-Wide, Category Tree Flattening | **Dihapus** | Instacart sudah relational/wide, aisle→department cuma 2 level datar |
| Bot Traffic Profiling/Filtering | Add-to-Cart Outlier Investigation | Sama prinsip (cek anomali ekstrem sebelum agregasi), objek beda |
| Funnel Analysis (view→cart→transaction) | Reorder & Behavior Analysis (first→repeat→loyal) | Instacart tidak punya event funnel, tapi reorder pattern bisa diperlakukan analog |
| Visitor Segmentation (Buyer/Cart-adder/Browser) | Customer Segmentation (Occasional/Regular/Frequent) | Basis segmentasi beda (funnel stage vs frekuensi order), prinsip mutually-exclusive tetap sama |
| Revenue tidak eksplisit | **Harga sama sekali tidak ada** | Instacart lebih terbatas lagi — bahkan AOV dalam nilai uang tidak bisa dihitung, hanya AOV dalam jumlah item |
| Data Feasibility Check | Ditambah 2 keterbatasan baru | Tidak ada tanggal kalender absolut + tidak ada demografi customer, spesifik ke struktur Instacart |
| Cardinality bermasalah | **Approx-vs-exact count mismatch DuckDB** | Temuan baru khusus project ini — `SUMMARIZE` DuckDB terbukti meleset signifikan, jadi bagian dari profiling findings |

**Batas scope penting (supaya tidak tergoda merangkak ke roadmap Data Scientist):** Top Product Pairs di Tahap 8 sengaja dibatasi ke co-occurrence sederhana (hitung frekuensi), **bukan** full association rule mining (Apriori/FP-Growth dengan support/confidence/lift) — itu kedalaman yang disengaja ditunda ke roadmap Data Scientist terpisah. Kalau nanti tergoda nambah kompleksitas di tengah jalan, itu sinyal untuk cek ulang apakah project ini masih di jalur Data Analyst atau sudah merangkak balik ke Data Scientist.