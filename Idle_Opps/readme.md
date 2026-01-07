# Stage Timeline Lead Query

## Purpose
Track opportunity stage velocity using a clean LEAD-based approach. This query calculates how long each opportunity spent in each sales stage by using the next stage's entry timestamp as the current stage's exit.

## Key Findings (CSQL Cohort - Jan 2025+)

### [Pipeline Overview](https://docs.google.com/spreadsheets/d/10vpCcVoBQ3OjM398zMECzvuinrCHbgTCBbBC9bDKMV4/edit?usp=sharing)
| Metric | Count | % of Total |
|--------|-------|------------|
| **Total Opps Created** | 2,472 | 100% |
| **Won** | 589 | 23.8% |
| **Open (In Pipeline)** | 927 | 37.5% |
| **Lost** | 956 | 38.7% |

### 🚨 Stage 02 (Confirm Need) - Idle Analysis

| Idle Duration | Count | % of Open | Risk Level |
|---------------|-------|-----------|------------|
| **< 30 days** | 213 | 23.0% | ✅ Healthy |
| **30-60 days** | 114 | 12.3% | ⚠️ At Risk |
| **> 90 days (3+ months)** | 264 | 28.5% | 🔴 High Risk |

### Why This Matters

**Stage 02 (Confirm Need) is a critical bottleneck:**

1. **264 opps (28.5% of open pipeline)** have been stuck in the very first qualification stage for over 3 months. These are essentially dead deals that:
   - Inflate pipeline numbers artificially
   - Consume sales rep attention without progression
   - Should likely be disqualified or re-engaged with urgency

2. **114 opps in the 30-60 day range** are approaching the danger zone. Proactive intervention now could prevent them from becoming stale.

3. **Only 213 opps (23%)** are in a healthy state with recent activity. This suggests a systemic issue with either:
   - Lead quality entering Stage 02
   - Sales process/methodology at the qualification stage
   - Rep capacity or prioritization

### Recommendations

1. **Immediate Action**: Review the 264 high-risk opps (3+ months idle)
   - Disqualify deals with no real engagement
   - Escalate promising deals that need executive attention
   
2. **Process Improvement**: Investigate why opps stall at "Confirm Need"
   - Is the qualification criteria clear?
   - Are reps equipped to move deals past initial discovery?
   
3. **Pipeline Hygiene**: Implement automated alerts for opps idle > 30 days

4. **Win Rate Context**: With only 23.8% win rate, focus on qualification quality over quantity

---

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
