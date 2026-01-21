# QBR Metrics Generator: Win Rates, Slippage, and Velocity

This repository contains Python scripts designed to automate the generation of key performance metrics for Quarterly Business Reviews (QBRs). It specifically calculates **Win Rates**, **Deal Slippage**, and **Stage Velocity** (Conversion Rates) across multiple regions and market segments.

## 📊 Metrics Calculated

The script generates a comprehensive dataset covering the following metrics for each Scenario (Region/Segment):

### 1. Win Rate Analysis
* **Win Rate Revenue ($):** Percentage of won ARR vs. total closed ARR (Won + Lost).
* **Win Rate Transaction (#):** Percentage of won deal counts vs. total closed deal counts.
* **Won Transactions:** Total count of won opportunities.

### 2. Slippage Analysis
* **Slippage Rate (%):** Percentage of deals expected to close in the target quarter (as of 28 days ago) that pushed to a future quarter.
* **Slipped Deals (#):** Count of deals that slipped.
* **Initial Pipeline (#):** Count of deals originally expected to close in the quarter.

### 3. Stage Velocity (Conversion Rates)
* **Stage 2 > Stage 4 Conversion (%):** The percentage of deals that were in *Stage 2 (Confirm Need)* 28 days ago and have since advanced to *Stage 4 (Demonstrate Value)* or higher.
* **Stage 2 > Stage 3 Conversion (%):** The percentage of deals that were in *Stage 2* 28 days ago and are currently in *Stage 3 (Establish Value)*.

## 🌍 Dimensions & Scenarios

The script automatically generates data for the following **6 Scenarios**:

| Scenario | Scope | Filters Applied |
| :--- | :--- | :--- |
| **Digital** | Global | `Segment = 'Digital'` |
| **SMB** | Global | `Segment = 'SMB'` |
| **NA** | Regional | `Region = 'NA'` AND `Segment NOT IN ('SMB', 'Digital')` |
| **EMEA** | Regional | `Region = 'EMEA'` AND `Segment NOT IN ('SMB', 'Digital')` |
| **LATAM** | Regional | `Region = 'LATAM'` AND `Segment NOT IN ('SMB', 'Digital')` |
| **APAC** | Regional | `Region = 'APAC'` AND `Segment NOT IN ('SMB', 'Digital')` |

## 📂 Product & Deal Categories

For each metric, the data is broken down into the following specific buckets:
* **CCaaS** (Contact Center)
* **CSQL** (Campaign Source Qualified Leads)
* **ES Cross-sell** (Employee Experience)
* **New Customer (Total)**
* **New Customer (BDR Sourced)**
* **New Customer (AE Sourced)**
* **Partner Influenced**
* **Partner Sourced**
* **AI Group** (Copilot, Ultimate, etc.)

## 🚀 Usage

1.  **Open the Notebook:** Load `ALAN_ISLASMORRIS_ZENDESK_COM 2026-01-19 14_08_33.ipynb` in your Snowpark-enabled environment.
2.  **Set the Target Quarter:** Update the `TARGET_QUARTER` variable (e.g., `'2025Q4'`).
3.  **Run All Cells:** The script will:
    * Define the calculation functions.
    * Iterate through all 6 scenarios (Digital, SMB, NA, EMEA, LATAM, APAC).
    * Calculate all 4 metrics (Win Rate, Slippage, S2>S4, S2>S3) for each scenario.
    * Merge everything into a single master DataFrame.
4.  **Export:** The final output `master_df` contains the consolidated QBR dataset, ready for export to CSV/Excel.

## 🛠 Dependencies
* `snowflake.snowpark`
* `pandas`
* `functools` (for merging dataframes)

## Key Links

- [Output File](https://docs.google.com/spreadsheets/d/1T7LYfa9c10CAs8DEdhq3CO5ZoYCLAEaXRLGuI1lePQQ/edit?gid=1833582232#gid=1833582232)

- [No of MQLs and Conversion Rates by Segment and Region](https://github.com/AlanIslasZd/CSQL_by_Rep/blob/main/marketing_no_of_mqls_and_conversion_rates_by_segment_and_region.ipynb)


## 📝 SQL Logic Reference
The logic in these scripts is strictly aligned with the source SQL files found in:
* `QBR_Velocity_and_Slippage/QBR_Stage_Conversion_and_Slippage_Analysis.sql`
* `QBR_Ellen_Automation_By_Region_And_Segment/Ellen_Source_Doc_with_win_rates_by_category.sql`
