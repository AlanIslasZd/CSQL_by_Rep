-- CSQL attribution to CSMs (Digital), per rep per month
-- Includes AE handoff and ARR band slicing
-- Snowflake SQL

WITH ae_roster AS (
  SELECT DISTINCT
    usr.id AS ae_id,
    usr.name AS ae_name
  FROM CLEANSED.SALESFORCE.SALESFORCE_USER_SCD2 usr
  JOIN CLEANSED.SALESFORCE.SALESFORCE_USER_TERRITORY_2_ASSOCIATION_SCD2 assoc
    ON usr.id = assoc.user_id
    AND assoc.valid_to_timestamp = '9999-12-31'
    AND assoc.role_in_territory_2 IN ('Account Executive', 'Account Executive - Coverage')
  WHERE usr.valid_to_timestamp = '9999-12-31'
    AND usr.is_active = TRUE
),

csm_roster AS (
  -- Monthly account snapshot used to attribute opps to CSMs at creation month
  SELECT DISTINCT
    DATE_TRUNC('month', TO_DATE(a.SERVICE_DATE)) AS snapshot_month,
    a.CRM_ACCOUNT_ID,
    COALESCE(a.RENEWAL_REP_NAME, a.ACCOUNT_OWNER_NAME) AS csm_name,
    --COALESCE(a.RENEWAL_REP_EMAIL, a.ACCOUNT_OWNER_EMAIL) AS csm_email,
    a.CRM_ARR_BAND_GRANULAR,
    a.PRO_FORMA_MARKET_SEGMENT
  FROM PRESENTATION.CUSTOMER_EXPERIENCE.RENEWALS_EXCELLENCE__ACCOUNTS a
  WHERE a.PRO_FORMA_MARKET_SEGMENT = 'Digital'
),

opps AS (
  SELECT
    b.ACCOUNT_ID,
    b.OWNER_ID AS ae_id,
    DATE_TRUNC('month', TO_DATE(b.CREATED_DATE)) AS creation_month,
    TO_DATE(b.CREATED_DATE) AS created_date,
    TO_DATE(b.CLOSE_DATE) AS close_date,
    b.STAGE_NAME,
    b.NAME,
    b.TYPE,
    b.SALES_LEAD_SOURCE_C,
    b.CAMPAIGN_ID,
    COALESCE(b.SUPPORT_ADD_ON_ARR_C, b.EXPECTED_REVENUE, b.AMOUNT) AS value_usd,
    b.IS_CLOSED,
    b.IS_WON,
    CASE
      WHEN UPPER(b.SALES_LEAD_SOURCE_C) LIKE '%CSQL%'
           OR b.CAMPAIGN_ID IN ('70180000001JlouAAC') -- extend this list if needed
      THEN 1 ELSE 0
    END AS is_csql
  FROM CLEANSED.SALESFORCE.SALESFORCE_OPPORTUNITY_SCD2 b
  WHERE b.valid_to_timestamp = '9999-12-31'
    AND TO_DATE(b.CREATED_DATE) >= TO_DATE('2025-07-01')  -- Q3/Q4 2025
    AND b.TYPE <> 'New Business'                          -- focus on upsell/cross-sell
    AND b.STAGE_NAME NOT IN ('Omitted')
),

opps_tagged AS (
  SELECT
    o.*,
    ar.ae_name
  FROM opps o
  LEFT JOIN ae_roster ar
    ON o.ae_id = ar.ae_id
),

csql_attributed AS (
  -- Attribute CSQL opps to the CSM responsible for the account in the month the opp was created
  SELECT
    o.creation_month,
    cr.csm_name,
    --cr.csm_email,
    cr.CRM_ARR_BAND_GRANULAR AS arr_band,
    o.ae_name,
    o.value_usd,
    o.is_won
  FROM opps_tagged o
  JOIN csm_roster cr
    ON cr.CRM_ACCOUNT_ID = o.ACCOUNT_ID
   AND cr.snapshot_month = o.creation_month
  WHERE o.is_csql = 1
)

SELECT
  csm_name,
  --csm_email,
  creation_month,
  arr_band,
  COUNT(*) AS csql_created,                               -- per rep per month
  AVG(NULLIF(value_usd, 0)) AS ads_usd,                   -- revenue estimate (ADS)
  SUM(IFF(is_won, 1, 0)) AS won_deals,                    -- conversion numerator
  SUM(IFF(is_won, 1, 0)) / NULLIF(COUNT(*), 0) AS win_rate,
  COUNT(DISTINCT ae_name) AS distinct_ae_partners         -- optional: AE handoff breadth
FROM csql_attributed
GROUP BY csm_name, 
--csm_email, 
creation_month, arr_band
ORDER BY creation_month DESC, csm_name;

