# Architecture — YouTube Trending Data Pipeline

## Overview

An end-to-end YouTube Trending Data Pipeline built using AWS services and the Medallion Architecture.

The pipeline processes YouTube trending data from multiple sources and organizes it into three logical layers:

```text
Data Sources
     |
     v
+------------------+
|  BRONZE LAYER    |
|  Raw Data        |
+------------------+
     |
     v
+------------------+
|  SILVER LAYER    |
|  Clean Parquet   |
+------------------+
     |
     v
+------------------+
|  DATA QUALITY    |
|  Lambda + Athena |
+------------------+
     |
     v
+------------------+
|   GOLD LAYER     |
| Analytics Tables |
+------------------+
     |
     v
+------------------+
|     ATHENA       |
| SQL Analytics    |
+------------------+


1. Data Sources

The pipeline works with multiple YouTube-related data sources.

Historical YouTube Trending Data

Kaggle datasets provide historical trending-video data in CSV format.

Examples include regional datasets such as:

CA
DE
FR
GB
IN
JP
KR
MX
RU
US

YouTube API Data

Additional data is collected from the YouTube API and stored as JSON before being processed.

Reference Data

YouTube category reference data is also stored separately and can be used to associate category IDs with category information.

2. Bronze Layer — Raw Storage

The Bronze layer is the raw-data landing layer.

Its purpose is to preserve incoming data before analytical transformations.

The Bronze layer contains:

Raw CSV
Raw JSON
API output
Reference data

The raw files are stored in Amazon S3.

Example logical structure:

Bronze S3
│
├── raw_statistics/
│   ├── region=ca/
│   ├── region=de/
│   ├── region=fr/
│   ├── region=gb/
│   ├── region=in/
│   ├── region=jp/
│   ├── region=kr/
│   ├── region=mx/
│   ├── region=ru/
│   └── region=us/
│
├── raw_statistics_reference_data/
│
├── reference_data/
│
├── trending_csv/
├── trending_json/
└── youtube_api/

The Bronze layer is treated as the source-of-record layer.

Raw data is not modified during ingestion.

3. Silver Layer — Clean and Standardized Data

The Silver layer contains analytics-ready Parquet data.

The purpose of this layer is to create a consistent schema from the different source formats.

The project converts the relevant incoming datasets into Parquet.

The main Silver datasets include:

trending_silver_csv
trending_silver_json
youtube_api

A unified logical dataset is then exposed through:

trending_silver_unified

Silver Unified Schema

The current unified Silver schema contains:

video_id
title
channel_title
category_id
view_count
region
source_format

source_format identifies the origin of the record:

csv
json
api

This allows data from different sources to be queried through one logical dataset.

4. Data Quality Layer

After the Silver data is available, a Lambda function performs data-quality validation.

The validation Lambda uses:

AWS Lambda
     |
     v
Amazon Athena
     |
     v
Silver dataset

The Lambda does not use awswrangler.

The final implementation uses:

boto3
pandas
Athena
Data Quality Checks

The validation process checks:

1. Row Count

Verifies that the Silver dataset contains the minimum expected number of records.

2. Schema

Checks that required columns exist.

Expected columns include:

video_id
title
channel_title
category_id
view_count
like_count
comment_count
published_at
duration
region
source_format
3. NULL Values

Critical fields are checked for excessive NULL values.

Important fields include:

video_id
title
region
4. Value Range

The pipeline checks for invalid numeric values such as:

view_count < 0
5. Source Coverage

The validation checks whether expected source types are represented:

csv
json
api
5. Duplicate Data Handling

Repeated video_id values are investigated but are not automatically treated as errors.

The current Silver schema does not contain a reliable trending-date field that would allow every repeated video ID to be classified as an invalid duplicate.

Therefore:

Repeated video ID
       |
       v
Investigate
       |
       v
Do not automatically delete

The project preserves the observations rather than silently removing them.

Validation SQL is provided in:

athena/validation_queries.sql
6. Gold Layer — Analytics

The Gold layer contains business-oriented analytical datasets.

The final Gold layer contains three logical tables:

trending_analytics
channel_analytics
category_analytics

These tables aggregate the Silver data for analytical queries.

7. Gold Transformation

AWS Glue ETL was originally planned for the Silver-to-Gold transformation.

However, Glue ETL access was restricted in the AWS account.

Therefore, the final implementation uses:

Silver
  |
  v
Amazon Athena SQL
  |
  v
CTAS
  |
  v
Gold Parquet

CTAS means:

CREATE TABLE AS SELECT

Athena performs the aggregation and writes the resulting datasets as Parquet files to the Gold S3 bucket.

The Gold SQL implementation is stored in:

athena/create_gold_tables.sql
8. Gold Table — trending_analytics

This table provides regional summary metrics.

Important metrics include:

total_rows
unique_videos
total_views
total_likes
total_comments
avg_views_per_row
max_views
unique_channels
unique_categories
region

This table can answer questions such as:

Which region has the most views?

How many videos are represented in each region?

How many channels contribute to each region?

Which region has the highest average views?
9. Gold Table — channel_analytics

This table summarizes channel performance.

Important metrics include:

channel_title
total_videos
total_rows
total_views
total_likes
total_comments
avg_views_per_row
peak_views
categories
region

This enables analysis such as:

Which channels have the most views?

Which channels have the highest-performing videos?

How many videos does each channel contribute?

Which regions contain the strongest channels?
10. Gold Table — category_analytics

This table summarizes category-level performance.

Important metrics include:

category_id
video_count
unique_videos
total_views
total_likes
total_comments
avg_views_per_row
unique_channels
region

This enables analysis such as:

Which categories generate the most views?

Which categories have the most videos?

Which categories have the highest average views?
11. Amazon S3

Amazon S3 provides the storage layer for the pipeline.

The architecture follows:

Bronze S3
   |
   v
Silver S3
   |
   v
Gold S3

The Gold bucket used by the project is:

yt-data-pipeline-gold-ap-south-1-dev-01

The Gold datasets are stored as Parquet.

12. AWS Lambda

Lambda is used for serverless processing and validation.

The project includes:

Data Quality Lambda

Responsible for:

Read Silver metadata/data through Athena
        |
        v
Run quality checks
        |
        v
PASS / FAIL
        |
        v
SNS notification

The Lambda source code is located at:

lambda/validate_silver/lambda_function.py
13. Amazon Athena

Athena provides the SQL query layer.

It is used for:

Silver validation
Silver querying
Gold transformations
Gold validation
Analytics queries

The repository contains:

athena/create_table_silver.sql
athena/create_gold_tables.sql
athena/validation_queries.sql

Athena allows the project to query Parquet data in S3 without managing database servers.

14. AWS Glue

AWS Glue was considered for ETL processing and catalog management.

The original design included:

Bronze → Silver Glue ETL
Silver → Gold Glue ETL

However, Glue ETL execution was blocked by AWS account permissions.

The project therefore uses Athena-based transformations for the final implementation.

This is an important architectural decision:

Planned:

Bronze
   ↓
Glue ETL
   ↓
Silver
   ↓
Glue ETL
   ↓
Gold


Final:

Bronze
   ↓
Existing processing / conversion
   ↓
Silver Parquet
   ↓
Athena SQL / CTAS
   ↓
Gold Parquet

Glue is therefore documented as an attempted/planned component rather than claiming that the restricted Glue jobs successfully executed the final pipeline.

15. Amazon SNS

Amazon SNS is used for data-quality notifications.

The validation Lambda can publish:

PASS

or:

FAIL

notifications to the configured SNS topic.

The purpose is to alert when the quality gate detects a problem.

16. AWS IAM

IAM controls access between the AWS services.

The project follows the principle of least privilege where possible.

Typical permissions include:

Lambda
  |
  +-- S3 access
  |
  +-- Athena access
  |
  +-- SNS publish
  |
  +-- CloudWatch Logs

IAM policies are stored in:

iam/
17. Final Data Flow

The final implemented logical flow is:

                 DATA SOURCES
                     |
          +----------+----------+
          |                     |
       Kaggle                YouTube API
       CSV data                 JSON
          |                     |
          +----------+----------+
                     |
                     v
              BRONZE S3
                     |
                     v
          Silver Parquet datasets
                     |
                     v
           UNIFIED SILVER DATA
          trending_silver_unified
                     |
                     v
            DATA QUALITY LAMBDA
                     |
             +-------+-------+
             |               |
           PASS             FAIL
             |               |
             v               v
           GOLD             SNS
             |
             v
       ATHENA CTAS
             |
      +------+------+------+
      |             |      |
      v             v      v
  Trending       Channel  Category
  Analytics      Analytics Analytics
      |             |      |
      +------+------+------+
             |
             v
        GOLD S3 PARQUET
             |
             v
          ATHENA
             |
             v
        SQL ANALYTICS
18. Current Project Status

The project currently demonstrates:

S3-based data lake storage
Bronze/Silver/Gold architecture
Multiple input formats
Parquet-based analytical storage
Athena SQL
Athena CTAS
Lambda-based data-quality validation
Pandas-based validation logic
SNS notifications
IAM-based access control
Data validation queries
Regional and analytical aggregations
19. Important Design Decisions
Why Parquet?

Parquet provides columnar storage suitable for analytical workloads.

Why Athena?

Athena provides serverless SQL access to data stored in S3.

Why CTAS?

CTAS allows Athena to create analytical tables and write the results directly as Parquet.

Why Lambda for Data Quality?

Lambda provides a serverless quality gate before downstream analytics.

Why not automatically remove duplicate video IDs?

Because the current schema does not contain enough temporal information to safely determine whether repeated video IDs represent invalid duplicates or legitimate observations.

Why no Glue ETL in the final flow?

Glue ETL access was restricted in the AWS account. Athena SQL/CTAS was used as the practical alternative for the Gold transformation.

20. Repository Structure
youtube-trending-pipeline/
│
├── README.md
│
├── athena/
│   ├── create_table_silver.sql
│   ├── create_gold_tables.sql
│   └── validation_queries.sql
│
├── lambda/
│   └── validate_silver/
│       └── lambda_function.py
│
├── iam/
│
└── docs/
    └── architecture.md
21. Future Extensions

The following components are not part of the currently completed core implementation:

Step Functions
QuickSight dashboards
Automated scheduling
Additional monitoring
Advanced data-quality rules
