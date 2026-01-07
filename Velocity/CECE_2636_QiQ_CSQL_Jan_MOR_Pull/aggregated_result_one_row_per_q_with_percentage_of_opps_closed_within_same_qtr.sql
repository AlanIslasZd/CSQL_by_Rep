WITH raw_data AS (
    SELECT 
        b.ID,
        b.NAME AS OPPORTUNITY_NAME,
        DATE(b.CREATED_DATE) AS CREATED_DATE,
        DATE(b.CLOSE_DATE) AS CLOSE_DATE,
        
        -- Pre-calculate the Quarters
        YEAR(b.CLOSE_DATE) || '-Q' || QUARTER(b.CLOSE_DATE) AS CLOSE_QTR,
        YEAR(b.CREATED_DATE) || '-Q' || QUARTER(b.CREATED_DATE) AS CREATE_QTR,
        
        -- The Flag logic
        CASE 
            WHEN DATE_TRUNC('quarter', b.CREATED_DATE) = DATE_TRUNC('quarter', b.CLOSE_DATE) 
            THEN 'Yes - Close Fast' 
            ELSE 'No - Closed Later' 
        END AS IS_SAME_QTR_VELOCITY

    FROM CLEANSED.SALESFORCE.SALESFORCE_OPPORTUNITY_BCV b
    INNER JOIN (
        SELECT DISTINCT ID
        FROM CLEANSED.SALESFORCE.SALESFORCE_OPPORTUNITY_SCD2
        WHERE CAMPAIGN_ID LIKE '%70180000001JlouAAC%'
          AND CREATED_DATE > '2024-12-31'
          AND STAGE_NAME IN ('02 - Confirm Need', '03 - Establish Value', '04 - Demonstrate Value', 
                             '05 - Secure Commitment', '06 - Contracting', '07 - Signed', '08 - Closed')
    ) q ON b.ID = q.ID
    WHERE b.IS_WON = TRUE 
)
-- PIVOT TABLE LOGIC
SELECT
    CLOSE_QTR,
    
    -- 1. Total Deals (Denominator)
    COUNT(ID) AS TOTAL_WON,
    
    -- 2. Pivot the columns based on your flag
    COUNT(CASE WHEN IS_SAME_QTR_VELOCITY = 'Yes - Close Fast' THEN 1 END) AS COUNT_FAST,
    COUNT(CASE WHEN IS_SAME_QTR_VELOCITY = 'No - Closed Later' THEN 1 END) AS COUNT_LATER,
    
    -- 3. Calculate the Percentage
    ROUND(
        COUNT(CASE WHEN IS_SAME_QTR_VELOCITY = 'Yes - Close Fast' THEN 1 END) * 100.0 
        / NULLIF(COUNT(ID), 0)
    , 1) AS PCT_OPPS_CLOSED_WITHIN_SAME_QTR

FROM raw_data
GROUP BY CLOSE_QTR
ORDER BY CLOSE_QTR;
