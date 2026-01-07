SELECT
    id,
    amount,
    expected_revenue,
    currency_iso_code
FROM
    cleansed.salesforce.salesforce_opportunity_bcv
WHERE
    id = '006PC000009ChdVYAS';
