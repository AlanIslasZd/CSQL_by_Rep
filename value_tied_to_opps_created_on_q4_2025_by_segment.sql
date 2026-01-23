with csql_opps as (
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
    and date(opp.created_date) between '2025-10-01' and '2025-12-31'
    )
SELECT 
pro_forma_market_segment,
sum(product_arr_usd)
from
    functional.gtm_sales_ops.gtmsi_consolidated_pipeline_bookings cns
where
    date_label = 'today'
    and closedate >= '2025-10-01'
    and product not like '%Allocated%'
    and product not in ('Ultimate_AR', 'Zendesk_AR')
    and (product_arr_usd > 0 or product_booking_arr_usd >  0)
    and crm_opportunity_id in (select distinct crm_opportunity_id from csql_opps)
    and stage_name != 'Lost'
    and product = 'Total Booking'
--and pro_forma_market_segment != 'Digital'
Group by 1    
    
