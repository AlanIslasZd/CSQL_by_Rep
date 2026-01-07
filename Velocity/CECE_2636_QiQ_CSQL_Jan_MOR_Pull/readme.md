# Same Quarter Deal Velocity Analysis (2025)

## Definition
[Same Quarter Velocity](https://docs.google.com/spreadsheets/d/1nPDiXE7QHSf4FAIniOxCsBRQJqmj-K0iAAjd7m2ThqU/edit?gid=1414706716#gid=1414706716&range=E7) metric: the percentage of won deals that were created and closed within the same fiscal quarter.

## Methodology & Logic
The analysis is based on the following "Team Aligned" logic definitions:

### 1. Population Criteria
To be included in this analysis, an Opportunity must meet **ALL** of the following:
* **Campaign ID:** Contains `%70180000001JlouAAC%`
* **Creation Date:** Opportunities created in 2025 or later.
* **Stage History:** Must have passed through one of the qualified stages ('02 - Confirm Need' through '08 - Closed').
* **Outcome:** Must be `IS_WON = TRUE`.

### 2. Metric Definition
* **Fast Track (Numerator):** Deals where `Close Quarter` == `Created Quarter`.
* **Total Won (Denominator):** All won deals in that quarter matching the criteria above.
* **Velocity %:** `(Fast Track / Total Won) * 100`

## How to Update This Report
1.  Open `query_velocity_analysis.sql`.
2.  Run the query in Snowflake.
3.  Export the results to CSV.
4.  Import the raw data into the "Raw Data" tab of the Google Sheet.
5.  Refresh the Pivot Table in the "Result" tab.
