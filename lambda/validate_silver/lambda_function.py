"""
Data Quality Validation Lambda
================================

Validates the unified Silver dataset before the Gold layer is used.

The Lambda queries the Silver Glue/Athena catalog table using
Amazon Athena and performs basic data-quality checks.

Checks:
    1. Row count
    2. Critical-column NULL checks
    3. Schema validation
    4. Numeric value validation
    5. Data-source coverage

AWS services used:
    - AWS Lambda
    - Amazon Athena
    - Amazon SNS
    - Amazon CloudWatch Logs

Python libraries:
    - boto3
    - pandas
"""

import os
import time
import logging

import boto3
import pandas as pd


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

logger = logging.getLogger()
logger.setLevel(logging.INFO)

athena = boto3.client("athena")
sns = boto3.client("sns")

DATABASE = os.environ.get(
    "ATHENA_DATABASE",
    "yt_pipeline_bronze_dev"
)

TABLE = os.environ.get(
    "ATHENA_TABLE",
    "trending_silver_unified"
)

ATHENA_OUTPUT = os.environ.get(
    "ATHENA_OUTPUT",
    "s3://YOUR-ATHENA-RESULTS-BUCKET/"
)

SNS_TOPIC_ARN = os.environ.get(
    "SNS_TOPIC_ARN",
    ""
)

MIN_ROW_COUNT = int(
    os.environ.get("DQ_MIN_ROW_COUNT", "10")
)

MAX_NULL_PERCENT = float(
    os.environ.get("DQ_MAX_NULL_PERCENT", "5")
)


EXPECTED_COLUMNS = [
    "video_id",
    "title",
    "channel_title",
    "category_id",
    "view_count",
    "like_count",
    "comment_count",
    "published_at",
    "duration",
    "region",
    "source_format",
]


# ---------------------------------------------------------------------------
# Athena helper
# ---------------------------------------------------------------------------

def run_athena_query(query):
    """
    Execute an Athena query and return the result as a Pandas DataFrame.
    """

    logger.info("Executing Athena query:")
    logger.info(query)

    response = athena.start_query_execution(
        QueryString=query,
        QueryExecutionContext={
            "Database": DATABASE
        },
        ResultConfiguration={
            "OutputLocation": ATHENA_OUTPUT
        }
    )

    query_execution_id = response["QueryExecutionId"]

    while True:
        status_response = athena.get_query_execution(
            QueryExecutionId=query_execution_id
        )

        state = status_response["QueryExecution"]["Status"]["State"]

        if state == "SUCCEEDED":
            break

        if state in ["FAILED", "CANCELLED"]:
            reason = status_response["QueryExecution"]["Status"].get(
                "StateChangeReason",
                "Unknown Athena error"
            )
            raise RuntimeError(
                f"Athena query {state}: {reason}"
            )

        time.sleep(1)

    result = athena.get_query_results(
        QueryExecutionId=query_execution_id
    )

    rows = result["ResultSet"]["Rows"]

    if not rows:
        return pd.DataFrame()

    headers = [
        column.get("VarCharValue", "")
        for column in rows[0]["Data"]
    ]

    data = []

    for row in rows[1:]:
        values = [
            column.get("VarCharValue", "")
            for column in row["Data"]
        ]

        while len(values) < len(headers):
            values.append("")

        data.append(values)

    return pd.DataFrame(data, columns=headers)


# ---------------------------------------------------------------------------
# Data-quality checks
# ---------------------------------------------------------------------------

def check_row_count():
    """Check whether the Silver table contains enough rows."""

    query = f"""
        SELECT COUNT(*) AS row_count
        FROM "{TABLE}"
    """

    df = run_athena_query(query)

    row_count = int(df.iloc[0]["row_count"])

    passed = row_count >= MIN_ROW_COUNT

    return {
        "check": "row_count",
        "value": row_count,
        "threshold": MIN_ROW_COUNT,
        "passed": passed,
        "message": (
            f"Row count: {row_count} "
            f"(minimum required: {MIN_ROW_COUNT})"
        )
    }


def check_schema():
    """Check whether the expected columns exist."""

    query = f"""
        SELECT *
        FROM "{TABLE}"
        LIMIT 1
    """

    df = run_athena_query(query)

    actual_columns = set(df.columns)
    expected_columns = set(EXPECTED_COLUMNS)

    missing_columns = sorted(
        expected_columns - actual_columns
    )

    passed = len(missing_columns) == 0

    return {
        "check": "schema",
        "missing_columns": missing_columns,
        "passed": passed,
        "message": (
            "All expected columns are present"
            if passed
            else f"Missing columns: {missing_columns}"
        )
    }


def check_null_percentage():
    """
    Check NULL percentage for important columns.

    This query checks the critical fields used by the pipeline.
    """

    query = f"""
        SELECT
            COUNT(*) AS total_rows,

            SUM(
                CASE
                    WHEN video_id IS NULL
                    THEN 1
                    ELSE 0
                END
            ) AS null_video_id,

            SUM(
                CASE
                    WHEN title IS NULL
                    THEN 1
                    ELSE 0
                END
            ) AS null_title,

            SUM(
                CASE
                    WHEN region IS NULL
                    THEN 1
                    ELSE 0
                END
            ) AS null_region

        FROM "{TABLE}"
    """

    df = run_athena_query(query)

    total_rows = int(df.iloc[0]["total_rows"])

    if total_rows == 0:
        return {
            "check": "null_percentage",
            "passed": False,
            "message": "Cannot calculate NULL percentage because table is empty"
        }

    results = []

    columns = {
        "video_id": "null_video_id",
        "title": "null_title",
        "region": "null_region",
    }

    for column, null_column in columns.items():

        null_count = int(
            df.iloc[0][null_column]
        )

        null_percentage = (
            null_count / total_rows
        ) * 100

        passed = (
            null_percentage <= MAX_NULL_PERCENT
        )

        results.append({
            "column": column,
            "null_count": null_count,
            "null_percentage": round(
                null_percentage,
                2
            ),
            "passed": passed
        })

    overall_passed = all(
        result["passed"]
        for result in results
    )

    return {
        "check": "null_percentage",
        "columns": results,
        "threshold": MAX_NULL_PERCENT,
        "passed": overall_passed,
        "message": (
            "Critical-column NULL checks passed"
            if overall_passed
            else "One or more critical columns exceed the NULL threshold"
        )
    }


def check_value_ranges():
    """Check for impossible negative view counts."""

    query = f"""
        SELECT
            COUNT(*) AS invalid_views
        FROM "{TABLE}"
        WHERE view_count < 0
    """

    df = run_athena_query(query)

    invalid_views = int(
        df.iloc[0]["invalid_views"]
    )

    passed = invalid_views == 0

    return {
        "check": "value_range",
        "invalid_view_count": invalid_views,
        "passed": passed,
        "message": (
            "No negative view counts found"
            if passed
            else f"Found {invalid_views} rows with negative view counts"
        )
    }


def check_source_coverage():
    """
    Verify that expected source types are present.

    The project combines:
        - CSV
        - JSON
        - YouTube API
    """

    query = f"""
        SELECT
            source_format,
            COUNT(*) AS row_count
        FROM "{TABLE}"
        GROUP BY source_format
        ORDER BY source_format
    """

    df = run_athena_query(query)

    expected_sources = {
        "csv",
        "json",
        "api"
    }

    actual_sources = set(
        df["source_format"].str.lower()
    )

    missing_sources = sorted(
        expected_sources - actual_sources
    )

    passed = len(missing_sources) == 0

    return {
        "check": "source_coverage",
        "sources_found": sorted(actual_sources),
        "missing_sources": missing_sources,
        "passed": passed,
        "message": (
            "Expected data sources are present"
            if passed
            else f"Missing sources: {missing_sources}"
        )
    }


# ---------------------------------------------------------------------------
# SNS notification
# ---------------------------------------------------------------------------

def publish_notification(subject, message):
    """Publish a notification when an SNS topic is configured."""

    if not SNS_TOPIC_ARN:
        logger.info(
            "SNS_TOPIC_ARN not configured. "
            "Skipping SNS notification."
        )
        return

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=subject,
        Message=message
    )


# ---------------------------------------------------------------------------
# Lambda handler
# ---------------------------------------------------------------------------

def lambda_handler(event, context):

    logger.info(
        f"Running Data Quality checks on "
        f"{DATABASE}.{TABLE}"
    )

    results = []

    try:

        results.append(
            check_row_count()
        )

        results.append(
            check_schema()
        )

        results.append(
            check_null_percentage()
        )

        results.append(
            check_value_ranges()
        )

        results.append(
            check_source_coverage()
        )

        overall_passed = all(
            result["passed"]
            for result in results
        )

        passed_count = sum(
            1
            for result in results
            if result["passed"]
        )

        total_count = len(results)

        logger.info(
            f"Data Quality Summary: "
            f"{passed_count}/{total_count} checks passed"
        )

        if overall_passed:

            publish_notification(
                "Pipeline Data Quality PASSED",
                (
                    f"All {total_count} data-quality checks "
                    f"passed for {DATABASE}.{TABLE}."
                )
            )

        else:

            failed_checks = [
                result
                for result in results
                if not result["passed"]
            ]

            publish_notification(
                "Pipeline Data Quality FAILED",
                str(failed_checks)
            )

        return {
            "quality_passed": overall_passed,
            "checks_passed": passed_count,
            "checks_total": total_count,
            "database": DATABASE,
            "table": TABLE,
            "details": results
        }

    except Exception as error:

        logger.exception(
            "Data Quality execution failed"
        )

        publish_notification(
            "Pipeline Data Quality ERROR",
            str(error)
        )

        return {
            "quality_passed": False,
            "error": str(error)
        }
