WITH csql AS (
    SELECT id AS opportunity_id, campaign_id
    FROM CLEANSED.SALESFORCE.SALESFORCE_OPPORTUNITY_BCV
),

part AS (
    SELECT id, partner, partner_deal_source
    FROM functional.gtm_sales_ops.partner_opp_table_all
),

all_opps_consolidated_cte AS (
    SELECT
        gtmi.source_snapshot_date,
        gtmi.close_year_quarter,
        gtmi.crm_opportunity_id,
        gtmi.product_arr_usd,
        gtmi.region,
        gtmi.pro_forma_market_segment,
        
        -- STATUS LOGIC
        CASE WHEN gtmi.opportunity_status = 'Closed' THEN 1 ELSE 0 END AS is_won,
        CASE WHEN gtmi.opportunity_status = 'Lost'
             AND (gtmi.deal_lost_reasonmulti__c NOT LIKE '%Duplicate%' OR gtmi.deal_lost_reasonmulti__c IS NULL) 
             THEN 1 ELSE 0 END AS is_lost,

        -- PRODUCT/SEGMENT LOGIC
        CASE WHEN gtmi.PRODUCT IN ('Contact_Center') THEN 1 ELSE 0 END AS is_CCaaS,
        CASE WHEN (gtmi.PRODUCT IN ('ES') OR gtmi.use_case_c ILIKE '%internal%') and gtmi.opportunity_type ilike '%Expansion%' THEN 1 ELSE 0 END AS is_ES,
        CASE WHEN gtmi.PRODUCT IN ('AI_Expert', 'AR', 'Copilot', 'Ultimate') THEN 1 ELSE 0 END AS is_AI_group,
        CASE WHEN gtmi.opportunity_type = 'New Business' THEN 1 ELSE 0 END AS is_New_Customer,
        CASE WHEN csql.campaign_id LIKE '%70180000001JlouAAC%' THEN 1 ELSE 0 END AS is_CSQL,
        CASE WHEN gtmi.gtm_team LIKE '%BDR%' THEN 1 ELSE 0 END AS is_BDR,
        CASE WHEN gtmi.gtm_team LIKE '%AE Only%' THEN 1 ELSE 0 END AS is_AE_ONLY,
        CASE WHEN part.partner IS NOT NULL AND part.partner != 'AWS Marketplace' THEN 1 ELSE 0 END AS is_Partner,
        CASE WHEN part.partner IS NOT NULL AND part.partner != 'AWS Marketplace' 
             AND part.partner_deal_source = 'Partner Sourced' THEN 1 ELSE 0 END AS is_sourced,
        CASE WHEN part.partner IS NOT NULL AND part.partner != 'AWS Marketplace' 
             AND part.partner_deal_source = 'Zendesk Sourced' THEN 1 ELSE 0 END AS is_influenced,


    FROM functional.gtm_sales_ops.gtmsi_consolidated_pipeline_bookings gtmi
    LEFT JOIN csql ON csql.opportunity_id = gtmi.crm_opportunity_id
    LEFT JOIN part ON part.id = gtmi.crm_opportunity_id
    WHERE gtmi.date_label = 'today'
      AND gtmi.opportunity_is_commissionable = true
      AND (gtmi.product_arr_usd > 0 OR gtmi.product_booking_arr_usd > 0)
      AND gtmi.closedate BETWEEN '2024-01-01'and current_date()-1

)

SELECT 
    source_snapshot_date AS "DATA_AS_OF",
    close_year_quarter AS "Close Quarter",
    region,
    pro_forma_market_segment,
    
    -- ==========================================
    -- 1. TOTALS
    -- ==========================================
    -- Win Rate (Count)
    COUNT(DISTINCT CASE WHEN is_won = 1 THEN crm_opportunity_id END) AS "Total Won Count",
    COUNT(DISTINCT CASE WHEN is_won = 1 OR is_lost = 1 THEN crm_opportunity_id END) AS "Total Won/Lost (Count)",
    
    -- Win Rate (Transactional ARR)
    SUM(CASE WHEN is_won = 1 THEN product_arr_usd ELSE 0 END) "Total Won Prod ARR USD",
    SUM(CASE WHEN is_won = 1 OR is_lost = 1 THEN product_arr_usd ELSE 0 END) AS "Total Won/Lost Prod ARR USD (Transactional)",

    -- ==========================================
    -- 2. CCaaS
    -- ==========================================
    -- Win Rate (Count)
    COUNT(DISTINCT CASE WHEN is_CCaaS = 1 AND is_won = 1 THEN crm_opportunity_id END) AS "CCaaS Won Count",
    COUNT(DISTINCT CASE WHEN is_CCaaS = 1 AND (is_won = 1 OR is_lost = 1) THEN crm_opportunity_id END) AS "CCaaS Total Won/Lost (Count)",

    -- Win Rate (Transactional ARR)
    SUM(CASE WHEN is_CCaaS = 1 AND is_won = 1 THEN product_arr_usd ELSE 0 END) AS "CCaaS Total Won Prod ARR USD" ,
    SUM(CASE WHEN is_CCaaS = 1 AND (is_won = 1 OR is_lost = 1) THEN product_arr_usd ELSE 0 END) AS "CCaaS Total Won/Lost Prod ARR USD (Transactional)",

    -- ==========================================
    -- 3. ES
    -- ==========================================
    -- Win Rate (Count)
    COUNT(DISTINCT CASE WHEN is_ES = 1 AND is_won = 1 THEN crm_opportunity_id END) AS "ES Won Count",
    COUNT(DISTINCT CASE WHEN is_ES = 1 AND (is_won = 1 OR is_lost = 1) THEN crm_opportunity_id END) AS "ES Total Won/Lost (Count)",
   
    -- Win Rate (Transactional ARR)
    SUM(CASE WHEN is_ES = 1 AND is_won = 1 THEN product_arr_usd ELSE 0 END) AS "ES Total Won Prod ARR USD" ,
    SUM(CASE WHEN is_ES = 1 AND (is_won = 1 OR is_lost = 1) THEN product_arr_usd ELSE 0 END) AS "ES Total Won/Lost Prod ARR USD (Transactional)",

    -- ==========================================
    -- 4. AI GROUP
    -- ==========================================
    -- Win Rate (Count)
    COUNT(DISTINCT CASE WHEN is_AI_group = 1 AND is_won = 1 THEN crm_opportunity_id END) AS "AI Group Won Count",
    COUNT(DISTINCT CASE WHEN is_AI_group = 1 AND (is_won = 1 OR is_lost = 1) THEN crm_opportunity_id END) AS "AI Group Total Won/Lost (Count)",

    -- Win Rate (Transactional ARR)
    SUM(CASE WHEN is_AI_group = 1 AND is_won = 1 THEN product_arr_usd ELSE 0 END) AS "AI Group Total Won Prod ARR USD" ,
    SUM(CASE WHEN is_AI_group = 1 AND (is_won = 1 OR is_lost = 1) THEN product_arr_usd ELSE 0 END) AS "AI Group Total Won/Lost Prod ARR USD (Transactional)",


    -- ==========================================
    -- 5. NEW CUSTOMER
    -- ==========================================
    -- Win Rate (Count)
    COUNT(DISTINCT CASE WHEN is_New_Customer = 1 AND is_won = 1 THEN crm_opportunity_id END) AS "New Customer Won Count",
    COUNT(DISTINCT CASE WHEN is_New_Customer = 1 AND (is_won = 1 OR is_lost = 1) THEN crm_opportunity_id END) AS "New Customer Total Won/Lost (Count)",

    -- Win Rate (Transactional ARR)
    SUM(CASE WHEN is_New_Customer = 1 AND is_won = 1 THEN product_arr_usd ELSE 0 END) AS "New Customer Total Won Prod ARR USD" ,
    SUM(CASE WHEN is_New_Customer = 1 AND (is_won = 1 OR is_lost = 1) THEN product_arr_usd ELSE 0 END) AS "New Customer Total Won/Lost Prod ARR USD (Transactional)",


    -- ==========================================
    -- 6. CSQL
    -- ==========================================
    -- Win Rate (Count)
    COUNT(DISTINCT CASE WHEN is_CSQL = 1 AND is_won = 1 THEN crm_opportunity_id END) AS "CSQL Won Count",
    COUNT(DISTINCT CASE WHEN is_CSQL = 1 AND (is_won = 1 OR is_lost = 1) THEN crm_opportunity_id END) AS "CSQL Total Won/Lost (Count)",

    -- Win Rate (Transactional ARR)
    SUM(CASE WHEN is_CSQL = 1 AND is_won = 1 THEN product_arr_usd ELSE 0 END) AS "CSQL Total Won Prod ARR USD" ,
    SUM(CASE WHEN is_CSQL = 1 AND (is_won = 1 OR is_lost = 1) THEN product_arr_usd ELSE 0 END) AS "CSQL Total Won/Lost Prod ARR USD (Transactional)",
    
    -- ==========================================
    -- 7.  NEW CUSTOMER BDR
    -- ==========================================
    -- Win Rate (Count)
    COUNT(DISTINCT CASE WHEN is_New_Customer = 1 AND is_BDR=1 AND is_won = 1 THEN crm_opportunity_id END) AS "New Customer BDR Won Count",
    COUNT(DISTINCT CASE WHEN is_New_Customer = 1 AND is_BDR=1 AND (is_won = 1 OR is_lost = 1) THEN crm_opportunity_id END) AS "New Customer BDR Total Won/Lost (Count)",

    -- Win Rate (Transactional ARR)
    SUM(CASE WHEN is_New_Customer = 1 AND is_BDR=1 AND is_won = 1 THEN product_arr_usd ELSE 0 END) AS "New Customer BDR Total Won Prod ARR USD" ,
    SUM(CASE WHEN is_New_Customer = 1 AND is_BDR=1 AND (is_won = 1 OR is_lost = 1) THEN product_arr_usd ELSE 0 END) AS "New Customer BDR Total Won/Lost Prod ARR USD (Transactional)",

    -- ==========================================
    -- 8.  NEW CUSTOMER AE ONLY
    -- ==========================================
    -- Win Rate (Count)
    COUNT(DISTINCT CASE WHEN is_New_Customer = 1 AND is_AE_ONLY=1 AND is_won = 1 THEN crm_opportunity_id END) AS "New Customer AE Won Count",
    COUNT(DISTINCT CASE WHEN is_New_Customer = 1 AND is_AE_ONLY=1 AND (is_won = 1 OR is_lost = 1) THEN crm_opportunity_id END) AS "New Customer AE Total Won/Lost (Count)",

    -- Win Rate (Transactional ARR)
    SUM(CASE WHEN is_New_Customer = 1 AND is_AE_ONLY=1 AND is_won = 1 THEN product_arr_usd ELSE 0 END) AS "New Customer AE Total Won Prod ARR USD" ,
    SUM(CASE WHEN is_New_Customer = 1 AND is_AE_ONLY=1 AND (is_won = 1 OR is_lost = 1) THEN product_arr_usd ELSE 0 END) AS "New Customer AE Total Won/Lost Prod ARR USD (Transactional)",



    -- ==========================================
    -- 9.  PARTNER
    -- ==========================================
    -- Win Rate (Count)
    COUNT(DISTINCT CASE WHEN is_Partner = 1 AND is_won = 1 THEN crm_opportunity_id END) AS "Partner Won Count",
    COUNT(DISTINCT CASE WHEN is_Partner = 1 AND (is_won = 1 OR is_lost = 1) THEN crm_opportunity_id END) AS "Partner Total Won/Lost (Count)",

    -- Win Rate (Transactional ARR)
    SUM(CASE WHEN is_Partner = 1 AND is_won = 1 THEN product_arr_usd ELSE 0 END) AS "Partner Total Won Prod ARR USD" ,
    SUM(CASE WHEN is_Partner = 1 AND (is_won = 1 OR is_lost = 1) THEN product_arr_usd ELSE 0 END) AS "Partner Total Won/Lost Prod ARR USD (Transactional)",
    

    -- -- ==========================================
    -- -- 10.  PARTNER SOURCED
    -- -- ==========================================
    -- Win Rate (Count)
    COUNT(DISTINCT CASE WHEN is_Partner = 1 AND is_sourced=1 AND is_won = 1 THEN crm_opportunity_id END) AS "Partner Sourced Won Count",
    COUNT(DISTINCT CASE WHEN is_Partner = 1 AND is_sourced=1 AND (is_won = 1 OR is_lost = 1) THEN crm_opportunity_id END) AS "Partner Sourced AE Total Won/Lost (Count)",

    -- Win Rate (Transactional ARR)
    SUM(CASE WHEN is_Partner = 1 AND is_sourced=1 AND is_won = 1 THEN product_arr_usd ELSE 0 END) AS "Partner Sourced Total Won Prod ARR USD" ,
    SUM(CASE WHEN is_Partner = 1 AND is_sourced=1 AND (is_won = 1 OR is_lost = 1) THEN product_arr_usd ELSE 0 END) AS "Partner Sourced Total Won/Lost Prod ARR USD (Transactional)",



    -- -- ==========================================
    -- -- 9.  PARTNER INFLUENCED
    -- -- ==========================================
  -- Win Rate (Count)
    COUNT(DISTINCT CASE WHEN is_Partner = 1 AND is_influenced=1 AND is_won = 1 THEN crm_opportunity_id END) AS "Partner Influenced Won Count",
    COUNT(DISTINCT CASE WHEN is_Partner = 1 AND is_influenced=1 AND (is_won = 1 OR is_lost = 1) THEN crm_opportunity_id END) AS "Partner Influenced AE Total Won/Lost (Count)",

    -- Win Rate (Transactional ARR)
    SUM(CASE WHEN is_Partner = 1 AND is_influenced=1 AND is_won = 1 THEN product_arr_usd ELSE 0 END) AS "Partner Influenced Total Won Prod ARR USD" ,
    SUM(CASE WHEN is_Partner = 1 AND is_influenced=1 AND (is_won = 1 OR is_lost = 1) THEN product_arr_usd ELSE 0 END) AS "Partner Influenced Total Won/Lost Prod ARR USD (Transactional)"




FROM all_opps_consolidated_cte
WHERE 1=1
      AND all_opps_consolidated_cte.region='NA'
      AND all_opps_consolidated_cte.pro_forma_market_segment not in ('SMB', 'Digital')
      
GROUP BY 1, 2, 3, 4
ORDER BY 1 DESC, 2 DESC, 4;
