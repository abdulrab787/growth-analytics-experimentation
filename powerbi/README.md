# GA4 Funnel Dashboard (Power BI)

This is a 4-page Power BI report saved in PBIP format. It's built on small CSV extracts from the BigQuery `sessions` table and the simulated experiment.

| Page | What it shows |
|---|---|
| Funnel | KPI cards, a funnel chart and a step-by-step conversion table |
| Segments | Purchase rate by first-touch medium and by device, plus a medium × device matrix |
| Trend & Seasonality | Daily sessions with the 7-day rolling purchase rate, and rates by season period |
| Experiment Readout | Results of the simulated H2 test: decision, lift, p-value, P(variant better), guardrail and user-split check |

## How to open it

1. Install **Power BI Desktop** (the March 2024 release or later).
2. Turn on PBIP support: go to **File → Options → Preview features** and tick **Power BI Project (.pbip) save option** and **Store reports using enhanced metadata format (PBIR)**. Restart Power BI Desktop.
3. Open `GA4_Funnel_Dashboard.pbip`.
4. If your repo isn't at `C:\ARI\ga4-funnel-ab-planning`, update the data folder. Go to **Transform data → Edit parameters** and set `DataFolder` to the full path of `powerbi\data\`, including the trailing backslash.
5. Click **Refresh**.

## Data

| File | Grain | Source |
|---|---|---|
| `data/fact_daily_funnel.csv` | One row per date × device × first-touch medium (1,649 rows) | Aggregated from `ga4_practice.sessions` |
| `data/experiment_results.csv` | One row per scenario × metric | Written by `analysis/analyse_experiment.py` |

## Model

- **`fact_daily_funnel`** links to **`dim_date`**, a date table built in Power Query and marked as the official date table. `dim_date` includes the season **Period** labels.
- **`funnel_steps`** is a small static table that drives the funnel chart through the `Funnel Value` measure.
- **`experiment_results`** stands on its own and isn't linked to the other tables.
- Every measure is organised into a display folder: Volume, Rates, Trend, Funnel or Experiment.
