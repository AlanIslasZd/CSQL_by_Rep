SELECT 
    b.ID,
    b.NAME AS OPPORTUNITY_NAME,       -- Critical: Stakeholders need Names, not just IDs
    DATE(b.CREATED_DATE) AS CREATED_DATE,
    DATE(b.CLOSE_DATE) AS CLOSE_DATE,
    
    -- Pre-calculate the Quarters so you don't have to format dates in Sheets
    YEAR(b.CLOSE_DATE) || '-Q' || QUARTER(b.CLOSE_DATE) AS CLOSE_QTR,
    YEAR(b.CREATED_DATE) || '-Q' || QUARTER(b.CREATED_DATE) AS CREATE_QTR,
    
    -- This "Flag" column makes the Pivot Table one click
    CASE 
        WHEN DATE_TRUNC('quarter', b.CREATED_DATE) = DATE_TRUNC('quarter', b.CLOSE_DATE) 
        THEN 'Yes - Close Fast' 
        ELSE 'No - Closed Later' 
    END AS IS_SAME_QTR_VELOCITY

FROM CLEANSED.SALESFORCE.SALESFORCE_OPPORTUNITY_BCV b
INNER JOIN (
    -- YOUR EXACT TEAM-ALIGNED LOGIC
    SELECT DISTINCT ID
    FROM CLEANSED.SALESFORCE.SALESFORCE_OPPORTUNITY_SCD2
    WHERE CAMPAIGN_ID LIKE '%70180000001JlouAAC%'
      AND CREATED_DATE > '2024-12-31'
      AND STAGE_NAME IN ('02 - Confirm Need', '03 - Establish Value', '04 - Demonstrate Value', 
                         '05 - Secure Commitment', '06 - Contracting', '07 - Signed', '08 - Closed')
) q ON b.ID = q.ID
WHERE b.IS_WON = TRUE -- Ensures we only look at the WON deals as per your objective
ORDER BY b.CLOSE_DATE DESC;
