# Stage Timeline Lead Query

## Purpose
Track opportunity stage velocity using a clean LEAD-based approach. This query calculates how long each opportunity spent in each sales stage by using the next stage's entry timestamp as the current stage's exit.

## Key Concept
**Stage Exit = Next Stage Entry**

Instead of tracking complex entry/exit timestamps separately, we use `LEAD()` to determine that when an opp enters Stage N+1, they've exited Stage N. This eliminates gaps and simplifies the logic.

## Query Structure

### CTEs

| CTE | Description |
|-----|-------------|
| `stage_first_entry` | Gets the **first time** each opp entered each stage (deduped with `QUALIFY RN = 1`) |
| `current_stage` | Gets the **current state** of each opp from the latest SCD2 record (`VALID_TO_TIMESTAMP = '9999-12-31'`) |
| `stage_sequence` | Uses `LEAD()` to calculate stage exit times based on next stage entry |

### Output Columns

| Column | Description |
|--------|-------------|
| `ID` | Opportunity ID |
| `CREATED_DATE` | When the opp was created |
| `CURRENT_STAGE` | The stage the opp is currently in |
| `IS_WON` | Boolean - whether the opp was won |
| `OUTCOME` | Derived: `WON`, `LOST`, or `OPEN` |
| `STAGE_NAME` | The stage being analyzed (one row per stage visited) |
| `STAGE_ENTRY` | When they first entered this stage |
| `STAGE_EXIT` | When they entered the next stage (or `CURRENT_DATE` if still here) |
| `NEXT_STAGE` | What stage came after this one |
| `DAYS_IN_STAGE` | Days from entry to exit |

## OUTCOME Logic

```sql
CASE 
    WHEN IS_WON = TRUE THEN 'WON'
    WHEN STAGE_NAME IN ('Lost', 'Failed Finance Audit', '08 - Closed') THEN 'LOST'
    ELSE 'OPEN'
END AS OUTCOME
```

## Filters

- **Campaign**: `CAMPAIGN_ID LIKE '%70180000001JlouAAC%'` (CSQL cohort)
- **Date**: `CREATED_DATE > '2025-01-01'`
- **Stages**: Only numbered stages 02-08 (excludes 00, 01, Omitted, Lost, Failed Finance Audit)

## Example Output

| ID | CREATED_DATE | CURRENT_STAGE | OUTCOME | STAGE_NAME | STAGE_ENTRY | STAGE_EXIT | DAYS_IN_STAGE |
|----|--------------|---------------|---------|------------|-------------|------------|---------------|
| 006... | 2025-01-15 | 06 - Contracting | OPEN | 02 - Confirm Need | 2025-01-15 | 2025-01-20 | 5 |
| 006... | 2025-01-15 | 06 - Contracting | OPEN | 03 - Establish Value | 2025-01-20 | 2025-02-01 | 12 |
| 006... | 2025-01-15 | 06 - Contracting | OPEN | 06 - Contracting | 2025-02-01 | 2025-01-07 | 340 |

## Use Cases

1. **Idle Analysis**: Filter to `OUTCOME = 'OPEN'` and look at `DAYS_IN_STAGE` for the last stage
2. **Bottleneck Detection**: Find which stages have the longest durations
3. **Velocity Benchmarking**: Compare `DAYS_IN_STAGE` across WON vs LOST opps
4. **Stage Skip Analysis**: Look for missing stages in the journey

## Comparison to Original Query

| Aspect | Original Query | This Query |
|--------|----------------|------------|
| Lines of code | ~300+ | ~60 |
| CTEs | 5-6 | 3 |
| Exit logic | Complex t1/t2 join with first entry + last exit | Simple LEAD() |
| OPEN opp handling | Required sentinel value replacement | `COALESCE(STAGE_EXIT, CURRENT_DATE())` |
| Maintainability | Hard to modify | Easy to extend |
