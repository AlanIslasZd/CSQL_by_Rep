# 📉 Opportunity Stage Journey Analysis

**Status:** Active Analysis  
**Owner:** Data Analytics Team  
**Last Updated:** 2025-12-19  

## 🎯 Objective
To analyze the opportunities stages through the sales pipeline. unlike standard "funnel" reports which assume a linear progression (Stage 1 -> 2 -> 3), this analysis constructs the actual "Stage Journey" string for every opportunity to identify:
1. **Skipped Stages:** How often do deals jump from Stage 2 directly to Closed?
2. **Backsliding:** How often do deals revert to earlier stages?
3. **Stalled Deals:** Average idle time for OPEN opportunities in their final stage.

## 📂 Project Structure
* `notebooks/`: Contains the Pandas analysis for journey string parsing and aggregation.
* `src/`: The Snowflake SQL query used to generate the raw event logs.

## 🛠️ Methodology & Logic

### 1. Data Source (SQL)
The dataset is derived from `CLEANSED.SALESFORCE.SALESFORCE_OPPORTUNITY_SCD2`.
* **Granularity:** One row per Opportunity ID.
* **Cohort Filters:**
    * `CREATED_DATE > '2025-01-01'` (Q1 2025 Focus).
    * `CAMPAIGN_ID` like `%70180000001JlouAAC%`.
    * **Exclusions:** Removes '00 - Prospect', '01 - Qualify', and 'Omitted' stages.

### 2. The "Stage Journey" String
We use `LISTAGG` in SQL to create a chronological string of stage movements.
* *Example Output:* `"02-Confirm Need -> 04-Demonstrate Value -> 08-Closed"`
* **Logic:** Captures the **first entry** into each stage, ordered by `VALID_FROM_TIMESTAMP`.

### 3. Key Metrics
| Metric | Definition |
| :--- | :--- |
| `NUM_STAGES` | Count of distinct stages visited by the opportunity. |
| `DAYS_IDLE_IN_LAST_STAGE` | Days elapsed since the `VALID_FROM` date of the current stage (only for OPEN opps). |
| `OUTCOME` | Categorized as `WON`, `LOST`, or `OPEN` based on the `IS_CLOSED`/`IS_WON` flags. |

## 📊 Key Findings (Preliminary)
*Based on analysis of 2,579 opportunities:*
* **Won Deals Complexity:** Successful deals touch an average of **3.3 stages**, whereas Lost deals typically die after just **2.1 stages**.
* **The "Direct-to-Closed" Pattern:** A significant volume of deals (e.g., 171 count) jump straight from *Stage 2 (Confirm Need)* to *Stage 8 (Closed)*, bypassing value demonstration stages.
* **Idle Risk:** Open opportunities sitting in *Stage 3 (Establish Value)* show a high idle time (avg ~75 days), indicating a potential "frozen zone" in the pipeline.

## 🚀 How to Run
1.  Run `src/stage_journey_export.sql` in Snowflake.
2.  Download the results as `stage_journey_export.csv`.
3.  Open `notebooks/Stage_journey_analysis.ipynb`.
4.  Upload the CSV to the Colab session/local environment.
5.  Run all cells to generate the "Top Paths" tables.

---
*Generated via AI-Native Workflow*
