Exploring Claude to Get started with understanding the problem [applying Consulting Fundamentals Principles](https://chatgpt-libre.zende.sk/c/a2ffe569-5896-4e25-ab36-ff43dd8a6633)

# Digital [CSQL Attribution Query](https://chatgpt-libre.zende.sk/c/a2ffe569-5896-4e25-ab36-ff43dd8a6633)

## Stakeholders
- Chris and Jim

## Follow up Meetings
- [Kick off](https://docs.google.com/document/d/15KLoo9P49FoDgwnLQf1RNSuzYYEHYGyPxoZ6v9XGD44/edit?tab=t.0)

## Main Analysis
- [Velocity Analysis](https://app.snowflake.com/zendesk/global/?loginAfterSessionExpired=true#/notebooks/_SANDBOX_WORKING_CAPITAL.PUBLIC.CSQLS_VELOCITY_ANALYSIS)

## Colab Analysis
- [Sankey Stage Journey Analysis](https://colab.research.google.com/drive/1spzikzYazNr6RYFu6KComgD_r0xDNigf?usp=sharing)

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
- [CSQLs Britney/ Marco](https://docs.google.com/spreadsheets/d/1atTd89PkanTDWFTIbh0hBdIHBeEEjowabn3ENHrFCa0/edit?usp=sharing)
- [Laura Lucid Diagam](https://lucid.app/lucidchart/eb1a43f5-5799-4d56-9413-293209ea22fa/edit?viewport_loc=-279%2C-580%2C4408%2C3229%2C0_0&invitationId=inv_cc702ca9-ca02-4ffb-9da1-0a08e22dd9d1)
- [Laura's Request](https://zendesk.slack.com/archives/C0A2VT080M7/p1764093866566429)
- [NA Transformation Metrics Tracker](https://docs.google.com/spreadsheets/d/1AcpZjuqe8eIbjLQBrTPr1xl47cbmunUWd-n7GsGbgmE/edit?usp=sharing)
- [Mock up Presentation 1](https://docs.google.com/presentation/d/1-vkp4ij9zHWd0o34Kr_5UteZvlAHR-fNHxmYv_q1y-I/edit?slide=id.p5#slide=id.p5)


#### Message sent to Britney on Dec 18 2025
- [Drilling down into Opps that have been idle for 90d+](https://docs.google.com/spreadsheets/d/1AOMV7lLRRIiGMeOpDmNG89_29WzSgnpdneOavHDYusU/edit?gid=1573233927#gid=1573233927)

