-- Open Opps Idle Analysis: Which opps are still in pipeline and how long have they been stuck?
-- Minimalist query focused on: CREATED_DATE, LAST_STAGE, DAYS_IDLE

WITH current_state AS (
    -- Get current snapshot of each opp (latest record)
    SELECT 
        ID,
        DATE(CREATED_DATE) AS CREATED_DATE,
        STAGE_NAME,
        VALID_FROM_TIMESTAMP AS STAGE_ENTRY_DATE,
        IS_WON
    FROM CLEANSED.SALESFORCE.SALESFORCE_OPPORTUNITY_SCD2
    WHERE VALID_TO_TIMESTAMP = '9999-12-31'  -- Current record only
        AND CAMPAIGN_ID LIKE '%70180000001JlouAAC%'
        AND CREATED_DATE > '2024-12-31'
        -- OPEN = not won AND not in terminal lost stages
        AND IS_WON = FALSE
        AND STAGE_NAME NOT IN ('08 - Closed', 'Lost', 'Failed Finance Audit','01 - Qualify Need','00 - Prospect & Plan')
)
SELECT 
    ID,
    CREATED_DATE,
    -- Extract stage number for cleaner output
    LEFT(STAGE_NAME, 2) AS LAST_STAGE,
    STAGE_NAME AS LAST_STAGE_NAME,
    DATE(STAGE_ENTRY_DATE) AS STAGE_ENTRY_DATE,
    -- Days idle = days from when they entered current stage until today
    DATEDIFF('day', DATE(STAGE_ENTRY_DATE), CURRENT_DATE()) AS DAYS_IDLE,
    -- Categorize idle duration into bins
    CASE 
        WHEN DATEDIFF('day', DATE(STAGE_ENTRY_DATE), CURRENT_DATE()) < 15 THEN '<15 days'
        WHEN DATEDIFF('day', DATE(STAGE_ENTRY_DATE), CURRENT_DATE()) < 30 THEN '3-4 weeks'
        WHEN DATEDIFF('day', DATE(STAGE_ENTRY_DATE), CURRENT_DATE()) < 60 THEN '1-2 months'
        WHEN DATEDIFF('day', DATE(STAGE_ENTRY_DATE), CURRENT_DATE()) < 90 THEN '2-3 months'
        ELSE '3+ months'
    END AS DAYS_IDLE_BIN
FROM current_state
ORDER BY DAYS_IDLE DESC;
