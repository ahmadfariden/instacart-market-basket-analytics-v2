# Instacart Market Basket Analysis — Data Analyst Portfolio Project

> Stack: DuckDB · SQL · Power BI · Git/GitHub
> Status: 🚧 In Progress (adaptasi metodologi dari project Retail Rocket)

## Tentang Project Ini
Analisis pola reorder, komposisi basket, dan segmentasi customer menggunakan Instacart Market
Basket Analysis Dataset (Kaggle). Fokus ke behavior/analytics — bukan ML modeling/prediksi
(itu roadmap Data Scientist terpisah, ditunda).

Dataset ini punya keterbatasan lebih besar dari Retail Rocket: **tidak ada data harga sama
sekali** (bahkan AOV dalam nilai uang tidak bisa dihitung), tidak ada tanggal kalender absolut
(cuma waktu relatif), dan tidak ada demografi customer. Detail lengkap di
[`docs/assumptions.md`](docs/assumptions.md).

## Struktur Folder
```
instacart_project/
├── data/
│   ├── raw/              # 6 CSV asli — source of truth, tidak di-push ke git
│   └── processed/        # Output antar-milestone (.parquet)
├── data_mart/             # 5 mart final untuk dashboard (.parquet)
├── sql/                   # Query per milestone (02-10)
├── powerbi/               # File Power BI (.pbix)
├── docs/
│   ├── roadmap.md
│   ├── assumptions.md
│   └── insights.md
└── retail_rocket.duckdb   # (nama disesuaikan) database lokal, di-.gitignore
```

## Cara Reproduce
1. Download dataset dari Kaggle (Instacart Market Basket Analysis), taruh 6 CSV di `data/raw/`
   (`orders.csv`, `order_products__prior.csv`, `order_products__train.csv`, `products.csv`,
   `aisles.csv`, `departments.csv`)
2. Download DuckDB CLI dari duckdb.org, taruh `duckdb.exe` di root project
3. Jalankan milestone berurutan sesuai `docs/roadmap.md`

## Roadmap
Lihat [`docs/roadmap.md`](docs/roadmap.md) — adaptasi dari template Retail Rocket v4, dengan
tabel "Ringkasan Adaptasi" yang menjelaskan apa yang di-drop/diganti dan alasannya.
