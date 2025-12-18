/* =================================================================================
  STAGE TRANSITION MEDIAN TIMES
  
  QUESTION: What is the median time to move from Stage 02 to Stage 04, 05, ... 08?
  
  CONTEXT:
  - Stages 00, 01, and 'Omitted' are excluded from this cohort
  - Therefore, "02 - Confirm Need" is the FIRST/ENTRY STAGE for all CSQLs
  - This query measures time from pipeline entry (Stage 02) to each milestone
  
  LOGIC:
  - Uses first entry into each stage (handles re-entries)
  - Excludes LOST opps (IS_CLOSED = TRUE AND IS_WON = FALSE)
  - Handles stage skipping (e.g., 03 → 05 directly)
  - Calculates days from Stage 02 (entry) to each subsequent stage
  
  STAGE PROGRESSION:
  02 - Confirm Need      ← ENTRY STAGE (pipeline start)
  03 - Establish Value
  04 - Demonstrate Value
  05 - Secure Commitment
  06 - Contracting
  07 - Signed
  08 - Closed            ← END STAGE (deal complete)
  
  COHORT: Q1 2025 CSQLs (Jan 1 - Aug 30, 2025)
=================================================================================
*/

WITH stage_final_snapshot AS (
    -- Get current IS_WON, IS_CLOSED status
    SELECT 
        ID,
        IS_WON,
        IS_CLOSED
    FROM CLEANSED.SALESFORCE.SALESFORCE_OPPORTUNITY_SCD2
    WHERE VALID_TO_TIMESTAMP = '9999-12-31'
),
stage_history AS (
    -- Get all stage entries for cohort opps
    SELECT 
        ID,
        STAGE_NAME,
        VALID_FROM_TIMESTAMP,
        ROW_NUMBER() OVER (PARTITION BY ID, STAGE_NAME ORDER BY VALID_FROM_TIMESTAMP) AS RN
    FROM CLEANSED.SALESFORCE.SALESFORCE_OPPORTUNITY_SCD2
    WHERE STAGE_NAME NOT IN ('00 - Prospect & Plan', '01 - Qualify Need', 'Omitted')
        AND CAMPAIGN_ID LIKE '%70180000001JlouAAC%'
        AND CREATED_DATE BETWEEN '2025-01-01' AND '2025-08-30'
),
first_entry_per_stage AS (
    -- Keep only first entry into each stage per opp
    SELECT 
        ID,
        STAGE_NAME,
        VALID_FROM_TIMESTAMP
    FROM stage_history
    WHERE RN = 1
),
stage_02_entry AS (
    -- Anchor: First entry into Stage 02
    SELECT 
        ID,
        VALID_FROM_TIMESTAMP AS STAGE_02_DATE
    FROM first_entry_per_stage
    WHERE STAGE_NAME = '02 - Confirm Need'
),
stage_pivoted AS (
    -- Pivot to get first entry date for each stage per opp
    SELECT 
        feps.ID,
        MAX(CASE WHEN STAGE_NAME = '02 - Confirm Need' THEN VALID_FROM_TIMESTAMP END) AS DATE_02,
        MAX(CASE WHEN STAGE_NAME = '03 - Establish Value' THEN VALID_FROM_TIMESTAMP END) AS DATE_03,
        MAX(CASE WHEN STAGE_NAME = '04 - Demonstrate Value' THEN VALID_FROM_TIMESTAMP END) AS DATE_04,
        MAX(CASE WHEN STAGE_NAME = '05 - Secure Commitment' THEN VALID_FROM_TIMESTAMP END) AS DATE_05,
        MAX(CASE WHEN STAGE_NAME = '06 - Contracting' THEN VALID_FROM_TIMESTAMP END) AS DATE_06,
        MAX(CASE WHEN STAGE_NAME = '07 - Signed' THEN VALID_FROM_TIMESTAMP END) AS DATE_07,
        MAX(CASE WHEN STAGE_NAME = '08 - Closed' THEN VALID_FROM_TIMESTAMP END) AS DATE_08
    FROM first_entry_per_stage feps
    GROUP BY feps.ID
),
opp_transitions AS (
    -- Calculate days from Stage 02 to each subsequent stage
    SELECT 
        sp.ID,
        sfs.IS_WON,
        sfs.IS_CLOSED,
        -- Days from Stage 02 to each stage (NULL if stage was skipped or not reached)
        DATEDIFF('day', sp.DATE_02, sp.DATE_03) AS DAYS_02_TO_03,
        DATEDIFF('day', sp.DATE_02, sp.DATE_04) AS DAYS_02_TO_04,
        DATEDIFF('day', sp.DATE_02, sp.DATE_05) AS DAYS_02_TO_05,
        DATEDIFF('day', sp.DATE_02, sp.DATE_06) AS DAYS_02_TO_06,
        DATEDIFF('day', sp.DATE_02, sp.DATE_07) AS DAYS_02_TO_07,
        DATEDIFF('day', sp.DATE_02, sp.DATE_08) AS DAYS_02_TO_08,
        -- Flag: did this opp reach each stage?
        CASE WHEN sp.DATE_03 IS NOT NULL THEN 1 ELSE 0 END AS REACHED_03,
        CASE WHEN sp.DATE_04 IS NOT NULL THEN 1 ELSE 0 END AS REACHED_04,
        CASE WHEN sp.DATE_05 IS NOT NULL THEN 1 ELSE 0 END AS REACHED_05,
        CASE WHEN sp.DATE_06 IS NOT NULL THEN 1 ELSE 0 END AS REACHED_06,
        CASE WHEN sp.DATE_07 IS NOT NULL THEN 1 ELSE 0 END AS REACHED_07,
        CASE WHEN sp.DATE_08 IS NOT NULL THEN 1 ELSE 0 END AS REACHED_08
    FROM stage_pivoted sp
    LEFT JOIN stage_final_snapshot sfs ON sp.ID = sfs.ID
    WHERE sp.DATE_02 IS NOT NULL  -- Must have started in Stage 02
),
-- Filter: Exclude LOST opps (keep WON + still OPEN)
opp_transitions_filtered AS (
    SELECT *
    FROM opp_transitions
    WHERE NOT (IS_CLOSED = TRUE AND IS_WON = FALSE)  -- Exclude lost
)

-- ===========================================
-- RESULT 1: Median days from Stage 02 to each subsequent stage
-- ===========================================
SELECT 
    'Stage 02 → Stage 03' AS TRANSITION,
    COUNT(CASE WHEN REACHED_03 = 1 THEN 1 END) AS OPP_COUNT,
    ROUND(MEDIAN(DAYS_02_TO_03), 1) AS MEDIAN_DAYS,
    ROUND(AVG(DAYS_02_TO_03), 1) AS AVG_DAYS,
    MIN(DAYS_02_TO_03) AS MIN_DAYS,
    MAX(DAYS_02_TO_03) AS MAX_DAYS,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY DAYS_02_TO_03) AS P25_DAYS,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY DAYS_02_TO_03) AS P75_DAYS
FROM opp_transitions_filtered
WHERE REACHED_03 = 1

UNION ALL

SELECT 
    'Stage 02 → Stage 04' AS TRANSITION,
    COUNT(CASE WHEN REACHED_04 = 1 THEN 1 END) AS OPP_COUNT,
    ROUND(MEDIAN(DAYS_02_TO_04), 1) AS MEDIAN_DAYS,
    ROUND(AVG(DAYS_02_TO_04), 1) AS AVG_DAYS,
    MIN(DAYS_02_TO_04) AS MIN_DAYS,
    MAX(DAYS_02_TO_04) AS MAX_DAYS,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY DAYS_02_TO_04) AS P25_DAYS,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY DAYS_02_TO_04) AS P75_DAYS
FROM opp_transitions_filtered
WHERE REACHED_04 = 1

UNION ALL

SELECT 
    'Stage 02 → Stage 05' AS TRANSITION,
    COUNT(CASE WHEN REACHED_05 = 1 THEN 1 END) AS OPP_COUNT,
    ROUND(MEDIAN(DAYS_02_TO_05), 1) AS MEDIAN_DAYS,
    ROUND(AVG(DAYS_02_TO_05), 1) AS AVG_DAYS,
    MIN(DAYS_02_TO_05) AS MIN_DAYS,
    MAX(DAYS_02_TO_05) AS MAX_DAYS,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY DAYS_02_TO_05) AS P25_DAYS,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY DAYS_02_TO_05) AS P75_DAYS
FROM opp_transitions_filtered
WHERE REACHED_05 = 1

UNION ALL

SELECT 
    'Stage 02 → Stage 06' AS TRANSITION,
    COUNT(CASE WHEN REACHED_06 = 1 THEN 1 END) AS OPP_COUNT,
    ROUND(MEDIAN(DAYS_02_TO_06), 1) AS MEDIAN_DAYS,
    ROUND(AVG(DAYS_02_TO_06), 1) AS AVG_DAYS,
    MIN(DAYS_02_TO_06) AS MIN_DAYS,
    MAX(DAYS_02_TO_06) AS MAX_DAYS,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY DAYS_02_TO_06) AS P25_DAYS,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY DAYS_02_TO_06) AS P75_DAYS
FROM opp_transitions_filtered
WHERE REACHED_06 = 1

UNION ALL

SELECT 
    'Stage 02 → Stage 07' AS TRANSITION,
    COUNT(CASE WHEN REACHED_07 = 1 THEN 1 END) AS OPP_COUNT,
    ROUND(MEDIAN(DAYS_02_TO_07), 1) AS MEDIAN_DAYS,
    ROUND(AVG(DAYS_02_TO_07), 1) AS AVG_DAYS,
    MIN(DAYS_02_TO_07) AS MIN_DAYS,
    MAX(DAYS_02_TO_07) AS MAX_DAYS,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY DAYS_02_TO_07) AS P25_DAYS,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY DAYS_02_TO_07) AS P75_DAYS
FROM opp_transitions_filtered
WHERE REACHED_07 = 1

UNION ALL

SELECT 
    'Stage 02 → Stage 08 (Closed)' AS TRANSITION,
    COUNT(CASE WHEN REACHED_08 = 1 THEN 1 END) AS OPP_COUNT,
    ROUND(MEDIAN(DAYS_02_TO_08), 1) AS MEDIAN_DAYS,
    ROUND(AVG(DAYS_02_TO_08), 1) AS AVG_DAYS,
    MIN(DAYS_02_TO_08) AS MIN_DAYS,
    MAX(DAYS_02_TO_08) AS MAX_DAYS,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY DAYS_02_TO_08) AS P25_DAYS,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY DAYS_02_TO_08) AS P75_DAYS
FROM opp_transitions_filtered
WHERE REACHED_08 = 1

ORDER BY TRANSITION;


/* ===========================================
   OPTIONAL: Uncomment below for WON-only analysis
   ===========================================

-- RESULT 2: Same metrics but ONLY for WON opps
SELECT 
    'Stage 02 → Stage 08 (WON ONLY)' AS TRANSITION,
    COUNT(*) AS OPP_COUNT,
    ROUND(MEDIAN(DAYS_02_TO_08), 1) AS MEDIAN_DAYS,
    ROUND(AVG(DAYS_02_TO_08), 1) AS AVG_DAYS,
    MIN(DAYS_02_TO_08) AS MIN_DAYS,
    MAX(DAYS_02_TO_08) AS MAX_DAYS
FROM opp_transitions_filtered
WHERE REACHED_08 = 1
  AND IS_WON = TRUE;

*/
