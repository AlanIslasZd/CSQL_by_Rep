-- 1. Roster (Denominator: Active AEs)
WITH roster AS (
    SELECT DISTINCT
        usr.id AS AE_ID,
        usr.name AS AE_NAME,
        usr.market_segment_c AS AE_SEGMENT,
        usr.vp_team_c AS AE_REGION
    FROM CLEANSED.SALESFORCE.SALESFORCE_USER_SCD2 AS usr
    INNER JOIN CLEANSED.SALESFORCE.SALESFORCE_USER_TERRITORY_2_ASSOCIATION_SCD2 AS assoc
        ON usr.id = assoc.user_id AND assoc.valid_to_timestamp = '9999-12-31'
        AND assoc.role_in_territory_2 IN ('Account Executive', 'Account Executive - Coverage')
    WHERE usr.valid_to_timestamp = '9999-12-31'
      AND usr.is_active = TRUE
     
      
------------------------------------------
--****------------****--------------****--
---CHANGE FILTERS HERE FOR REGIONAL QBRS--
--****------------****--------------****--
------------------------------------------
     AND usr.vp_team_c ='AMER'
     AND usr.market_segment_c NOT IN ('SMB', 'Digital') 

),

-- 2. CSQL Helper (Campaigns & Use Case)
csql as (
    select 
        id as opportunity_id, 
        campaign_id
    from CLEANSED.SALESFORCE.SALESFORCE_OPPORTUNITY_SCD2
),

-- 3. Partner Helper
part as (
    select
        id, 
        partner, 
        partner_deal_source
    from functional.gtm_sales_ops.partner_opp_table_all
),

-- 4. Opportunities Source (Base Table + Joins)
source_opps AS (
    SELECT
        o.OWNERID,
        o.SOURCE_SNAPSHOT_DATE, 
        o.CRM_OPPORTUNITY_ID,
        o.PRODUCT,
        o.TYPE,
        o.stage_name,
        o.OPPORTUNITY_STATUS,
        o.closedate,
        CAST(o.stage_2_plus_date_c AS DATE) as s2_date,
        
        -- Pulling in Helper Columns
        c.campaign_id,
        o.use_case_c,
        p.partner,
        p.partner_deal_source,

        -- AI Flags
        CASE WHEN o.PRODUCT IN ('AI_Expert')
          THEN 1 ELSE 0 END as is_ai_expert,
        CASE WHEN o.PRODUCT IN ('Ultimate_AR','Zendesk_AR','Ultimate','AR')
          THEN 1 ELSE 0 END as is_ai_agent,
        CASE WHEN o.PRODUCT IN ('Copilot')
          THEN 1 ELSE 0 END as is_ai_copilot,
        CASE WHEN o.PRODUCT IN ('QA')
          THEN 1 ELSE 0 END as is_qa,
        CASE WHEN o.PRODUCT IN ('WEM')
          THEN 1 ELSE 0 END as is_wem, 
       CASE WHEN o.PRODUCT IN ('AI Expert', 'Ultimate_AR','Zendesk_AR','Ultimate','AR', 'Copilot', 'QA', 'WEM')
          THEN 1 ELSE 0 END as is_ai_group_new,
        CASE WHEN o.PRODUCT IN ('Copilot','Ultimate_AR','AR','Zendesk_AR','Generative_Search','Ultimate','AI_Expert')
          THEN 1 ELSE 0 END as is_ai,
        CASE WHEN o.PRODUCT = 'ES' OR o.use_case_c ILIKE '%internal%' THEN 1 ELSE 0 END as is_es,
        CASE WHEN o.PRODUCT = 'Contact_Center' THEN 1 ELSE 0 END as is_cc,
        CASE WHEN o.opportunity_type = 'New Business' THEN 1 ELSE 0 END as is_nb,
        CASE WHEN c.campaign_id LIKE '%70180000001JlouAAC%' THEN 1 ELSE 0 END as is_cs,
        CASE WHEN p.partner IS NOT NULL AND p.partner != 'AWS Marketplace' 
              AND p.partner_deal_source = 'Partner Sourced' THEN 1 ELSE 0 END as is_partner_sourced,
        CASE WHEN p.partner IS NOT NULL AND p.partner != 'AWS Marketplace' 
              AND p.partner_deal_source = 'Zendesk Sourced' THEN 1 ELSE 0 END as is_partner_influenced
    FROM FUNCTIONAL.GTM_SALES_OPS.GTMSI_CONSOLIDATED_PIPELINE_BOOKINGS o
    LEFT JOIN csql c ON c.opportunity_id = o.crm_opportunity_id
    LEFT JOIN part p ON p.id = o.crm_opportunity_id
    WHERE o.DATE_LABEL = 'end of -1 quarter'
        AND o.opportunity_is_commissionable = 'TRUE'
        AND (o.product_arr_usd > 0 OR o.product_booking_arr_usd > 0)

        
------------------------------------------
--****------------****--------------****--
---CHANGE FILTERS HERE FOR REGIONAL QBRS--
--****------------****--------------****--
------------------------------------------
        AND o.region = 'NA'
        AND o.pro_forma_market_segment not in ('Digital', 'SMB') 
),

-- 5. Aggregation by AE
ae_aggregates AS (
    SELECT
        MAX(SOURCE_SNAPSHOT_DATE) AS DATA_AS_OF, -- <--- Added Date aggregation
        OWNERID,
        -- ===================== 1. AI =====================
        COUNT(DISTINCT CASE WHEN is_ai=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' THEN CRM_OPPORTUNITY_ID END) AS ai_open_total,
        COUNT(DISTINCT CASE WHEN is_ai=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03') THEN CRM_OPPORTUNITY_ID END) AS ai_open_in_s2,
        COUNT(DISTINCT CASE WHEN is_ai=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03','04','05','06') THEN CRM_OPPORTUNITY_ID END) AS ai_open_s2_plus,
        COUNT(DISTINCT CASE WHEN is_ai=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('04','05','06') THEN CRM_OPPORTUNITY_ID END) AS ai_open_s4_plus,
        COUNT(DISTINCT CASE WHEN is_ai=1 AND OPPORTUNITY_STATUS='Closed' AND closedate >= DATEADD(day, -90, CURRENT_DATE()) THEN CRM_OPPORTUNITY_ID END) AS ai_closed_l90,

        COUNT(DISTINCT CASE WHEN is_ai_agent=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' THEN CRM_OPPORTUNITY_ID END) AS ai_agent_open_total,
        COUNT(DISTINCT CASE WHEN is_ai_agent=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03') THEN CRM_OPPORTUNITY_ID END) AS ai_agent_open_in_s2,
        COUNT(DISTINCT CASE WHEN is_ai_agent=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03','04','05','06') THEN CRM_OPPORTUNITY_ID END) AS ai_agent_open_s2_plus,
        COUNT(DISTINCT CASE WHEN is_ai_agent=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('04','05','06') THEN CRM_OPPORTUNITY_ID END) AS ai_agent_open_s4_plus,
        COUNT(DISTINCT CASE WHEN is_ai_agent=1 AND OPPORTUNITY_STATUS='Closed' AND closedate >= DATEADD(day, -90, CURRENT_DATE()) THEN CRM_OPPORTUNITY_ID END) AS ai_agent_closed_l90,

        COUNT(DISTINCT CASE WHEN is_ai_copilot=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' THEN CRM_OPPORTUNITY_ID END) AS ai_copilot_open_total,
        COUNT(DISTINCT CASE WHEN is_ai_copilot=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03') THEN CRM_OPPORTUNITY_ID END) AS ai_copilot_open_in_s2,
        COUNT(DISTINCT CASE WHEN is_ai_copilot=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03','04','05','06') THEN CRM_OPPORTUNITY_ID END) AS ai_copilot_open_s2_plus,
        COUNT(DISTINCT CASE WHEN is_ai_copilot=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('04','05','06') THEN CRM_OPPORTUNITY_ID END) AS ai_copilot_open_s4_plus,
        COUNT(DISTINCT CASE WHEN is_ai_copilot=1 AND OPPORTUNITY_STATUS='Closed' AND closedate >= DATEADD(day, -90, CURRENT_DATE()) THEN CRM_OPPORTUNITY_ID END) AS ai_copilot_closed_l90,

        COUNT(DISTINCT CASE WHEN is_qa=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' THEN CRM_OPPORTUNITY_ID END) AS qa_open_total,
        COUNT(DISTINCT CASE WHEN is_qa=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03') THEN CRM_OPPORTUNITY_ID END) AS qa_open_in_s2,
        COUNT(DISTINCT CASE WHEN is_qa=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03','04','05','06') THEN CRM_OPPORTUNITY_ID END) AS qa_open_s2_plus,
        COUNT(DISTINCT CASE WHEN is_qa=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('04','05','06') THEN CRM_OPPORTUNITY_ID END) AS qa_open_s4_plus,
        COUNT(DISTINCT CASE WHEN is_qa=1 AND OPPORTUNITY_STATUS='Closed' AND closedate >= DATEADD(day, -90, CURRENT_DATE()) THEN CRM_OPPORTUNITY_ID END) AS qa_closed_l90,

        COUNT(DISTINCT CASE WHEN is_wem=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' THEN CRM_OPPORTUNITY_ID END) AS wem_open_total,
        COUNT(DISTINCT CASE WHEN is_wem=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03') THEN CRM_OPPORTUNITY_ID END) AS wem_open_in_s2,
        COUNT(DISTINCT CASE WHEN is_wem=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03','04','05','06') THEN CRM_OPPORTUNITY_ID END) AS wem_open_s2_plus,
        COUNT(DISTINCT CASE WHEN is_wem=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('04','05','06') THEN CRM_OPPORTUNITY_ID END) AS wem_open_s4_plus,
        COUNT(DISTINCT CASE WHEN is_wem=1 AND OPPORTUNITY_STATUS='Closed' AND closedate >= DATEADD(day, -90, CURRENT_DATE()) THEN CRM_OPPORTUNITY_ID END) AS wem_closed_l90,    

        COUNT(DISTINCT CASE WHEN is_ai_expert=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' THEN CRM_OPPORTUNITY_ID END) AS ai_expert_open_total,
        COUNT(DISTINCT CASE WHEN is_ai_expert=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03') THEN CRM_OPPORTUNITY_ID END) AS ai_expert_open_in_s2,
        COUNT(DISTINCT CASE WHEN is_ai_expert=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03','04','05','06') THEN CRM_OPPORTUNITY_ID END) AS ai_expert_open_s2_plus,
        COUNT(DISTINCT CASE WHEN is_ai_expert=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('04','05','06') THEN CRM_OPPORTUNITY_ID END) AS ai_expert_open_s4_plus,
        COUNT(DISTINCT CASE WHEN is_ai_expert=1 AND OPPORTUNITY_STATUS='Closed' AND closedate >= DATEADD(day, -90, CURRENT_DATE()) THEN CRM_OPPORTUNITY_ID END) AS ai_expert_closed_l90,    

        COUNT(DISTINCT CASE WHEN is_ai_group_new=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' THEN CRM_OPPORTUNITY_ID END) AS ai_group_new_open_total,
        COUNT(DISTINCT CASE WHEN is_ai_group_new=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03') THEN CRM_OPPORTUNITY_ID END) AS ai_group_new_open_in_s2,
        COUNT(DISTINCT CASE WHEN is_ai_group_new=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03','04','05','06') THEN CRM_OPPORTUNITY_ID END) AS ai_group_new_open_s2_plus,
        COUNT(DISTINCT CASE WHEN is_ai_group_new=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('04','05','06') THEN CRM_OPPORTUNITY_ID END) AS ai_group_new_open_s4_plus,
        COUNT(DISTINCT CASE WHEN is_ai_group_new=1 AND OPPORTUNITY_STATUS='Closed' AND closedate >= DATEADD(day, -90, CURRENT_DATE()) THEN CRM_OPPORTUNITY_ID END) AS ai_group_new_closed_l90,

        -- ES
        COUNT(DISTINCT CASE WHEN is_es=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' THEN CRM_OPPORTUNITY_ID END) AS es_open_total,
        COUNT(DISTINCT CASE WHEN is_es=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03') THEN CRM_OPPORTUNITY_ID END) AS es_open_in_s2,
        COUNT(DISTINCT CASE WHEN is_es=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03','04','05','06') THEN CRM_OPPORTUNITY_ID END) AS es_open_s2_plus,
        COUNT(DISTINCT CASE WHEN is_es=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('04','05','06') THEN CRM_OPPORTUNITY_ID END) AS es_open_s4_plus,
        COUNT(DISTINCT CASE WHEN is_es=1 AND OPPORTUNITY_STATUS='Closed' AND closedate >= DATEADD(day, -90, CURRENT_DATE()) THEN CRM_OPPORTUNITY_ID END) AS es_closed_l90,

        -- CCaaS
        COUNT(DISTINCT CASE WHEN is_cc=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' THEN CRM_OPPORTUNITY_ID END) AS cc_open_total,
        COUNT(DISTINCT CASE WHEN is_cc=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03') THEN CRM_OPPORTUNITY_ID END) AS cc_open_in_s2,
        COUNT(DISTINCT CASE WHEN is_cc=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03','04','05','06') THEN CRM_OPPORTUNITY_ID END) AS cc_open_s2_plus,
        COUNT(DISTINCT CASE WHEN is_cc=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('04','05','06') THEN CRM_OPPORTUNITY_ID END) AS cc_open_s4_plus,
        COUNT(DISTINCT CASE WHEN is_cc=1 AND OPPORTUNITY_STATUS='Closed' AND closedate >= DATEADD(day, -90, CURRENT_DATE()) THEN CRM_OPPORTUNITY_ID END) AS cc_closed_l90,

        -- NB
        COUNT(DISTINCT CASE WHEN is_nb=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' THEN CRM_OPPORTUNITY_ID END) AS nb_open_total,
        COUNT(DISTINCT CASE WHEN is_nb=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03') THEN CRM_OPPORTUNITY_ID END) AS nb_open_in_s2,
        COUNT(DISTINCT CASE WHEN is_nb=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03','04','05','06') THEN CRM_OPPORTUNITY_ID END) AS nb_open_s2_plus,
        COUNT(DISTINCT CASE WHEN is_nb=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('04','05','06') THEN CRM_OPPORTUNITY_ID END) AS nb_open_s4_plus,
        COUNT(DISTINCT CASE WHEN is_nb=1 AND OPPORTUNITY_STATUS='Closed' AND closedate >= DATEADD(day, -90, CURRENT_DATE()) THEN CRM_OPPORTUNITY_ID END) AS nb_closed_l90,

        -- CS
        COUNT(DISTINCT CASE WHEN is_cs=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' THEN CRM_OPPORTUNITY_ID END) AS cs_open_total,
        COUNT(DISTINCT CASE WHEN is_cs=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03') THEN CRM_OPPORTUNITY_ID END) AS cs_open_in_s2,
        COUNT(DISTINCT CASE WHEN is_cs=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03','04','05','06') THEN CRM_OPPORTUNITY_ID END) AS cs_open_s2_plus,
        COUNT(DISTINCT CASE WHEN is_cs=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('04','05','06') THEN CRM_OPPORTUNITY_ID END) AS cs_open_s4_plus,
        COUNT(DISTINCT CASE WHEN is_cs=1 AND OPPORTUNITY_STATUS='Closed' AND closedate >= DATEADD(day, -90, CURRENT_DATE()) THEN CRM_OPPORTUNITY_ID END) AS cs_closed_l90,

        -- Partner Sourced
        COUNT(DISTINCT CASE WHEN is_partner_sourced=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' THEN CRM_OPPORTUNITY_ID END) AS ps_open_total,
        COUNT(DISTINCT CASE WHEN is_partner_sourced=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03') THEN CRM_OPPORTUNITY_ID END) AS ps_open_in_s2,
        COUNT(DISTINCT CASE WHEN is_partner_sourced=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03','04','05','06') THEN CRM_OPPORTUNITY_ID END) AS ps_open_s2_plus,
        COUNT(DISTINCT CASE WHEN is_partner_sourced=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('04','05','06') THEN CRM_OPPORTUNITY_ID END) AS ps_open_s4_plus,
        COUNT(DISTINCT CASE WHEN is_partner_sourced=1 AND OPPORTUNITY_STATUS='Closed' AND closedate >= DATEADD(day, -90, CURRENT_DATE()) THEN CRM_OPPORTUNITY_ID END) AS ps_closed_l90,

        -- Partner Influenced
        COUNT(DISTINCT CASE WHEN is_partner_influenced=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' THEN CRM_OPPORTUNITY_ID END) AS pi_open_total,
        COUNT(DISTINCT CASE WHEN is_partner_influenced=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03') THEN CRM_OPPORTUNITY_ID END) AS pi_open_in_s2,
        COUNT(DISTINCT CASE WHEN is_partner_influenced=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('02','03','04','05','06') THEN CRM_OPPORTUNITY_ID END) AS pi_open_s2_plus,
        COUNT(DISTINCT CASE WHEN is_partner_influenced=1 AND OPPORTUNITY_STATUS='Open' AND s2_date >= '2025-01-01' AND LEFT(stage_name, 2) IN ('04','05','06') THEN CRM_OPPORTUNITY_ID END) AS pi_open_s4_plus,
        COUNT(DISTINCT CASE WHEN is_partner_influenced=1 AND OPPORTUNITY_STATUS='Closed' AND closedate >= DATEADD(day, -90, CURRENT_DATE()) THEN CRM_OPPORTUNITY_ID END) AS pi_closed_l90

    FROM source_opps
    GROUP BY OWNERID
)

-- 6. Final Output with Boolean Flags (Threshold: 2+ Open S2+)
SELECT 
    s.DATA_AS_OF, -- <--- Displays the specific snapshot date

    r.AE_NAME,
    r.AE_REGION,
    r.AE_SEGMENT,

    -- AI
    COALESCE(s.ai_open_total, 0) AS "AI Open Total",
    COALESCE(s.ai_open_in_s2, 0) AS "AI Open IN S2",
    COALESCE(s.ai_open_s2_plus, 0) AS "AI Open S2+",
    COALESCE(s.ai_open_s4_plus, 0) AS "AI Open S4+",
    COALESCE(s.ai_closed_l90, 0) AS "AI Closed L90",
    CASE WHEN COALESCE(s.ai_open_total, 0) > 0 THEN 1 ELSE 0 END AS "Flag: AI Participated (Has 1+ open AI opp (any stage 2-6))",
    CASE WHEN COALESCE(s.ai_open_s2_plus, 0) > 0 THEN 1 ELSE 0 END AS "Flag: AI Participated (1+ Open S2+)",
    CASE WHEN COALESCE(s.ai_open_s2_plus, 0) > 1 THEN 1 ELSE 0 END AS "Flag: AI Participated (2+ Open S2+)",
    CASE WHEN COALESCE(s.ai_open_s4_plus, 0) > 0 THEN 1 ELSE 0 END AS "Flag: AI Participated (Has open AI opp in S4+)",
    CASE WHEN COALESCE(s.ai_closed_l90, 0) > 0 THEN 1 ELSE 0 END AS "Flag: AI Participated (1+ Closed L90d)",

    -- ES
    COALESCE(s.es_open_total, 0) AS "ES Open Total",
    COALESCE(s.es_open_in_s2, 0) AS "ES Open IN S2",
    COALESCE(s.es_open_s2_plus, 0) AS "ES Open S2+",
    COALESCE(s.es_open_s4_plus, 0) AS "ES Open S4+",
    COALESCE(s.es_closed_l90, 0) AS "ES Closed L90",
    CASE WHEN COALESCE(s.es_open_total, 0) > 0 THEN 1 ELSE 0 END AS "Flag: ES Participated (Has 1+ open ES opp (any stage 2-6))",
    CASE WHEN COALESCE(s.es_open_s2_plus, 0) > 0 THEN 1 ELSE 0 END AS "Flag: ES Participated (1+ Open S2+)",
    CASE WHEN COALESCE(s.es_open_s2_plus, 0) > 1 THEN 1 ELSE 0 END AS "Flag: ES Participated (2+ Open S2+)",
    CASE WHEN COALESCE(s.es_open_s4_plus, 0) > 0 THEN 1 ELSE 0 END AS "Flag: ES Participated (Has open ES opp in S4+)",
    CASE WHEN COALESCE(s.es_closed_l90, 0) > 0 THEN 1 ELSE 0 END AS "Flag: ES Participated (1+ Closed L90d)",

    -- CCaaS
    COALESCE(s.cc_open_total, 0) AS "CCaaS Open Total",
    COALESCE(s.cc_open_in_s2, 0) AS "CCaaS Open IN S2",
    COALESCE(s.cc_open_s2_plus, 0) AS "CCaaS Open S2+",
    COALESCE(s.cc_open_s4_plus, 0) AS "CCaaS Open S4+",
    COALESCE(s.cc_closed_l90, 0) AS "CCaaS Closed L90",
    CASE WHEN COALESCE(s.cc_open_total, 0) > 0 THEN 1 ELSE 0 END AS "Flag: CCaaS Participated (Has 1+ open CCaaS opp (any stage 2-6))",
    CASE WHEN COALESCE(s.cc_open_s2_plus, 0) > 0 THEN 1 ELSE 0 END AS "Flag: CCaaS Participated (1+ Open S2+)",
    CASE WHEN COALESCE(s.cc_open_s2_plus, 0) > 1 THEN 1 ELSE 0 END AS "Flag: CCaaS Participated (2+ Open S2+)",
    CASE WHEN COALESCE(s.cc_open_s4_plus, 0) > 0 THEN 1 ELSE 0 END AS "Flag: CCaaS Participated (Has open CCaaS opp in S4+)",
    CASE WHEN COALESCE(s.cc_closed_l90, 0) > 0 THEN 1 ELSE 0 END AS "Flag: CCaaS Participated (1+ Closed L90d)",

    -- NB
    COALESCE(s.nb_open_total, 0) AS "NB Open Total",
    COALESCE(s.nb_open_in_s2, 0) AS "NB Open IN S2",
    COALESCE(s.nb_open_s2_plus, 0) AS "NB Open S2+",
    COALESCE(s.nb_open_s4_plus, 0) AS "NB Open S4+",
    COALESCE(s.nb_closed_l90, 0) AS "NB Closed L90",
    CASE WHEN COALESCE(s.nb_open_total, 0) > 0 THEN 1 ELSE 0 END AS "Flag: NB Participated (Has 1+ open NB opp (any stage 2-6))",
    CASE WHEN COALESCE(s.nb_open_s2_plus, 0) > 0 THEN 1 ELSE 0 END AS "Flag: NB Participated (1+ Open S2+)",
    CASE WHEN COALESCE(s.nb_open_s2_plus, 0) > 1 THEN 1 ELSE 0 END AS "Flag: NB Participated (2+ Open S2+)",
    CASE WHEN COALESCE(s.nb_open_s4_plus, 0) > 0 THEN 1 ELSE 0 END AS "Flag: NB Participated (Has open NB opp in S4+)",
    CASE WHEN COALESCE(s.nb_closed_l90, 0) > 0 THEN 1 ELSE 0 END AS "Flag: NB Participated (1+ Closed L90d)",

    -- CS
    COALESCE(s.cs_open_total, 0) AS "CS Open Total",
    COALESCE(s.cs_open_in_s2, 0) AS "CS Open IN S2",
    COALESCE(s.cs_open_s2_plus, 0) AS "CS Open S2+",
    COALESCE(s.cs_open_s4_plus, 0) AS "CS Open S4+",
    COALESCE(s.cs_closed_l90, 0) AS "CS Closed L90",
    CASE WHEN COALESCE(s.cs_open_total, 0) > 0 THEN 1 ELSE 0 END AS "Flag: CS Participated (Has 1+ open CS opp (any stage 2-6))",
    CASE WHEN COALESCE(s.cs_open_s2_plus, 0) > 0 THEN 1 ELSE 0 END AS "Flag: CS Participated (1+ Open S2+)",
    CASE WHEN COALESCE(s.cs_open_s2_plus, 0) > 1 THEN 1 ELSE 0 END AS "Flag: CS Participated (2+ Open S2+)",
    CASE WHEN COALESCE(s.cs_open_s4_plus, 0) > 0 THEN 1 ELSE 0 END AS "Flag: CS Participated (Has open CS opp in S4+)",
    CASE WHEN COALESCE(s.cs_closed_l90, 0) > 0 THEN 1 ELSE 0 END AS "Flag: CS Participated (1+ Closed L90d)",

    -- Partner Sourced
    COALESCE(s.ps_open_total, 0) AS "P-Sourced Open Total",
    COALESCE(s.ps_open_in_s2, 0) AS "P-Sourced Open IN S2",
    COALESCE(s.ps_open_s2_plus, 0) AS "P-Sourced Open S2+",
    COALESCE(s.ps_open_s4_plus, 0) AS "P-Sourced Open S4+",
    COALESCE(s.ps_closed_l90, 0) AS "P-Sourced Closed L90",
    CASE WHEN COALESCE(s.ps_open_total, 0) > 0 THEN 1 ELSE 0 END AS "Flag: P-Sourced (Has 1+ open P-sourced opp (any stage 2-6))",
    CASE WHEN COALESCE(s.ps_open_s2_plus, 0) > 0 THEN 1 ELSE 0 END AS "Flag: P-Sourced (1+ Open S2+)",
    CASE WHEN COALESCE(s.ps_open_s2_plus, 0) > 1 THEN 1 ELSE 0 END AS "Flag: P-Sourced (2+ Open S2+)",
    CASE WHEN COALESCE(s.ps_open_s4_plus, 0) > 0 THEN 1 ELSE 0 END AS "Flag: P-Sourced (Has open P-sourced opp in S4+)",
    CASE WHEN COALESCE(s.ps_closed_l90, 0) > 0 THEN 1 ELSE 0 END AS "Flag: P-Sourced (1+ Closed L90d)",

    -- Partner Influenced
    COALESCE(s.pi_open_total, 0) AS "P-Influenced Open Total",
    COALESCE(s.pi_open_in_s2, 0) AS "P-Influenced Open IN S2",
    COALESCE(s.pi_open_s2_plus, 0) AS "P-Influenced Open S2+",
    COALESCE(s.pi_open_s4_plus, 0) AS "P-Influenced Open S4+",
    COALESCE(s.pi_closed_l90, 0) AS "P-Influenced Closed L90",
    CASE WHEN COALESCE(s.pi_open_total, 0) > 0 THEN 1 ELSE 0 END AS "Flag: P-Influenced (Has 1+ open P-Influenced opp (any stage 2-6))",
    CASE WHEN COALESCE(s.pi_open_s2_plus, 0) > 0 THEN 1 ELSE 0 END AS "Flag: P-Influenced (1+ Open S2+)",
    CASE WHEN COALESCE(s.pi_open_s2_plus, 0) > 1 THEN 1 ELSE 0 END AS "Flag: P-Influenced (2+ Open S2+)",
    CASE WHEN COALESCE(s.pi_open_s4_plus, 0) > 0 THEN 1 ELSE 0 END AS "Flag: P-Influenced (Has open P-Influenced opp in S4+)",
    CASE WHEN COALESCE(s.pi_closed_l90, 0) > 0 THEN 1 ELSE 0 END AS "Flag: P-Influenced (1+ Closed L90d)",

    -- MORE AI (Agent, Copilot, QA, etc.)
    COALESCE(s.ai_agent_open_total, 0) AS "AI Agent Open Total",
    COALESCE(s.ai_agent_open_in_s2, 0) AS "AI Agent Open IN S2",
    COALESCE(s.ai_agent_open_s2_plus, 0) AS "AI Agent Open S2+",
    COALESCE(s.ai_agent_open_s4_plus, 0) AS "AI Agent Open S4+",
    COALESCE(s.ai_agent_closed_l90, 0) AS "AI Agent Closed L90",
    CASE WHEN COALESCE(s.ai_agent_open_total, 0) > 0 THEN 1 ELSE 0 END AS "Flag: AI Agent Participated",
    
    COALESCE(s.ai_copilot_open_total, 0) AS "AI Copilot Open Total",
    COALESCE(s.ai_copilot_open_in_s2, 0) AS "AI Copilot Open IN S2",
    COALESCE(s.ai_copilot_open_s2_plus, 0) AS "AI Copilot Open S2+",
    COALESCE(s.ai_copilot_open_s4_plus, 0) AS "AI Copilot Open S4+",
    COALESCE(s.ai_copilot_closed_l90, 0) AS "AI Copilot Closed L90",
    CASE WHEN COALESCE(s.ai_copilot_open_total, 0) > 0 THEN 1 ELSE 0 END AS "Flag: AI Copilot Participated",

    COALESCE(s.qa_open_total, 0) AS "QA Open Total",
    COALESCE(s.qa_open_in_s2, 0) AS "QA Open IN S2",
    COALESCE(s.qa_open_s2_plus, 0) AS "QA Open S2+",
    COALESCE(s.qa_open_s4_plus, 0) AS "QA Open S4+",
    COALESCE(s.qa_closed_l90, 0) AS "QA Closed L90",
    CASE WHEN COALESCE(s.qa_open_total, 0) > 0 THEN 1 ELSE 0 END AS "Flag: QA Participated",

    COALESCE(s.wem_open_total, 0) AS "WEM Open Total",
    COALESCE(s.wem_open_in_s2, 0) AS "WEM Open IN S2",
    COALESCE(s.wem_open_s2_plus, 0) AS "WEM Open S2+",
    COALESCE(s.wem_open_s4_plus, 0) AS "WEM Open S4+",
    COALESCE(s.wem_closed_l90, 0) AS "WEM Closed L90",
    CASE WHEN COALESCE(s.wem_open_total, 0) > 0 THEN 1 ELSE 0 END AS "Flag: WEM Participated",

    COALESCE(s.ai_expert_open_total, 0) AS "AI Expert Open Total",
    COALESCE(s.ai_expert_open_in_s2, 0) AS "AI Expert Open IN S2",
    COALESCE(s.ai_expert_open_s2_plus, 0) AS "AI Expert Open S2+",
    COALESCE(s.ai_expert_open_s4_plus, 0) AS "AI Expert Open S4+",
    COALESCE(s.ai_expert_closed_l90, 0) AS "AI Expert Closed L90",
    CASE WHEN COALESCE(s.ai_expert_open_total, 0) > 0 THEN 1 ELSE 0 END AS "Flag: AI Expert Participated",

    COALESCE(s.ai_group_new_open_total, 0) AS "AI Group New Open Total",
    COALESCE(s.ai_group_new_open_in_s2, 0) AS "AI Group New Open IN S2",
    COALESCE(s.ai_group_new_open_s2_plus, 0) AS "AI Group New Open S2+",
    COALESCE(s.ai_group_new_open_s4_plus, 0) AS "AI Group New Open S4+",
    COALESCE(s.ai_group_new_closed_l90, 0) AS "AI Group New Closed L90",
    CASE WHEN COALESCE(s.ai_group_new_open_total, 0) > 0 THEN 1 ELSE 0 END AS "Flag: AI Group New Participated"

FROM roster r
LEFT JOIN ae_aggregates s ON r.AE_ID = s.OWNERID
ORDER BY 1;
