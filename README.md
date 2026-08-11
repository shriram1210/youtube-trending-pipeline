# 🎬 YouTube Trending Data Pipeline — AWS Medallion Architecture

![AWS](https://img.shields.io/badge/AWS-Cloud-orange?logo=amazon-aws)
![Python](https://img.shields.io/badge/Python-3.12-blue?logo=python)
![S3](https://img.shields.io/badge/AWS-S3-green)
![Glue](https://img.shields.io/badge/AWS-Glue-blue)
![Athena](https://img.shields.io/badge/AWS-Athena-purple)
![Lambda](https://img.shields.io/badge/AWS-Lambda-orange)
![Region](https://img.shields.io/badge/Region-ap--south--1-green)

---

## 📌 Project Overview

End-to-end data pipeline that ingests, cleans, validates, and aggregates
YouTube trending data using Bronze → Silver → Gold Medallion Architecture on AWS.

> ✅ Real-world data engineering pipeline
> ✅ Medallion Architecture (Bronze/Silver/Gold)
> ✅ Automated data quality validation
> ✅ Serverless and fully managed AWS services
> ✅ Least-privilege IAM security

---

## 🏗️ Architecture

Data Sources Bronze Layer Silver Layer Quality Gate Gold Layer Analytics
──────────── ──────────── ──────────── ──────────── ────────── ─────────

YouTube API ──┐ ┌─> Lambda ──────┐ ┌─> Glue ETL ──┬─> trending_analytics ──┐
├──> S3 (Bronze) ───────┤ JSON→Parquet ├──> S3 (Silver) ───────>│ ├─> channel_analytics ├──> S3 (Gold) ──> Athena ──> QuickSight
Kaggle CSV ───┘ └─> Glue ETL ─────┘ │ │ └─> category_analytics ──┘
CSV→Parquet ▼ └─> SNS (failure alert)
Lambda (Validate)
│
▼
SNS (pass/fail alert)

Cross-cutting: IAM · SNS · CloudWatch
Orchestration (planned): Step Functions

---

## ⚙️ AWS Services Used

| Service | Role |
|---------|------|
| **Amazon S3** | Bronze/Silver/Gold storage layers |
| **AWS Lambda** | JSON→Parquet transform + data quality validation |
| **AWS Glue** | CSV/JSON cleaning ETL (Silver) + aggregation ETL (Gold) |
| **Glue Data Catalog** | Table registry for Silver/Gold |
| **Amazon Athena** | SQL querying over Silver/Gold Parquet |
| **Amazon SNS** | Pass/fail email alerts on data quality checks |
| **AWS IAM** | Least-privilege roles per service |
| **Step Functions** | Pipeline orchestration (planned) |
| **CloudWatch** | Logging and monitoring (planned) |
| **QuickSight** | Final dashboards on Gold data (planned) |

---

## 🥉🥈🥇 Medallion Architecture Explained

### Bronze Layer — Raw Data
- Stores raw data exactly as received
- No transformation
- YouTube API JSON files
- Kaggle CSV files
- Data is never deleted from Bronze

### Silver Layer — Cleaned Data
- Data cleaned and standardized
- Converted to Parquet format (faster queries)
- Partitioned by year/month/day
- Null values handled
- Duplicate records removed

### Gold Layer — Business Ready Data
- Aggregated for business use
- trending_analytics — top trending videos
- channel_analytics — best performing channels
- category_analytics — most popular categories
- Ready for dashboards and reports

---

## 📊 Data Quality Checks

Lambda validation function checks:
- Row count is not zero
- No null video_id values
- No duplicate video_id values
- No negative view_count values

If any check fails — SNS sends failure alert email immediately.

---

## 🐍 Lambda Validation Code

```python
import awswrangler as wr
import boto3

SILVER_PATH = "s3://yt-pipeline-silver-<yourname>/trending/"
TOPIC_ARN = "arn:aws:sns:ap-south-1:<account-id>:pipeline-alerts"

def lambda_handler(event, context):
    sns = boto3.client("sns")
    df = wr.s3.read_parquet(path=SILVER_PATH, dataset=True)

    errors = []
    if len(df) == 0:
        errors.append("Row count is zero")
    if df["video_id"].isnull().any():
        errors.append("Null video_id found")
    if df["video_id"].duplicated().any():
        errors.append("Duplicate video_id found")
    if (df["view_count"] < 0).any():
        errors.append("Negative view_count found")

    if errors:
        sns.publish(
            TopicArn=TOPIC_ARN,
            Subject="Pipeline Validation FAILED",
            Message="Issues found:\n" + "\n".join(errors),
        )
        return {"status": "FAILED", "errors": errors}

    sns.publish(
        TopicArn=TOPIC_ARN,
        Subject="Pipeline Validation PASSED",
        Message=f"{len(df)} rows validated successfully.",
    )
    return {"status": "PASSED", "row_count": len(df)}
```

---

## 🗄️ Athena Table Registration

```sql
CREATE EXTERNAL TABLE trending_silver (
  video_id       string,
  title          string,
  channel_title  string,
  category_id    int,
  view_count     bigint,
  like_count     bigint,
  trending_date  date,
  source_format  string
)
PARTITIONED BY (year string, month string, day string)
STORED AS PARQUET
LOCATION 's3://yt-pipeline-silver-<yourname>/trending/';

MSCK REPAIR TABLE trending_silver;
```

> Note: Glue Crawlers were blocked in this AWS account.
> Replaced with explicit CREATE EXTERNAL TABLE DDL in Athena.
> This is a legitimate real-world alternative used by many teams.

---

## 🔐 IAM Roles

| Role | Permissions |
|------|-------------|
| `glue-etl-role` | S3 read Bronze + write Silver/Gold |
| `lambda-validate-role` | S3 read Silver + SNS publish |
| `lambda-ingest-role` | S3 write Bronze only |

Least privilege applied — each role has only minimum permissions needed.

---

## 📈 Progress

- [x] Phase 0 — YouTube Data API key + architecture design
- [x] Phase 1 — IAM foundations
- [x] Phase 2 — S3 bucket structure Bronze/Silver/Gold
- [x] Phase 3 — Seed data upload to Bronze
- [x] Phase 4 — Glue ETL Bronze to Silver
- [x] Phase 5 — Data quality validation Lambda + SNS
- [ ] Phase 6 — Glue ETL Silver to Gold
- [ ] Phase 7 — Athena table registration for Gold
- [ ] Phase 8 — Athena SQL querying
- [ ] Phase 9 — Step Functions orchestration
- [ ] Phase 10 — CloudWatch monitoring
- [ ] Phase 11 — QuickSight dashboards
- [ ] Phase 12 — Final documentation

---

## 📁 Repository Structure

youtube-trending-pipeline/
├── lambda/
│ └── validate_silver/
│ └── lambda_function.py
├── iam/
│ ├── glue-etl-s3-access.json
│ ├── lambda-validate-sns-publish.json
│ └── lambda-ingest-s3-write.json
├── athena/
│ └── create_table_silver.sql
├── docs/
│ └── architecture.md
└── README.md

---

## 🔮 Future Improvements

- [ ] Step Functions orchestration for full pipeline
- [ ] CloudWatch dashboards for monitoring
- [ ] QuickSight dashboards for business insights
- [ ] EventBridge trigger for daily ingestion
- [ ] Terraform IaC for reproducible deployment
- [ ] Support for more YouTube regions

---

## 🧠 What I Learned

- Medallion Architecture Bronze/Silver/Gold design pattern
- AWS Glue ETL jobs for data transformation
- Parquet format and columnar storage benefits
- AWS Athena SQL querying on S3 data
- Lambda data quality validation patterns
- SNS alerting for pipeline failures
- IAM least-privilege per service
- awswrangler Python library for AWS data engineering

---

## 👨‍💻 Author

**Shriram Koloor**
- ISE Student — JNN College of Engineering
- VTU — Building real AWS data engineering projects
- GitHub: https://github.com/shriram1210
- LinkedIn: [Your LinkedIn URL]

---

## 📄 License

MIT License — Open source and free to use.
