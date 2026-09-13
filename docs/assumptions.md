# Assumptions, Definitions & Limitations

## Data Collection (Milestone 2) — VERIFIED
| Tabel | Rows |
|---|---|
| orders | 3,421,083 |
| order_products_prior | 32,434,489 |
| order_products_train | 1,384,617 |
| products | 49,688 |
| aisles | 134 |
| departments | 21 |

## Data Profiling Findings (Milestone 3)

**Missing values — VALIDATED as expected business process, not data quality issue**
- `days_since_prior_order`: 206,209 NULL (6.03%)
- Cross-check: 100% NULL rows occur at `order_number = 1` (206,209/206,209), 0 at other order numbers
- **Decision: retain NULL as-is, add `is_first_order` flag** — do not impute with 0
  (0 has a different meaning: same-day reorder)

**Duplicates — none found**
- `order_products_prior`: 32,434,489 total rows = 32,434,489 distinct (order_id, product_id) grain
- `order_products_train`: 1,384,617 total rows = 1,384,617 distinct grain
- 0 duplicates in both tables

**eval_set validation — confirmed clean partition**
- prior: 3,214,874 orders → 100% in order_products_prior, 0% in train
- train: 131,209 orders → 0% in prior, 100% in order_products_train
- test: 75,000 orders → 0% in either (no basket data, as expected for test set)

**Cardinality — LOCKED RULE: always use COUNT(DISTINCT ...), never SUMMARIZE**
- DuckDB's `SUMMARIZE` command produces approximate cardinality that proved significantly off:
  aisles (approx 131 vs exact 134), departments (approx 19 vs exact 21), product_id
  (approx 45,031 vs exact 49,688)
- Exact re-verification: aisles=134, departments=21, product_id=49,688 — all match their
  respective table row counts exactly (no duplicate IDs)
- Note: exact product_id count is 49,688, not 49,677 as earlier noted in the roadmap draft —
  49,688 is confirmed correct (matches `products` row count exactly)

**Referential integrity — perfect, no orphans**
- 0 products with invalid `aisle_id`, 0 products with invalid `department_id`
- Safe to join products → aisles → departments in star schema (milestone 6) without orphan risk

**Basket size / add_to_cart_order outlier — investigated, no distortion evidence found**
- add_to_cart_order: min 1, max 145 (prior) / 80 (train), median 6-7, p99 ~33-34
- Basket size: min 1, max 145, median 8, p95 25, p99 35
- Orders with basket >100 items: 20 (≈0.0006% of 3.2M orders)
- Orders with basket >50 items: 3,081 (≈0.1% of 3.2M orders)
- **Decision: RETAIN all orders as-is, add `is_large_basket` flag (>50 items) for optional
  filtering transparency — do NOT exclude.** Unlike Retail Rocket's bot traffic (which had
  proven distortion evidence — 32.5% of transactions affected), here there is no evidence of
  distortion: volume is too small to bias any statistic, and large baskets are plausibly
  legitimate bulk/office shoppers, not anomalous data.

## Methodology Note
Different decisions for analogous situations (Retail Rocket excluded bot view-events;
Instacart retains all large-basket orders) reflect the same underlying principle applied
consistently: **only filter/exclude when there is demonstrated evidence of distortion**,
not merely because a value is a statistical outlier.
