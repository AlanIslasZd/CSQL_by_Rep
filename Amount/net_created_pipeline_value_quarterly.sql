SELECT
    TO_CHAR(b.STAGE_2_PLUS_DATE_C, 'YYYY') || '-Q' || DATE_PART(QUARTER, b.STAGE_2_PLUS_DATE_C) AS created_quarter,
    SUM(a.product_arr_usd / 1000) AS product_arr_usd_k
FROM
    functional.gtm_sales_ops.gtmsi_consolidated_pipeline_bookings a
INNER JOIN
    cleansed.salesforce.salesforce_opportunity_bcv b
    ON a.crm_opportunity_id = b.id
WHERE
    a.date_label = 'today'
    AND b.STAGE_2_PLUS_DATE_C BETWEEN '2025-01-01' AND '2025-12-31'
    AND a.PRO_FORMA_MARKET_SEGMENT NOT IN ('Digital','SMB')
    AND b.campaign_id = '70180000001JlouAAC'
    AND a.product = 'Total Booking' 
    AND b.is_deleted = false
    and closedate >= '2025-01-01'
    AND a.product_arr_usd > 0 
    and a.opportunity_is_commissionable = true
    AND a.STAGE_NAME IN (
        '08 - Closed',
        '02 - Confirm Need',
        '03 - Establish Value', 
        '04 - Demonstrate Value',
        '05 - Secure Commitment',
        '06 - Contracting',
        '07 - Signed',
        'Lost'
    )
GROUP BY 
    1
ORDER BY 
    1;
