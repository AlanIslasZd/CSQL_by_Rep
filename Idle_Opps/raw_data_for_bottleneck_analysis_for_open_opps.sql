-- Stage Timeline with LEAD: Use next stage's entry as current stage's exit
-- This is cleaner because stage exit = next stage entry (no gaps)

WITH stage_first_entry AS (
    -- Get first entry into each stage per opp
    SELECT 
        ID, 
        CREATED_DATE, 
        STAGE_NAME, 
        VALID_FROM_TIMESTAMP AS STAGE_FIRST_ENTRY,
        ROW_NUMBER() OVER (PARTITION BY ID, STAGE_NAME ORDER BY VALID_FROM_TIMESTAMP ASC) AS RN
    FROM CLEANSED.SALESFORCE.SALESFORCE_OPPORTUNITY_SCD2
    WHERE CAMPAIGN_ID LIKE '%70180000001JlouAAC%'
        AND CREATED_DATE > '2025-01-01'
        AND STAGE_NAME IN ('02 - Confirm Need', '03 - Establish Value', '04 - Demonstrate Value',
                           '05 - Secure Commitment', '06 - Contracting', '07 - Signed', '08 - Closed')
    QUALIFY RN = 1
),
current_stage AS (
    -- Get current stage per opp (latest record)
    SELECT 
        ID,
        STAGE_NAME AS CURRENT_STAGE,
        IS_WON,
        CASE 
            WHEN IS_WON = TRUE THEN 'WON'
            WHEN STAGE_NAME IN ('Lost', 'Failed Finance Audit', '08 - Closed') THEN 'LOST'
            ELSE 'OPEN'
        END AS OUTCOME
    FROM CLEANSED.SALESFORCE.SALESFORCE_OPPORTUNITY_SCD2
    WHERE VALID_TO_TIMESTAMP = '9999-12-31'
        AND CAMPAIGN_ID LIKE '%70180000001JlouAAC%'
        AND CREATED_DATE > '2025-01-01'
),
stage_sequence AS (
    -- Order stages by first entry time and use LEAD to get next stage entry
    SELECT 
        ID,
        CREATED_DATE,
        STAGE_NAME,
        STAGE_FIRST_ENTRY,
        -- Next stage entry = this stage's exit
        LEAD(STAGE_FIRST_ENTRY) OVER (PARTITION BY ID ORDER BY STAGE_FIRST_ENTRY) AS STAGE_EXIT,
        LEAD(STAGE_NAME) OVER (PARTITION BY ID ORDER BY STAGE_FIRST_ENTRY) AS NEXT_STAGE
    FROM stage_first_entry
)
SELECT 
    ss.ID,
    ss.CREATED_DATE,
    cs.CURRENT_STAGE,
    cs.IS_WON,
    cs.OUTCOME,
    ss.STAGE_NAME,
    DATE(ss.STAGE_FIRST_ENTRY) AS STAGE_ENTRY,
    -- If no next stage (still in this stage), use CURRENT_DATE
    DATE(COALESCE(ss.STAGE_EXIT, CURRENT_DATE())) AS STAGE_EXIT,
    ss.NEXT_STAGE,
    -- Days in stage = next stage entry - this stage entry (or CURRENT_DATE if still here)
    DATEDIFF('day', ss.STAGE_FIRST_ENTRY, COALESCE(ss.STAGE_EXIT, CURRENT_DATE())) AS DAYS_IN_STAGE
FROM stage_sequence ss
JOIN current_stage cs ON ss.ID = cs.ID
ORDER BY ss.ID, ss.STAGE_FIRST_ENTRY;
