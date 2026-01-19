with
initial_opp_stage as (
select distinct
        source_snapshot_date as initial_snapshot,
        crm_opportunity_id,
        opportunity_stage_name as initial_stage_name,
        OPPORTUNITY_CLOSE_DATE as initial_closedate
    from
        foundational.customer.dim_crm_opportunities_daily_snapshot
    where
        source_snapshot_date = (select dateadd(day, -28, max(source_snapshot_date)) from foundational.customer.dim_crm_opportunities_daily_snapshot)
        )

, csql AS (
    SELECT id AS opportunity_id, campaign_id
    FROM CLEANSED.SALESFORCE.SALESFORCE_OPPORTUNITY_BCV
),

part AS (
    SELECT id, partner, partner_deal_source
    FROM functional.gtm_sales_ops.partner_opp_table_all
),

all_opps_consolidated_cte AS (
    SELECT
    DISTINCT
        gtmi.source_snapshot_date,
        gtmi.close_year_quarter,
        gtmi.crm_opportunity_id,
        gtmi.product_arr_usd,
        gtmi.stage_name,
        gtmi.opportunity_status,
        gtmi.closedate,
        gtmi.product_booking_arr_usd, gtmi.product_arr_usd,
        gtmi.region, gtmi.pro_forma_market_segment, gtmi.stage_2_plus_date_c, gtmi.product,

        
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
    LEFT JOIN foundational.finance.dim_date dd on gtmi.source_snapshot_date=dd.the_date
    WHERE gtmi.date_label = 'today'
      AND gtmi.opportunity_is_commissionable = true
      AND (gtmi.product_arr_usd > 0 OR gtmi.product_booking_arr_usd > 0)     
      AND gtmi.region='NA'
      AND gtmi.pro_forma_market_segment not in ('SMB', 'Digital')
      AND product='Total Booking'
),

---
--ALL OPPS
---

closed_cte AS (
    SELECT *
    FROM all_opps_consolidated_cte
    WHERE 
        opportunity_status='Closed'
    ),

pipeline_cte AS (
    SELECT *
    FROM all_opps_consolidated_cte
    WHERE 
        opportunity_status!='Closed'

)

, all_opps as (
select * from closed_cte
union 
select * from pipeline_cte
),


conversion_calc AS (
    SELECT 
        s2.crm_opportunity_id,
        s2.source_snapshot_date,
        ios.initial_snapshot as source_snapshot_date_28d_ago,
        ios.initial_stage_name as stage_name_28d_ago,
        s2.stage_name as current_stage_name,
        ios.initial_closedate as closedate_28d_ago,
        s2.closedate as current_closedate,

s2.region, s2.pro_forma_market_segment, s2.stage_2_plus_date_c, s2.product,
        
        
        s2.is_CCaaS, s2.is_ES, s2.is_AI_group, s2.is_New_Customer, 
        s2.is_CSQL, s2.is_BDR, s2.is_AE_ONLY, s2.is_Partner, 
        s2.is_sourced, s2.is_influenced,
        
        --status boolean
        CASE WHEN ios.initial_stage_name='01 - Qualify Need' THEN 1 ELSE 0 END AS was_S1,
        CASE WHEN ios.initial_stage_name='02 - Confirm Need' THEN 1 ELSE 0 END AS was_S2,
        CASE WHEN ios.initial_stage_name='03 - Establish Value' THEN 1 ELSE 0 END AS was_S3,
        CASE WHEN ios.initial_stage_name='04 - Demonstrate Value' THEN 1 ELSE 0 END AS was_S4,
        CASE WHEN ios.initial_stage_name='05 - Secure Commitment' THEN 1 ELSE 0 END AS was_S5,
        CASE WHEN ios.initial_stage_name='06 - Contracting' THEN 1 ELSE 0 END AS was_S6,
        CASE WHEN ios.initial_stage_name='07 - Signed' THEN 1 ELSE 0 END AS was_S7,
        CASE WHEN s2.stage_name='02 - Confirm Need' THEN 1 ELSE 0 END AS in_S2,
        CASE WHEN s2.stage_name='03 - Establish Value' THEN 1 ELSE 0 END AS in_S3,
        CASE WHEN s2.stage_name='04 - Demonstrate Value' THEN 1 ELSE 0 END AS in_S4,
        CASE WHEN s2.stage_name='05 - Secure Commitment' THEN 1 ELSE 0 END AS in_S5,
        CASE WHEN s2.stage_name='06 - Contracting' THEN 1 ELSE 0 END AS in_S6,
        CASE WHEN s2.stage_name='07 - Signed' THEN 1 ELSE 0 END AS in_S7,
        CASE WHEN s2.stage_name IN ('02 - Confirm Need', '03 - Establish Value', '04 - Demonstrate Value', '05 - Secure Commitment', '06 - Contracting') THEN 1 ELSE 0 END AS in_S2plus,

        --Movement statements
        -- was S2, now S4, 5, or 6
        CASE 
            WHEN ios.initial_stage_name = '02 - Confirm Need' AND s2.stage_name IN ('04 - Demonstrate Value', '05 - Secure Commitment', '06 - Contracting') 
            THEN 1 ELSE 0 END AS has_converted_S2_S4,

        CASE 
            WHEN ios.initial_stage_name = '01 - Qualify Need' AND s2.stage_name IN ('02 - Confirm Need') 
            THEN 1 ELSE 0 END AS has_converted_S1_S2,
        CASE 
            WHEN ios.initial_stage_name = '02 - Confirm Need' AND s2.stage_name IN ('03 - Establish Value') 
            THEN 1 ELSE 0 END AS has_converted_S2_S3,

        --Slippage logic
        
        -- Classify Initial Close Date
        case
            when ios.initial_closedate between date_trunc(quarter, ios.initial_snapshot) and dateadd(day, -1, dateadd(quarter, 1, date_trunc(quarter,ios.initial_snapshot))) then 'In CQ'
            when ios.initial_closedate < date_trunc(quarter, ios.initial_snapshot) then 'Prior to CQ'
            when ios.initial_closedate > dateadd(day, -1, dateadd(quarter, 1, date_trunc(quarter,ios.initial_snapshot))) then 'Out of CQ'
            else 'Check'
        end as initial_closedate_classification,
        
        -- Classify Current Close Date
        case
            when s2.closedate between date_trunc(quarter, ios.initial_snapshot) and dateadd(day, -1, dateadd(quarter, 1, date_trunc(quarter,ios.initial_snapshot))) then 'In CQ'
            when s2.closedate < date_trunc(quarter, ios.initial_snapshot) then 'Prior to CQ'
            when s2.closedate > dateadd(day, -1, dateadd(quarter, 1, date_trunc(quarter,ios.initial_snapshot))) then 'Out of CQ'
            else 'Check'
        end as most_recent_closedate_classification,
         case
            when initial_closedate_classification = 'In CQ' and most_recent_closedate_classification = 'Out of CQ' then 'Slipped out of CQ'
            when initial_closedate_classification = 'Out of CQ' and most_recent_closedate_classification = 'In CQ' then 'Brought into CQ'
            else most_recent_closedate_classification
    end as opp_close_status,
            
    FROM all_opps s2
    LEFT JOIN initial_opp_stage ios 
        ON s2.crm_opportunity_id = ios.crm_opportunity_id
    GROUP BY ALL
)

SELECT 
    source_snapshot_date AS "DATA_AS_OF",
    dd.year_quarter AS "As of Quarter",
    dd.fiscal_year_quarter AS "As of FQ",
    -- ==========================================
    -- 1. TOTALS
    -- ==========================================
    COUNT(DISTINCT CASE WHEN in_S2plus=1 THEN crm_opportunity_id END) AS "Total opps currently in S2-S6 Count",
    --a reference point for all the opps in the current state in stages 2-6
    COUNT(DISTINCT CASE WHEN has_converted_S2_S4=1 THEN crm_opportunity_id END) AS "Total S2 > S4 Conversions Count",
    --covers ops that were in stage 2 28d ago and are now in stages 4,5, or 6
    COUNT(DISTINCT CASE WHEN was_S2=1 THEN crm_opportunity_id END) "Total S2 Count 28D ago",
    --these are the opps we're looking at movement for
    COUNT(DISTINCT CASE WHEN has_converted_S2_S4 = 1 THEN crm_opportunity_id END) / NULLIF(COUNT(DISTINCT CASE WHEN was_S2=1 THEN crm_opportunity_id else null end), 0) AS  "Total S2 > S4 Conv Rate",


        -- Denominator: Count of Deals expected to close in Qtr (28 days ago)
   count(distinct case when initial_closedate_classification = 'In CQ' then crm_opportunity_id end) as initial_pipeline_opps,
    
    -- Numerator: Count of those deals that slipped out
    count(distinct case when opp_close_status = 'Slipped out of CQ' then crm_opportunity_id end) as slipped_opps,
    
    -- Rate Calculation
    div0(
        count(distinct case when opp_close_status = 'Slipped out of CQ' then crm_opportunity_id end),
        count(distinct case when initial_closedate_classification = 'In CQ' then crm_opportunity_id end)
    ) * 100 as slippage_rate_pct,
    
    -- taking the amount of ops that moved out of the opps available to move

    -- ==========================================
    -- 2. CCaaS
    -- ==========================================
    COUNT(DISTINCT CASE WHEN is_CCaaS=1 AND has_converted_S2_S4=1 THEN crm_opportunity_id END) AS "Total S2 > S4 CCaaS Count",
    COUNT(DISTINCT CASE WHEN is_CCaaS=1 AND was_S2=1 THEN crm_opportunity_id END) "Total S2 CCaaS Count 28D ago",
    COUNT(DISTINCT CASE WHEN is_CCaaS=1 AND has_converted_S2_S4 = 1 THEN crm_opportunity_id END) / NULLIF(COUNT(DISTINCT CASE WHEN is_CCaaS=1 AND was_S2=1 THEN crm_opportunity_id else null end), 0) AS  "Total CCaaS S2 > S4 Conv Rate",


   div0(count(distinct case when opp_close_status = 'Slipped out of CQ' AND is_CCaaS=1 then crm_opportunity_id end),
   count(distinct case when initial_closedate_classification = 'In CQ' AND is_CCaaS=1 then crm_opportunity_id end)
    ) * 100 as CCaaS_slippage_rate_pct,

    -- ==========================================
    -- 3. ES
    -- ==========================================
    COUNT(DISTINCT CASE WHEN is_ES=1 AND has_converted_S2_S4=1 THEN crm_opportunity_id END) AS "Total S2 > S4 ES Count",
    COUNT(DISTINCT CASE WHEN is_ES=1 AND was_S2=1 THEN crm_opportunity_id END) "Total S2 ES Count 28D ago",
    COUNT(DISTINCT CASE WHEN is_ES=1 AND has_converted_S2_S4 = 1 THEN crm_opportunity_id END) / NULLIF(COUNT(DISTINCT CASE WHEN is_ES=1 AND was_S2=1 THEN crm_opportunity_id else null end), 0) AS  "Total ES S2 > S4 Conv Rate",

   div0(count(distinct case when opp_close_status = 'Slipped out of CQ' AND is_ES=1 then crm_opportunity_id end),
   count(distinct case when initial_closedate_classification = 'In CQ' AND is_ES=1 then crm_opportunity_id end)
    ) * 100 as ES_slippage_rate_pct,

    -- -- ==========================================
    -- -- 4. AI GROUP
    -- -- ==========================================
    COUNT(DISTINCT CASE WHEN is_AI_group=1 AND has_converted_S2_S4=1 THEN crm_opportunity_id END) AS "Total S2_S4 AI GROUP Count",
    COUNT(DISTINCT CASE WHEN is_AI_group=1 AND was_S2=1 THEN crm_opportunity_id END) "Total S2 AI GROUP Count 28D ago",
    COUNT(DISTINCT CASE WHEN is_AI_group=1 AND has_converted_S2_S4 = 1 THEN crm_opportunity_id END) / NULLIF(COUNT(DISTINCT CASE WHEN is_AI_group=1 AND was_S2=1 THEN crm_opportunity_id else null end), 0) AS  "Total AI GROUP S2 > S4 Conv Rate",

    div0(count(distinct case when opp_close_status = 'Slipped out of CQ' AND is_AI_group=1 then crm_opportunity_id end),
   count(distinct case when initial_closedate_classification = 'In CQ' AND is_AI_group=1 then crm_opportunity_id end)
    ) * 100 as AI_slippage_rate_pct,
    
    -- -- ==========================================
    -- -- 5. NEW CUSTOMER
    -- -- ==========================================
    COUNT(DISTINCT CASE WHEN is_New_Customer=1 AND has_converted_S2_S4=1 THEN crm_opportunity_id END) AS "Total S2_S4 NB Count",
    COUNT(DISTINCT CASE WHEN is_New_Customer=1 AND was_S2=1 THEN crm_opportunity_id END) "Total S2 NB Count 28D ago",
    COUNT(DISTINCT CASE WHEN is_New_Customer=1 AND has_converted_S2_S4 = 1 THEN crm_opportunity_id END) / NULLIF(COUNT(DISTINCT CASE WHEN is_New_Customer=1 AND was_S2=1 THEN crm_opportunity_id else null end), 0) AS  "Total NB S2 > S4 Conv Rate",

    div0(count(distinct case when opp_close_status = 'Slipped out of CQ' AND is_New_Customer=1 then crm_opportunity_id end),
   count(distinct case when initial_closedate_classification = 'In CQ' AND is_New_Customer=1 then crm_opportunity_id end)
    ) * 100 as NB_slippage_rate_pct,
    
    -- -- ==========================================
    -- -- 6. CSQL
    -- -- ==========================================
    COUNT(DISTINCT CASE WHEN is_CSQL=1 AND has_converted_S2_S4=1 THEN crm_opportunity_id END) AS "Total S2_S4 CSQL Count",
    COUNT(DISTINCT CASE WHEN is_CSQL=1 AND was_S2=1 THEN crm_opportunity_id END) "Total S2 CSQL Count 28D ago",
    COUNT(DISTINCT CASE WHEN is_CSQL=1 AND has_converted_S2_S4 = 1 THEN crm_opportunity_id END) / NULLIF(COUNT(DISTINCT CASE WHEN is_CSQL=1 AND was_S2=1 THEN crm_opportunity_id else null end), 0) AS  "Total CSQL S2 > S4 Conv Rate",
     COUNT(DISTINCT CASE WHEN is_CSQL=1 AND has_converted_S2_S3 = 1 THEN crm_opportunity_id END) / NULLIF(COUNT(DISTINCT CASE WHEN is_CSQL=1 AND was_S2=1 THEN crm_opportunity_id else null end), 0) AS  "Total CSQL S2 > S3 Conv Rate",
    

   div0(count(distinct case when opp_close_status = 'Slipped out of CQ' AND is_CSQL=1 then crm_opportunity_id end),
   count(distinct case when initial_closedate_classification = 'In CQ' AND is_CSQL=1 then crm_opportunity_id end)
    ) * 100 as CSQL_slippage_rate_pct,
    
    -- -- ==========================================
    -- -- 7.  NEW CUSTOMER BDR
    -- -- ==========================================
    COUNT(DISTINCT CASE WHEN is_BDR=1 AND is_New_Customer=1 AND has_converted_S2_S4=1 THEN crm_opportunity_id END) AS "Total S2_S4 NB BDR Count",
    COUNT(DISTINCT CASE WHEN is_BDR=1 AND is_New_Customer=1 AND was_S2=1 THEN crm_opportunity_id END) "Total S2 NB BDR Count 28D ago",
    COUNT(DISTINCT CASE WHEN is_BDR=1 AND is_New_Customer=1 AND has_converted_S2_S4 = 1 THEN crm_opportunity_id END) / NULLIF(COUNT(DISTINCT CASE WHEN is_BDR=1 AND is_New_Customer=1 AND was_S2=1 THEN crm_opportunity_id else null end), 0) AS  "Total NB BDR S2 > S4 Conv Rate",
    
    COUNT(DISTINCT CASE WHEN is_BDR=1 AND is_New_Customer=1 AND has_converted_S1_S2 = 1 THEN crm_opportunity_id END) / NULLIF(COUNT(DISTINCT CASE WHEN is_BDR=1 AND is_New_Customer=1  AND was_S1=1 THEN crm_opportunity_id else null end), 0) AS  "Total NB BDR S1 > S2 Conv Rate",

    div0(count(distinct case when opp_close_status = 'Slipped out of CQ' AND is_BDR=1 AND is_New_Customer=1 then crm_opportunity_id end),
   count(distinct case when initial_closedate_classification = 'In CQ' AND is_BDR=1 AND is_New_Customer=1 then crm_opportunity_id end)
    ) * 100 as BDR_NB_slippage_rate_pct,
    -- -- ==========================================
    -- -- 8.  NEW CUSTOMER AE ONLY
    -- -- ==========================================
    COUNT(DISTINCT CASE WHEN is_AE_ONLY=1 AND is_New_Customer=1 AND has_converted_S2_S4=1 THEN crm_opportunity_id END) AS "Total S2_S4 NB AE Count",
    COUNT(DISTINCT CASE WHEN is_AE_ONLY=1 AND is_New_Customer=1 AND was_S2=1 THEN crm_opportunity_id END) "Total S2 NB AE Count 28D ago",
    COUNT(DISTINCT CASE WHEN is_AE_ONLY=1 AND is_New_Customer=1 AND has_converted_S2_S4 = 1 THEN crm_opportunity_id END) / NULLIF(COUNT(DISTINCT CASE WHEN is_AE_ONLY=1 AND is_New_Customer=1 AND was_S2=1 THEN crm_opportunity_id else null end), 0) AS  "Total NB AE S2 > S4 Conv Rate",

    div0(count(distinct case when opp_close_status = 'Slipped out of CQ' AND is_AE_ONLY=1 AND is_New_Customer=1 then crm_opportunity_id end),
   count(distinct case when initial_closedate_classification = 'In CQ' AND is_AE_ONLY=1 AND is_New_Customer=1 then crm_opportunity_id end)
    ) * 100 as AE_NB_slippage_rate_pct,
    
    -- -- ==========================================
    -- -- 9.  PARTNER
    -- -- ==========================================
    COUNT(DISTINCT CASE WHEN is_Partner=1 AND has_converted_S2_S4=1 THEN crm_opportunity_id END) AS "Total S2_S4 Partner Count",
    COUNT(DISTINCT CASE WHEN is_Partner=1 AND was_S2=1 THEN crm_opportunity_id END) "Total S2 Partner Count 28D ago",
    COUNT(DISTINCT CASE WHEN is_Partner=1 AND has_converted_S2_S4 = 1 THEN crm_opportunity_id END) / NULLIF(COUNT(DISTINCT CASE WHEN is_Partner=1 AND was_S2=1 THEN crm_opportunity_id else null end), 0) AS  "Total Partner S2 > S4 Conv Rate",
    COUNT(DISTINCT CASE WHEN is_Partner=1 AND has_converted_S1_S2 = 1 THEN crm_opportunity_id END) / NULLIF(COUNT(DISTINCT CASE WHEN is_Partner=1 AND was_S1=1 THEN crm_opportunity_id else null end), 0) AS  "Total Partner S1 > S2 Conv Rate",

    div0(count(distinct case when opp_close_status = 'Slipped out of CQ' AND is_Partner=1 then crm_opportunity_id end),
   count(distinct case when initial_closedate_classification = 'In CQ' AND is_Partner=1 then crm_opportunity_id end)
    ) * 100 as Partner_slippage_rate_pct,
    

    -- -- -- ==========================================
    -- -- -- 10.  PARTNER SOURCED
    -- -- -- ==========================================
    
    COUNT(DISTINCT CASE WHEN is_Partner=1 AND is_sourced=1 AND has_converted_S2_S4=1 THEN crm_opportunity_id END) AS "Total S2_S4 Partner Sourced Count",
    COUNT(DISTINCT CASE WHEN is_Partner=1 AND is_sourced=1 AND was_S2=1 THEN crm_opportunity_id END) "Total S2 Partner Sourced Count 28D ago",
    COUNT(DISTINCT CASE WHEN is_Partner=1 AND is_sourced=1 AND has_converted_S2_S4 = 1 THEN crm_opportunity_id END) / NULLIF(COUNT(DISTINCT CASE WHEN is_Partner=1 AND is_sourced=1 AND was_S2=1 THEN crm_opportunity_id else null end), 0) AS  "Total Partner Sourced S2 > S4 Conv Rate",

    div0(count(distinct case when opp_close_status = 'Slipped out of CQ' AND is_Partner=1 AND is_sourced=1 then crm_opportunity_id end),
   count(distinct case when initial_closedate_classification = 'In CQ' AND is_Partner=1 AND is_sourced=1 then crm_opportunity_id end)
    ) * 100 as Partner_sourced_slippage_rate_pct,

    -- -- -- ==========================================
    -- -- -- 9.  PARTNER INFLUENCED
    -- -- -- ==========================================
    COUNT(DISTINCT CASE WHEN is_Partner=1 AND is_influenced=1 AND has_converted_S2_S4=1 THEN crm_opportunity_id END) AS "Total S2_S4 Partner Influenced Count",
    COUNT(DISTINCT CASE WHEN is_Partner=1 AND is_influenced=1 AND was_S2=1 THEN crm_opportunity_id END) "Total S2 Partner Influenced Count 28D ago",
    COUNT(DISTINCT CASE WHEN is_Partner=1 AND is_influenced=1 AND has_converted_S2_S4 = 1 THEN crm_opportunity_id END) / NULLIF(COUNT(DISTINCT CASE WHEN is_Partner=1 AND is_influenced=1 AND was_S2=1 THEN crm_opportunity_id else null end), 0) AS  "Total Partner Influenced S2 > S4 Conv Rate",


    div0(count(distinct case when opp_close_status = 'Slipped out of CQ' AND is_Partner=1 AND is_influenced=1 then crm_opportunity_id end),
   count(distinct case when initial_closedate_classification = 'In CQ' AND is_Partner=1 AND is_influenced=1 then crm_opportunity_id end)
    ) * 100 as Partner_influenced_slippage_rate_pct,

FROM 
conversion_calc cc
    left join foundational.finance.dim_date dd on cc.source_snapshot_date=dd.the_date

WHERE 1=1

------------------------------------------
--****------------****--------------****--
---CHANGE FILTERS HERE FOR REGIONAL QBRS--
--****------------****--------------****--
------------------------------------------
      AND region='NA'
      AND pro_forma_market_segment not in ('SMB', 'Digital')

GROUP BY 1,2,3
ORDER BY 1 DESC
