# Insight & Recommendation
## Instacart Market Basket Analytics

> Insight ini dibangun dari data yang sudah divalidasi di seluruh pipeline (milestone 1-11).
> Setiap insight mengikuti struktur: Finding → Root Cause → Action → Expected Impact.

---

## Insight 1 (Sheet 2 — Reorder & Behavior): Consumable Categories Reorder 2x More Than Durables

**Finding**
- Dairy eggs (67.02%), produce (65.05%), dan beverages (65.37%) reorder rate hampir 2x lipat dari personal care (32.19%) dan pantry (34.74%)
- First-to-reorder rate mengikuti pola yang sama: produce 48.16% vs pantry 23.09%

**Root Cause**
- Item consumable/perishable (dairy, produce, beverages) punya siklus pakai pendek dan dibeli ulang secara habitual, sementara item durable/eksploratif (personal care, pantry staples) dibeli kurang predictable — entah karena lebih awet, atau customer masih dalam fase eksplorasi merek/produk

**Action**
- Prioritaskan fitur subscription/auto-replenish untuk dairy eggs, produce, dan beverages — kategori ini punya perilaku repurchase paling predictable untuk dibangunkan model subscription
- Untuk kategori reorder rendah (personal care, pantry), fokus ke discovery/recommendation, bukan pengingat replenishment — customer di sini masih dalam fase eksplorasi

**Expected Impact**
- Bahkan uplift moderat pada adopsi subscription untuk 3 department dengan reorder tertinggi (total ~9.4 juta baris order-product) bisa signifikan menaikkan frekuensi order tanpa biaya akuisisi customer baru

---

## Insight 2 (Sheet 3 — Product & Aisle Performance): Milk Aisle Is the Strongest Subscription Candidate

**Finding**
- Reorder rate aisle "milk" 78.18% — tertinggi dari semua 15 aisle top-volume, jauh di atas fresh fruits (71.88%) meski fresh fruits punya total pembelian jauh lebih besar
- Top product pairs didominasi cluster fresh produce (banana + avocado + strawberries + spinach muncul berulang bersamaan)

**Root Cause**
- Milk adalah staple hampir universal dengan siklus simpan pendek dan minim brand-switching — begitu customer pilih merek/jenis, mereka beli hampir otomatis
- Co-occurrence produce merefleksikan perilaku meal-planning asli (bahan smoothie/salad dibeli bersamaan), bukan komposisi basket acak

**Action**
- Milk adalah kandidat terkuat untuk fitur "auto-replenish" khusus — predictability reorder-nya lebih tinggi bahkan dari aisle produce ber-volume tertinggi
- Gunakan pasangan produce yang terkonfirmasi (banana+avocado+strawberries+spinach) sebagai basis saran "frequently bought together" atau prompt cross-sell berbasis resep

**Expected Impact**
- Nudge replenishment khusus milk menargetkan aisle dengan ketidakpastian perilaku paling rendah — kemungkinan besar conversion rate tertinggi dari pilot auto-replenish manapun

---

## Insight 3 (Sheet 4 — Customer Behavior & Segmentation): Loyalty, Not Basket Size, Separates Segments

**Finding**
- Avg basket size hampir rata di semua segmen: Occasional 9.67, Regular 9.97, Frequent Buyer 10.23 — beda kurang dari 6%
- Avg reorder rate bervariasi drastis: Occasional 26.22%, Regular 42.64%, Frequent Buyer 61.65% — lebih dari 2x lipat antara ekstrem

**Root Cause**
- Frequent Buyer nggak dibedakan oleh belanja "lebih banyak" — mereka dibedakan oleh membeli produk yang sama berulang kali. Basket size pada dasarnya sifat behavioral yang cenderung tetap, tapi loyalitas reorder adalah sifat yang bisa dilatih (lewat reminder, personalisasi, pembentukan kebiasaan)

**Action**
- Jangan targetkan Frequent Buyer dengan upsell "beli lebih banyak per order" — batas atas basket size mereka tampak struktural. Sebaliknya, fokuskan budget retensi ke segmen Regular (30.42% dari user, 62,729 orang) — mereka udah belanja mendekati basket size Frequent Buyer tapi cuma convert 42.64% reorder rate, ada ruang untuk mendorong mereka ke arah loyalitas Frequent Buyer dengan reminder "beli lagi" yang dipersonalisasi berdasarkan histori pembelian mereka sendiri

**Expected Impact**
- Menggeser bahkan sebagian reorder rate segmen Regular mendekati benchmark Frequent Buyer (61.65%) adalah lever pertumbuhan yang lebih efisien dibanding mencoba memperbesar basket size, yang variasinya kecil di seluruh basis customer

---

## Catatan Metodologi
Ketiga insight ini sengaja saling melengkapi (kategori/aisle mana yang cocok untuk auto-replenish, dan segmen customer mana yang paling responsif terhadap strategi retensi berbasis reorder), bukan berdiri sendiri per chart. Semua angka diambil langsung dari mart yang sudah divalidasi (`mart_reorder_by_department`, `mart_product_performance`, `mart_customer_segment`) — bukan estimasi atau asumsi baru.

**Batasan penting yang berlaku ke semua insight di atas:** dataset ini tidak memiliki data harga, sehingga "impact" di atas dinyatakan dalam istilah perilaku (reorder rate, volume order) — bukan proyeksi revenue dalam mata uang, karena data itu memang tidak tersedia untuk dihitung secara valid.
