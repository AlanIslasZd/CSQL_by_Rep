WITH roster AS (
    SELECT DISTINCT
        usr.id AS AE_ID,
        usr.name AS AE_NAME,
        /* Note: format comment adjusted to match value */
        CONCAT(
            TO_VARCHAR(EXTRACT(YEAR FROM CAST(usr.created_date AS DATE))),
            'Q',
            TO_VARCHAR(EXTRACT(QUARTER FROM CAST(usr.created_date AS DATE)))
        ) AS AE_USR_CREATED,
        CASE WHEN usr.created_date < CURRENT_DATE() - 90 THEN 0 ELSE 1 END AS less_than_90_days,
        CASE WHEN LOWER(role.name) LIKE ('%cae%') THEN 0 ELSE 1 END AS nb_qualifying,
        mgr.name AS MANAGER_NAME,
        role.name AS USER_ROLE,
        usr.mgr_team_c AS MGR_TEAM,
        usr.dir_team_c AS DIR_TEAM,
        usr.market_segment_c AS SEGMENT,
        usr.vp_team_c AS VP_TEAM,
        CASE
            WHEN usr.market_segment_c IN ('SMB') THEN 'Adrian Fallow'
            WHEN usr.market_segment_c NOT IN ('SMB','Digital') AND usr.vp_team_c IN ('AMER') THEN 'Jim Priestley'
            WHEN usr.market_segment_c NOT IN ('SMB','Digital') AND usr.vp_team_c IN ('EMEA') THEN 'Andy Lawson'
            WHEN usr.market_segment_c NOT IN ('SMB','Digital') AND usr.vp_team_c IN ('LATAM') THEN 'Eduardo Lugo'
            WHEN usr.market_segment_c NOT IN ('SMB','Digital') AND usr.vp_team_c IN ('APAC') THEN 'Mitch Young'
            ELSE 'Megan Lew'
        END AS SVP
    FROM CLEANSED.SALESFORCE.SALESFORCE_USER_SCD2 AS usr
    INNER JOIN CLEANSED.SALESFORCE.SALESFORCE_USER_TERRITORY_2_ASSOCIATION_SCD2 AS assoc
        ON usr.id = assoc.user_id
       AND assoc.valid_to_timestamp = '9999-12-31'
       AND assoc.role_in_territory_2 IN ('Account Executive', 'Account Executive - Coverage')
    LEFT JOIN CLEANSED.SALESFORCE.SALESFORCE_USER_SCD2 AS mgr
        ON usr.manager_id = mgr.id
       AND mgr.valid_to_timestamp = '9999-12-31'
    LEFT JOIN CLEANSED.SALESFORCE.SALESFORCE_USER_ROLE_SCD2 AS role
        ON usr.user_role_id = role.id
       AND role.valid_to_timestamp = '9999-12-31'
    LEFT JOIN CLEANSED.SALESFORCE.SALESFORCE_TERRITORY_2_SCD2 AS terr
        ON assoc.territory_2_id = terr.id
       AND terr.valid_to_timestamp = '9999-12-31'
    LEFT JOIN CLEANSED.SALESFORCE.SALESFORCE_TERRITORY_2_MODEL_SCD2 AS model
        ON terr.territory_2_model_id = model.id
       AND model.valid_to_timestamp = '9999-12-31'
    WHERE usr.valid_to_timestamp = '9999-12-31'
      AND usr.is_active = TRUE
      AND model.name = 'FY 2025 GTM Territories'
      AND LOWER(usr.name) NOT LIKE ('%belarus%')
),
created_opps AS (
    SELECT
        o.OWNERID,
        o.CRM_OPPORTUNITY_ID,
        o.TYPE,
        o.PRODUCT,
        o.product_arr_usd,
        o.stage_name,
        o.OPPORTUNITY_STATUS,
        o.closedate,
        to_char(o.stage_2_plus_date_c, 'YYYY') || '-Q' || date_part(quarter, o.stage_2_plus_date_c) as stage_2_plus_date_year_quarter
      
    FROM FUNCTIONAL.GTM_SALES_OPS.GTMSI_CONSOLIDATED_PIPELINE_BOOKINGS o
    WHERE o.DATE_LABEL = 'today'
      
      --AND o.OPPORTUNITY_STATUS = 'Open'
      
      AND o.stage_2_plus_date_c >= '2025-07-01' and  o.stage_2_plus_date_c <= current_date()-1
      AND o.CLOSEDATE < '2027-01-01'
        and (product_arr_usd > 0 or product_booking_arr_usd > 0)
        and opportunity_is_commissionable = 'TRUE'
        and stage_2_plus_date_c is not null
        and region = 'NA'
        and pro_forma_market_segment not in ('Digital', 'SMB') 
        ) ,

agg AS (
    SELECT
        OWNERID,
        /* single pass conditional aggregates */
        
        --CCaaS counts
        COUNT(DISTINCT CASE WHEN PRODUCT IN ('Contact_Center') AND product_arr_usd > 0 AND opportunity_status='Open' THEN CRM_OPPORTUNITY_ID END) AS cc_deals,
        COUNT(DISTINCT CASE WHEN PRODUCT IN ('Contact_Center') AND product_arr_usd > 0  AND left(stage_name, 2)  in ('02', '03', '04', '05', '06', '07', '08') AND opportunity_status='Open' THEN CRM_OPPORTUNITY_ID END) AS cc_stg_2_plus_deals,
        COUNT(DISTINCT CASE WHEN PRODUCT IN ('Contact_Center') AND product_arr_usd > 0 AND left(stage_name, 2)  in ('04', '05', '06', '07', '08')  AND opportunity_status='Open' THEN CRM_OPPORTUNITY_ID END) AS cc_stg_4_plus_deals,     

        --AI counts
        COUNT(DISTINCT CASE WHEN PRODUCT IN ('Copilot','Ultimate_AR','AR','Zendesk_AR','Generative_Search','Ultimate','AI_Expert') AND product_arr_usd > 0  AND opportunity_status='Open'  THEN CRM_OPPORTUNITY_ID END) AS ai_deals,
        COUNT(DISTINCT CASE WHEN PRODUCT = 'Copilot' AND product_arr_usd > 0  AND opportunity_status='Open'  THEN CRM_OPPORTUNITY_ID END) AS ai_copilot_deals,
        COUNT(DISTINCT CASE WHEN PRODUCT IN ('Ultimate_AR','Zendesk_AR','Ultimate','AR') AND product_arr_usd > 0 AND opportunity_status='Open' THEN CRM_OPPORTUNITY_ID END) AS ai_agent_deals,
        
        COUNT(DISTINCT CASE WHEN PRODUCT = 'Copilot' AND product_arr_usd > 0  AND left(stage_name, 2) in ('02', '03', '04', '05', '06', '07', '08') AND opportunity_status='Open' THEN CRM_OPPORTUNITY_ID END) AS ai_copilot_stg_2_plus_deals,
        COUNT(DISTINCT CASE WHEN PRODUCT = 'Copilot' AND product_arr_usd > 0 AND left(stage_name, 2) in ('04', '05', '06', '07', '08') AND opportunity_status='Open' THEN CRM_OPPORTUNITY_ID END) AS ai_copilot_stg_4_plus_deals,   
        COUNT(DISTINCT CASE WHEN PRODUCT IN ('Ultimate_AR','Zendesk_AR','Ultimate','AR') AND product_arr_usd > 0  AND left(stage_name, 2)  in ('02', '03', '04', '05', '06', '07', '08') AND opportunity_status='Open' THEN CRM_OPPORTUNITY_ID END) AS ai_agent_stg_2_plus_deals,
        COUNT(DISTINCT CASE WHEN PRODUCT IN ('Ultimate_AR','Zendesk_AR','Ultimate','AR') AND product_arr_usd > 0 AND left(stage_name, 2)  in ('04', '05', '06', '07', '08') AND opportunity_status='Open' THEN CRM_OPPORTUNITY_ID END) AS ai_agent_stg_4_plus_deals,   


        --ES Counts
        COUNT(DISTINCT CASE WHEN PRODUCT IN ('ES') AND product_arr_usd > 0 AND opportunity_status='Open' THEN CRM_OPPORTUNITY_ID END) AS es_deals,
        COUNT(DISTINCT CASE WHEN PRODUCT IN ('ES') AND product_arr_usd > 0  AND left(stage_name, 2)  in ('02', '03', '04', '05', '06', '07', '08') AND opportunity_status='Open' THEN CRM_OPPORTUNITY_ID END) AS es_stg_2_plus_deals,
        COUNT(DISTINCT CASE WHEN PRODUCT IN ('ES') AND product_arr_usd > 0 AND left(stage_name, 2)  in ('04', '05', '06', '07', '08') AND opportunity_status='Open' THEN CRM_OPPORTUNITY_ID END) AS es_stg_4_plus_deals,    

        COUNT(DISTINCT CASE WHEN PRODUCT IN ('ES') AND product_arr_usd > 0 AND opportunity_status='Closed' AND closedate between current_date()-91 and current_date() THEN CRM_OPPORTUNITY_ID END) AS es__closed_deals,


        --New Business counts
        COUNT(DISTINCT CASE WHEN TYPE = 'New Business' AND product_arr_usd > 0 AND opportunity_status='Open' THEN CRM_OPPORTUNITY_ID END) AS nb_deals,
        COUNT(DISTINCT CASE WHEN TYPE = 'New Business' AND product_arr_usd > 0  AND left(stage_name, 2)  in ('02', '03', '04', '05', '06', '07', '08') AND opportunity_status='Open' THEN CRM_OPPORTUNITY_ID END) AS nb_stg_2_plus_deals,
        COUNT(DISTINCT CASE WHEN TYPE = 'New Business' AND product_arr_usd > 0 AND left(stage_name, 2)  in ('04', '05', '06', '07', '08') AND opportunity_status='Open' THEN CRM_OPPORTUNITY_ID END) AS nb_stg_4_plus_deals     

        --CS Counts TBD
  --      COUNT(DISTINCT CASE WHEN left(stage_name, 2)  in ('02', '03', '04', '05', '06', '07', '08') THEN CRM_OPPORTUNITY_ID END) AS stg_2_plus_deals,
  --      COUNT(DISTINCT CASE WHEN left(stage_name, 2)  in ('04', '05', '06', '07', '08') THEN CRM_OPPORTUNITY_ID END) AS stg_4_plus_deals     
        
    FROM created_opps
    GROUP BY OWNERID
)
SELECT
    r.AE_NAME,
    co.crm_opportunity_id,
    --co.stage_2_plus_date_year_quarter,
    --denominators
    --count(AE_ID) as ae_cnt,
    COALESCE(a.cc_deals, 0)        AS CC_DEALS_OPEN,
    COALESCE(a.es_deals, 0)        AS ES_DEALS_OPEN,
    COALESCE(a.ai_deals, 0)        AS AI_DEALS_OPEN,
    COALESCE(a.es__closed_deals, 0)        AS ES_DEALS_CLOSED,

    
    --numerators
    COALESCE(a.cc_stg_2_plus_deals, 0) AS CC_S2_flag,
    COALESCE(a.cc_stg_4_plus_deals, 0)  AS CC_S4_flag,
    COALESCE(a.es_stg_2_plus_deals, 0) AS ES_S2_flag,
    COALESCE(a.es_stg_4_plus_deals, 0) AS ES_S4_flag,
    
    CASE WHEN COALESCE(a.ai_copilot_deals, 0) >1 AND COALESCE(a.ai_agent_deals, 0) >1 THEN 1 ELSE 0 END AS AI_Flag,
    CASE WHEN COALESCE(a.ai_copilot_stg_2_plus_deals, 0) >1 AND COALESCE(a.ai_agent_stg_2_plus_deals, 0) THEN 1 ELSE 0 END AS AI_S2_Flag,
    CASE WHEN COALESCE(a.ai_copilot_stg_4_plus_deals, 0) >1 AND COALESCE(a.ai_agent_stg_4_plus_deals, 0) THEN 1 ELSE 0 END AS AI_S4_Flag,
    
    

FROM roster r
LEFT JOIN agg a
  ON a.OWNERID = r.AE_ID
LEFT JOIN created_opps co ON co.ownerid=r.ae_id

WHERE r.SEGMENT not in ('SMB', 'Digital') 
    AND r.VP_TEAM ='AMER'
-- LEFT JOIN agg a
--   ON a.OWNERID = r.ownerid
and ae_name='Jess Rivera'
group by all
