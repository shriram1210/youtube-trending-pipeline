"""
Data quality validation Lambda.

Reads the Silver Parquet dataset, runs a set of basic quality checks,
and publishes a pass/fail message to an SNS topic.

Requires the AWSSDKPandas Lambda layer (provides awswrangler + pandas).
Role: lambda-validate-role (read Silver, publish to SNS, write CloudWatch logs).
"""
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
