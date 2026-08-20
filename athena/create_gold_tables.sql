-- ============================================================
-- YouTube Trending Data Pipeline
-- Gold Layer - Analytics Tables
-- ============================================================
--
-- Purpose:
--   Transform the Unified Silver dataset into analytics-ready
--   Gold datasets stored as Parquet in Amazon S3.
--
-- Final architecture:
--
--   Unified Silver
--        |
--        v
--   Amazon Athena SQL / CTAS
--        |
--        +-----------------------------+
--        |              |              |
--        v              v              v
--   Trending        Channel        Category
--   Analytics       Analytics      Analytics
--        |              |              |
--        +--------------+--------------+
--                       |
--                       v
--                 Gold S3 Parquet
--
-- Note:
--   AWS Glue ETL was originally planned for the Silver-to-Gold
--   transformation. Due to Glue access restrictions in the AWS
--   account, the final implementation uses Athena CTAS.
--
-- Gold bucket:
--   yt-data-pipeline-gold-ap-south-1-dev-01
--
-- Silver source:
--   trending_silver_unified
--
-- ============================================================


-- ============================================================
-- GOLD TABLE 1
-- TRENDING ANALYTICS
-- ============================================================
--
-- Regional summary of the unified Silver data.
--
-- Metrics:
--   - total rows
--   - unique videos
--   - total views
--   - total likes
--   - total comments
--   - average views
--   - maximum views
--   - unique channels
--   - unique categories
--
-- ============================================================

DROP TABLE IF EXISTS trending_analytics;


CREATE TABLE trending_analytics
WITH (
    format = 'PARQUET',
    format_version = 2,
    external_location =
        's3://yt-data-pipeline-gold-ap-south-1-dev-01/youtube/trending_analytics/',
    write_compression = 'SNAPPY',
    partitioned_by = ARRAY['region']
)
AS

SELECT
    COUNT(*) AS total_rows,

    COUNT(DISTINCT video_id) AS unique_videos,

    SUM(view_count) AS total_views,

    SUM(like_count) AS total_likes,

    SUM(comment_count) AS total_comments,

    AVG(view_count) AS avg_views_per_row,

    MAX(view_count) AS max_views,

    COUNT(DISTINCT channel_title) AS unique_channels,

    COUNT(DISTINCT category_id) AS unique_categories,

    region

FROM trending_silver_unified

GROUP BY region;


-- ============================================================
-- GOLD TABLE 2
-- CHANNEL ANALYTICS
-- ============================================================
--
-- Channel-level performance metrics within each region.
--
-- Metrics:
--   - distinct videos
--   - total observations
--   - total views
--   - total likes
--   - total comments
--   - average views
--   - peak views
--   - number of categories
--
-- ============================================================

DROP TABLE IF EXISTS channel_analytics;


CREATE TABLE channel_analytics
WITH (
    format = 'PARQUET',
    format_version = 2,
    external_location =
        's3://yt-data-pipeline-gold-ap-south-1-dev-01/youtube/channel_analytics/',
    write_compression = 'SNAPPY',
    partitioned_by = ARRAY['region']
)
AS

SELECT
    channel_title,

    COUNT(DISTINCT video_id) AS total_videos,

    COUNT(*) AS total_rows,

    SUM(view_count) AS total_views,

    SUM(like_count) AS total_likes,

    SUM(comment_count) AS total_comments,

    AVG(view_count) AS avg_views_per_row,

    MAX(view_count) AS peak_views,

    COUNT(DISTINCT category_id) AS categories,

    region

FROM trending_silver_unified

GROUP BY
    channel_title,
    region;


-- ============================================================
-- GOLD TABLE 3
-- CATEGORY ANALYTICS
-- ============================================================
--
-- Category-level performance metrics within each region.
--
-- Metrics:
--   - total observations
--   - unique videos
--   - total views
--   - total likes
--   - total comments
--   - average views
--   - unique channels
--
-- ============================================================

DROP TABLE IF EXISTS category_analytics;


CREATE TABLE category_analytics
WITH (
    format = 'PARQUET',
    format_version = 2,
    external_location =
        's3://yt-data-pipeline-gold-ap-south-1-dev-01/youtube/category_analytics/',
    write_compression = 'SNAPPY',
    partitioned_by = ARRAY['region']
)
AS

SELECT
    category_id,

    COUNT(*) AS video_count,

    COUNT(DISTINCT video_id) AS unique_videos,

    SUM(view_count) AS total_views,

    SUM(like_count) AS total_likes,

    SUM(comment_count) AS total_comments,

    AVG(view_count) AS avg_views_per_row,

    COUNT(DISTINCT channel_title) AS unique_channels,

    region

FROM trending_silver_unified

GROUP BY
    category_id,
    region;


-- ============================================================
-- GOLD VERIFICATION
-- ============================================================


-- Verify regional analytics
SELECT *
FROM trending_analytics
ORDER BY total_views DESC;


-- Verify channel analytics
SELECT *
FROM channel_analytics
ORDER BY total_views DESC
LIMIT 20;


-- Verify category analytics
SELECT *
FROM category_analytics
ORDER BY total_views DESC;


-- ============================================================
-- GOLD ROW COUNTS
-- ============================================================

SELECT
    'trending_analytics' AS table_name,
    COUNT(*) AS row_count
FROM trending_analytics

UNION ALL

SELECT
    'channel_analytics' AS table_name,
    COUNT(*) AS row_count
FROM channel_analytics

UNION ALL

SELECT
    'category_analytics' AS table_name,
    COUNT(*) AS row_count
FROM category_analytics;
