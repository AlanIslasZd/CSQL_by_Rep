 SELECT DISTINCT ID
    FROM CLEANSED.SALESFORCE.SALESFORCE_OPPORTUNITY_SCD2
    WHERE CAMPAIGN_ID LIKE '%70180000001JlouAAC%'
      AND CREATED_DATE > '2024-12-31'
      AND STAGE_NAME IN ('02 - Confirm Need', '03 - Establish Value', '04 - Demonstrate Value', 
                         '05 - Secure Commitment', '06 - Contracting', '07 - Signed', '08 - Closed')
