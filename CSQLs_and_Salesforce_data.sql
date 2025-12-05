WITH t1 as (
SELECT DISTINCT
    -- Opportunity Owner (The Denominator)
    -- We use the Account owner (CSM) as the primary grouper for "Per Rep" stats
    --A.RENEWAL_REP_NAME AS CSM_Name,
    B.OPPORTUNITY_OWNER_S_MANAGER_S_EMAIL_C AS Manager_Email,

    -- Created Date (The Timeline)
    -- Truncated to month for "Per Month" trending
    DATE_TRUNC('month', DATE(B.CREATED_DATE)) AS Creation_Month,

    -- Amount / Revenue (The Value)
    -- LOGIC: Use the Support Add-on ARR if available; otherwise use standard Amount
    B.SUPPORT_ADD_ON_ARR_C, 
    B.EXPECTED_REVENUE,

    -- Account related Data
    A.CRM_ACCOUNT_NAME,
    A.CRM_ACCOUNT_ID,
    A.PRO_FORMA_REGION,

    -- Stage Name (The Funnel Position)
    B.STAGE_NAME,
    B.NAME,

    -- Type (The Classification)
    -- Critical to filter out "New Business" and keep only "Upsell/Cross-sell"
    B.TYPE,
    B.TYPE_OF_EXPANSION_C,

    -- Lead Source (The Attribution)
    B.SALES_LEAD_SOURCE_C,

    -- Close Date (The Velocity)
    -- Used to calculate Sales Cycle: DATEDIFF(day, Created_Date, Close_Date)
    B.CLOSE_DATE,
    --B.IS_CLOSED,
    --B.IS_WON,

    -- Current ARR (Account Level Attribute)
    -- Used for coverage band segmentation (<12k vs 12-100k)
    A.CRM_NET_ARR_USD AS Current_Customer_ARR,
    A.CRM_ARR_BAND_GRANULAR,

    -- Probability (The Forecast Weight)
    -- If B.PROBABILITY exists, use it. If not, this CASE statement calculates it manually.
    CASE
        WHEN B.PROBABILITY IS NOT NULL THEN B.PROBABILITY
        WHEN B.STAGE_NAME LIKE '%Prospect%' THEN 10
        WHEN B.STAGE_NAME LIKE '%Qualify%' THEN 20
        WHEN B.STAGE_NAME LIKE '%Value%' THEN 50
        WHEN B.STAGE_NAME LIKE '%Negotiat%' THEN 90
        WHEN B.IS_WON = TRUE THEN 100
        ELSE 0
    END AS Deal_Probability,
    
    -- Flags for easy counting
    B.IS_WON,
    B.IS_CLOSED


FROM
    "PRESENTATION"."CUSTOMER_EXPERIENCE"."RENEWALS_EXCELLENCE__ACCOUNTS" AS A
LEFT JOIN
    cleansed.salesforce.salesforce_opportunity_scd2 AS B
    ON A."CRM_ACCOUNT_ID" = B.ACCOUNT_ID
    -- Note: Joining on Created Date = Service Date is risky (see note below)
    AND TO_DATE(A."SERVICE_DATE") = TO_DATE(B.CREATED_DATE) 
WHERE
    B.STAGE_NAME NOT IN ('00 - Prospect & Plan', '01 - Qualify Need', 'Omitted')
    AND B.CAMPAIGN_ID LIKE '%70180000001JlouAAC%'
    AND B.CREATED_DATE > TO_DATE('2025-06-30') -- Filtering for Q3/Q4 2025
    AND A.PRO_FORMA_MARKET_SEGMENT = 'Digital'
    AND B.CLOSE_DATE >= DATEADD('month', -12, DATE_TRUNC('month', CURRENT_DATE()))
), t2 as (
SELECT 
    --CSM_Name,
    Manager_Email,
    Creation_Month,
    SUPPORT_ADD_ON_ARR_C,
    EXPECTED_REVENUE,
    CRM_ACCOUNT_NAME,
    CRM_ACCOUNT_ID,
    PRO_FORMA_REGION,
    STAGE_NAME,
    NAME,
    TYPE,
    TYPE_OF_EXPANSION_C,
    SALES_LEAD_SOURCE_C,
    IS_CLOSED,
    IS_WON,
    Current_Customer_ARR,
    CRM_ARR_BAND_GRANULAR,
    Deal_Probability,
    MAX(CLOSE_DATE) as CLOSE_DATE
FROM t1
GROUP BY 
    --CSM_Name,
    Manager_Email,
    Creation_Month,
    SUPPORT_ADD_ON_ARR_C,
    EXPECTED_REVENUE,
    CRM_ACCOUNT_NAME,
    CRM_ACCOUNT_ID,
    PRO_FORMA_REGION,
    STAGE_NAME,
    NAME,
    TYPE,
    TYPE_OF_EXPANSION_C,
    SALES_LEAD_SOURCE_C,
    IS_CLOSED,
    IS_WON,
    Current_Customer_ARR,
    CRM_ARR_BAND_GRANULAR,
    Deal_Probability
), t3 as (
SELECT *,    
ROW_NUMBER() OVER (PARTITION BY CRM_ACCOUNT_NAME, NAME, Manager_Email ORDER BY CLOSE_DATE DESC, EXPECTED_REVENUE DESC, STAGE_NAME DESC, Creation_Month) AS RN
FROM t2
),
t4 as (
SELECT *,
SUM(EXPECTED_REVENUE) OVER (PARTITION BY CRM_ACCOUNT_NAME) as TOTAL_ACCOUNT_REVENUE
FROM t3 
WHERE RN = 1
)
SELECT DISTINCT 
    --CSM_Name,
    Manager_Email,
    Creation_Month,
    SUPPORT_ADD_ON_ARR_C,
    EXPECTED_REVENUE,
    CRM_ACCOUNT_NAME,
    CRM_ACCOUNT_ID,
    PRO_FORMA_REGION,
    STAGE_NAME,
    NAME,
    TYPE,
    TYPE_OF_EXPANSION_C,
    SALES_LEAD_SOURCE_C,
    IS_CLOSED,
    IS_WON,
    Current_Customer_ARR,
    CRM_ARR_BAND_GRANULAR,
    Deal_Probability, 
    CLOSE_DATE,
    TOTAL_ACCOUNT_REVENUE
FROM t4 
ORDER BY TOTAL_ACCOUNT_REVENUE DESC;
