# Architecture — YouTube Trending Data Pipeline

## Overview

End-to-end data pipeline using AWS Medallion Architecture.
Data flows through three layers — Bronze, Silver, Gold.

---

## Layer by Layer Explanation

### Bronze Layer — Raw Storage
- Stores raw data exactly as received
- YouTube API JSON files land here
- Kaggle CSV files land here
- Nothing is transformed or cleaned
- Data is never deleted

### Silver Layer — Cleaned Data
- Raw data cleaned and standardized
- Converted to Parquet format
- Partitioned by year/month/day
- Null values handled
- Duplicates removed
- Validated by Lambda quality checks

### Gold Layer — Business Ready
- Aggregated for business analytics
- Three tables produced:
  - trending_analytics
  - channel_analytics
  - category_analytics
- Ready for Athena queries and QuickSight dashboards

---

## Service by Service Explanation

### Amazon S3
Three buckets:
- yt-pipeline-bronze — raw data
- yt-pipeline-silver — cleaned Parquet
- yt-pipeline-gold — aggregated Parquet

### AWS Lambda
Two functions:
- Ingest Lambda — writes raw data to Bronze
- Validate Lambda — reads Silver, runs quality checks, alerts via SNS

### AWS Glue
Two ETL jobs:
- Bronze to Silver — cleans and converts CSV/JSON to Parquet
- Silver to Gold — aggregates data for analytics

### Amazon Athena
- SQL queries over Silver and Gold Parquet data
- Tables registered via explicit DDL
- No Glue Crawler needed

### Amazon SNS
- pipeline-alerts topic
- Sends email on validation pass or fail
- Immediate failure notification

### AWS IAM
Three roles with least privilege:
- glue-etl-role — S3 read/write for ETL
- lambda-validate-role — S3 read Silver + SNS publish
- lambda-ingest-role — S3 write Bronze only

---

## Data Flow

YouTube API
↓
S3 Bronze (raw JSON)
↓
Glue ETL (clean + convert)
↓
S3 Silver (clean Parquet)
↓
Lambda Validate (quality checks)
↓
SNS Alert (pass or fail email)
↓
Glue ETL (aggregate)
↓
S3 Gold (aggregated Parquet)
↓
Athena (SQL queries)
↓
QuickSight (dashboards)

---

## Orchestration (Planned)

Step Functions will orchestrate the full pipeline:

Ingestion
↓
Wait for data
↓
Silver transforms (parallel)
↓
Quality Gate (Lambda validate)
↓
Gold aggregation
↓
SNS success notification

---

## Note on Glue Crawlers

Glue Crawlers are blocked in this AWS account due to
permissions restriction.

Replaced with explicit CREATE EXTERNAL TABLE DDL in Athena.

This is a legitimate real-world alternative. Many teams
prefer explicit DDL over crawler inference because:
- Inferred schemas can guess wrong on edge-case rows
- Explicit schemas give full control
- No crawler cost or scheduling needed
