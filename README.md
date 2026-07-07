# Crypto Medallion Data Warehouse

A production-style cryptocurrency analytics warehouse built with **dbt Core**, implementing the **Medallion Architecture (Bronze → Silver → Gold)** on top of a live data ingestion pipeline.

**The problem this solves:** Raw API data is messy, inconsistently typed, and not structured for analysis. Analysts shouldn't query raw tables directly - they'd get bad types, null values, and no guarantee of data quality. This project transforms raw crypto market data into clean, validated, business-ready models with automated quality checks on every run.

Raw data is ingested daily by the companion project **[Crypto Incremental Pipeline](https://github.com/kavyansh-1/crypto-incremental-pipeline)**, which pulls cryptocurrency data from the CoinGecko API into PostgreSQL via an incremental ELT pipeline orchestrated with Apache Airflow. This repository is the transformation layer that sits on top.

---

## Architecture

```
                   CoinGecko API
                         │
                         ▼
         Crypto Incremental Pipeline (Airflow-orchestrated)
                         │
                         ▼
             ┌─────────────────────┐
             │   Bronze Layer      │  coin_prices (raw)
             │   loaded_at +       │  Two timestamps: source clock vs arrival clock
             │   last_updated      │
             └─────────┬───────────┘
                       │
                       ▼
             ┌─────────────────────┐
             │   Staging Layer     │  stg_coin_prices
             │   Clean columns,    │  Renames, selects useful fields
             │   standard names    │
             └─────────┬───────────┘
                       │
                       ▼
             ┌─────────────────────┐
             │   Silver Layer      │  silver_coin_prices
             │   Validated,        │  Type-cast, quality-flagged
             │   quality-checked   │  Only valid rows flow downstream
             └──────┬──────┬───────┘
                    │      │      │
          ┌─────────┘      │      └──────────┐
          ▼                ▼                 ▼
   top_gainers    market_cap_tiers    volume_leaders
         (Gold - business-ready, analyst-facing models)
```

---

## Medallion Layers

### Bronze — `coin_prices`

Raw data stored exactly as received from the API. Nothing filtered, nothing modified. Two timestamps are preserved deliberately:

- `last_updated` — CoinGecko's clock (when they updated the data)
- `loaded_at` — the pipeline's clock (when *we* stored the record)

This distinction matters for auditing: if the pipeline runs at 9 AM but the API data was last updated at 8:47 AM, both timestamps are preserved so you can answer "what did our warehouse know, and when did we know it?"

---

### Staging — `stg_coin_prices`

The cleanup interface between Bronze and Silver. Renames ambiguous columns (e.g. `id → coin_id`), selects only useful fields, and provides a stable contract so that if the raw source schema ever changes, only this one model needs updating — not every downstream model.

**Materialization:** View

---

### Silver — `silver_coin_prices`

The validation layer. Every row is evaluated and marked:

| `data_quality_flag` | Meaning |
|---|---|
| `valid` | All critical fields present and sensible |
| `flagged` | Null market cap, zero/negative price, or missing change data |

Only `valid` rows flow into Gold models. Silver also type-casts `current_price` from TEXT to NUMERIC and standardizes ticker symbols to uppercase (`btc → BTC`).

**Materialization:** View

---

### Gold — Three Business Models

| Model | Description |
|---|---|
| `top_gainers` | Top 10 coins by 24h price appreciation |
| `market_cap_tiers` | All coins categorized as Large Cap (>$10B), Mid Cap (>$1B), or Small Cap |
| `volume_leaders` | Top 10 coins by trading volume |

All Gold models filter to `data_quality_flag = 'valid'` only — they never touch raw or unvalidated data directly.

**Materialization:** View

---

## Data Quality — 11 Automated Tests

```bash
dbt test
# Done. PASS=11 WARN=0 ERROR=0 SKIP=0 TOTAL=11
```

### Staging layer

| Column | Test |
|---|---|
| `coin_id` | `unique` |
| `coin_id` | `not_null` |
| `symbol` | `not_null` |
| `current_price` | `not_null` |
| `last_updated` | `not_null` |

### Silver layer

| Column | Test |
|---|---|
| `coin_id` | `unique` |
| `coin_id` | `not_null` |
| `current_price` | `not_null` |
| `data_quality_flag` | `not_null` |
| `data_quality_flag` | `accepted_values: [valid, flagged]` |
| `data_tier` | `not_null` |

---

## Project Structure

```
crypto_analytics/
├── dbt_project.yml
├── models/
│   ├── staging/
│   │   ├── sources.yml          # Declares raw coin_prices as a dbt source
│   │   ├── schema.yml           # Column descriptions and all 11 tests
│   │   └── stg_coin_prices.sql
│   ├── silver/
│   │   └── silver_coin_prices.sql
│   └── marts/
│       ├── top_gainers.sql
│       ├── market_cap_tiers.sql
│       └── volume_leaders.sql
└── .gitignore
```

---

## Tech Stack

| Layer | Tool |
|---|---|
| Transformation | dbt Core 1.11 |
| Warehouse | PostgreSQL (Supabase) |
| dbt adapter | dbt-postgres |
| Python | 3.12 |
| Package manager | uv |
| Source data | CoinGecko API (via companion pipeline) |

---

## Setup

**1. Clone and enter the project**
```bash
git clone https://github.com/kavyansh-1/crypto-dbt-warehouse.git
cd crypto-dbt-warehouse/crypto_analytics
```

**2. Create and activate environment (Python 3.12 required — dbt not yet compatible with 3.14)**
```bash
uv venv --python python3.12
source .venv/bin/activate   # Linux/Mac
uv pip install dbt-postgres
```

**3. Configure connection — create `~/.dbt/profiles.yml`**
```yaml
crypto_analytics:
  target: dev
  outputs:
    dev:
      type: postgres
      host: your-pooler-host.pooler.supabase.com
      port: 6543
      user: postgres.your-project-ref
      password: your-password
      dbname: postgres
      schema: public
      threads: 4
```

Note: use the **Session pooler** connection (port 6543), not the direct connection (port 5432), for reliable IPv4 connectivity.

**4. Verify, run, and test**
```bash
dbt debug    # confirm connection
dbt run      # build all 5 models
dbt test     # run all 11 quality tests
```

**5. Browse documentation and lineage graph**
```bash
dbt docs generate
dbt docs serve
# Open http://localhost:8080
```

---

## Sample Queries

```sql
-- Top 10 price gainers today
SELECT name, symbol, current_price, price_change_percentage_24h
FROM top_gainers;

-- Distribution across market cap tiers
SELECT market_cap_tier, COUNT(*) AS coin_count
FROM market_cap_tiers
GROUP BY market_cap_tier
ORDER BY coin_count DESC;

-- Check data quality breakdown
SELECT data_quality_flag, COUNT(*)
FROM silver_coin_prices
GROUP BY data_quality_flag;
```

---


