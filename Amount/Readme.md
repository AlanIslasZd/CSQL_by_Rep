# Revenue Data Discrepancy Investigation

**Ticket:** [CECE-2617](https://zendesk.atlassian.net/browse/CECE-2617) - Add CSQLs potential value to Business Health Dashboard  
**Sprint Status:** Blocked / In Progress

## Context
The goal of this ticket was to incorporate CSQL potential value into the Business Health Dashboard. During the validation process, a discrepancy was identified between the raw Salesforce data (`salesforce_opportunity_bcv`) and the consolidated pipeline data (`gtmsi_consolidated_pipeline_bookings`) used by GTM Sales Ops (Marco's source of truth).

## The Issue
When attempting to pull "Amount" or "Expected Revenue" directly from Salesforce to calculate potential value, the numbers did not align with the "Product ARR" or "Booking ARR" values found in the GTM consolidated tables.

### Investigation Example
Using Opportunity ID: `006PC000009ChdVYAS`

1.  **Salesforce Raw Data:**
    * The raw `amount` in Salesforce is recorded as **$222.6k**.
    * Query used: `salesforce_amount_check.sql`

2.  **GTM Consolidated Data (Marco's Source):**
    * The `functional.gtm_sales_ops.gtmsi_consolidated_pipeline_bookings` table breaks this down differently into `product_arr_usd` and `product_booking_arr_usd` splits.
    * The values here do not immediately sum or match the raw Salesforce amount in a straightforward way for dashboarding purposes.
    * Query used: `gtm_bookings_check.sql`

## Conclusion & Next Steps
To ensure the Business Health Dashboard reflects accurate metrics that align with Global Metrics, we cannot simply use the raw Salesforce `amount`.

* **Action:** Need to inquire with Marco regarding the logic used to derive his numbers or investigate the DBT lineage for `gtmsi_consolidated_pipeline_bookings`.
* **Result:** Ticket CECE-2617 remains open pending data alignment.
