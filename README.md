Exploring Claude to Get started with understanding the problem [applying Consulting Fundamentals Principles](https://chatgpt-libre.zende.sk/c/a2ffe569-5896-4e25-ab36-ff43dd8a6633)

# Digital [CSQL Attribution Query](https://chatgpt-libre.zende.sk/c/a2ffe569-5896-4e25-ab36-ff43dd8a6633)

## Context
Analysis for Digital Customer Success team pipeline targets.
Answers: "How many CSQLs per CSM per month?"

## Key Finding
**Digital segment does NOT use campaign ID `70180000001JlouAAC`** (used by 
Commercial/Enterprise/SMB segments only). Instead, CSQLs are identified by:
- Owned by active Digital CSM
- Stage 2+ (excludes Prospect & Qualify stages)
- Created in analysis period

## CSQL Definition for Digital
- **Ownership:** INNER JOIN to active Digital CSM roster
- **Stage:** NOT IN ('00 Prospect & Plan', '01 Qualify Need', 'Omitted')
- **Attribution:** No campaign filter needed (unlike other segments)

## Usage
```sql
-- Adjust date range as needed:
AND s.CREATED_DATE >= '2024-07-01'
AND s.CREATED_DATE < '2025-01-01'
```
### Source
[CSQLs Britney/ Marco](https://docs.google.com/spreadsheets/d/1atTd89PkanTDWFTIbh0hBdIHBeEEjowabn3ENHrFCa0/edit?usp=sharing)
[Laura Lucid Diagam](https://lucid.app/lucidchart/eb1a43f5-5799-4d56-9413-293209ea22fa/edit?viewport_loc=-279%2C-580%2C4408%2C3229%2C0_0&invitationId=inv_cc702ca9-ca02-4ffb-9da1-0a08e22dd9d1)
[Laura's Request](https://zendesk.slack.com/archives/C0A2VT080M7/p1764093866566429)
