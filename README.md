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
