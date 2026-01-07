SELECT
    a.crm_opportunity_id,
    a.product,
    CAST(ROUND(a.product_arr_usd, -2) / 1000 AS INT) AS product_arr_usd_k,
    CAST(ROUND(a.product_booking_arr_usd, -2) / 1000 AS INT) AS product_booking_arr_usd_k
FROM
    functional.gtm_sales_ops.gtmsi_consolidated_pipeline_bookings a
INNER JOIN
    cleansed.salesforce.salesforce_opportunity_bcv b
    ON a.crm_opportunity_id = b.id
WHERE
    a.date_label = 'today'
    AND a.closedate BETWEEN '2025-10-01' AND '2025-10-31'
    AND a.opportunity_status = 'Closed'
    AND a.product_booking_arr_usd > 0
    AND b.campaign_id = '70180000001JlouAAC'
    AND a.crm_opportunity_id = '006PC000009ChdVYAS'
ORDER BY 
    1;
