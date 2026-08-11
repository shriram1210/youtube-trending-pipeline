-- Registers the Silver Parquet dataset in the Glue Data Catalog
-- without using a Glue Crawler (blocked in this AWS account).

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

-- Run again whenever new date partitions are added
-- replaces the crawler's detect new partitions behavior
MSCK REPAIR TABLE trending_silver;
