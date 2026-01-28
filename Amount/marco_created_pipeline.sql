with

csql_opps as (
select distinct
    opp.campaign_id,
    camp.name as campaign_name,
    opp.id as crm_opportunity_id,
from 
    cleansed.salesforce.salesforce_opportunity_bcv opp
left join
    cleansed.salesforce.salesforce_campaign_bcv camp
    on (opp.campaign_id = camp.id
        and camp.is_deleted = false)
where
    opp.campaign_id = '70180000001JlouAAC'
    and opp.is_deleted = false
    )

, account_arr_flag as (
select distinct
	crm_account_id,
	coalesce(round(crm_net_arr_usd,2) > 0 and round(crm_net_arr_usd,2) < 100000, false) as under_100k
from
    foundational.finance.fact_qtd_crm_finance_adjusted_daily_snapshot_enriched
where 
    is_most_recent = true
	and crm_net_arr_usd > 0
	and crm_account_id not like 'Zuora%'
)

, csql_consolidated as (
select distinct
    close_year_quarter,
    stage_2_plus_calendar_quarter,
    region,
    pro_forma_market_segment as segment,
    gtm_team,
    cns.crm_account_id,
    is_top3k_account,
    coalesce(aaf.under_100k,false) as account_under_100k_arr,
    crm_opportunity_id,
    opportunity_type,
    opportunity_status,
    opportunity_is_commissionable,
    stage_name,
    deal_lost_reasonmulti__c,
    stage_2_plus_date_c,
    closedate,
    product,
    product_arr_usd,
    product_booking_arr_usd
from
    functional.gtm_sales_ops.gtmsi_consolidated_pipeline_bookings cns
left join
    account_arr_flag aaf
    on (cns.crm_account_id = aaf.crm_account_id)
where
    date_label = 'today'
    and closedate >= '2024-01-01'
    and product not like '%Allocated%'
    and product not in ('Ultimate_AR', 'Zendesk_AR')
    and (product_arr_usd > 0 or product_booking_arr_usd >  0)
    and crm_opportunity_id in (select distinct crm_opportunity_id from csql_opps)
)

, main as (
select distinct
    region,
    segment,
    stage_2_plus_calendar_quarter,
    crm_account_id,
    is_top3k_account,
    account_under_100k_arr,
    crm_opportunity_id,
    opportunity_type,
    stage_name,
    stage_2_plus_date_c,
    closedate,
    product,
    product_arr_usd
from
    csql_consolidated
where
    product_arr_usd > 0
    and stage_2_plus_date_c is not null
    and opportunity_is_commissionable = true
    and stage_name not in ('00 - Prospect & Plan','01 - Qualify Need')
)


select * from main
