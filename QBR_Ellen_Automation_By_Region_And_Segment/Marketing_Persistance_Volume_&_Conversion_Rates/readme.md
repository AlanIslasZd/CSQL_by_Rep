
The process involved extracting raw data from regional/segment images via OCR, transforming metrics (merging events, calculating conversion rates), and cleaning the final dataset for analysis.

1. Data Extraction (OCR)
Raw data was sourced from static reporting images.

Method: Optical Character Recognition (OCR) was applied to one image per Region and Segment.

Output: Structured text data containing marketing metrics for each specific segment (e.g., APAC Ent/Comm, Global Digital, etc.).

2. Feature Engineering & Transformations
Once the raw data was digitized, several transformations were applied to standardize the metrics:

Merged Events: Combined disparate event categories into a single consolidated "Events" metric.

Core vs. Non-Core: Added segmentation for Persistence metrics to distinguish between Core and Non-Core business lines.

Conversion Rates: Calculated specific funnel metrics, specifically MQL to S2 Conversion Rates.

Opportunity Volume: Enriched the dataset by adding the Volume of Opportunities.

Source [Gemini_Chat](https://gemini.google.com/app/269ece97c814c781)
