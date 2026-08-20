-- ============================================================
-- YouTube Trending Data Pipeline
-- Silver Layer - Unified Athena View
-- ============================================================
--
-- Purpose:
--   Creates a unified logical view over the Parquet datasets
--   produced by the Bronze -> Silver transformations.
--
-- Important:
--   The project could not use AWS Glue Crawlers because of
--   account-level access restrictions.
--
--   Therefore, Athena is used to register/query the datasets.
--
-- Sources:
--   1. Historical/Kaggle CSV -> trending_csv
--   2. Historical JSON       -> trending_json
--   3. YouTube API           -> youtube_api
--
-- Database:
--   yt_pipeline_bronze_dev
--
-- ============================================================


-- ------------------------------------------------------------
-- 1. Inspect the existing Silver source tables
-- ------------------------------------------------------------

SHOW TABLES;


-- ------------------------------------------------------------
-- 2. Unified Silver View
-- ------------------------------------------------------------
--
-- This view provides one common schema for analytics.
--
-- The current deployed datasets use:
--
--   video_id
--   title
--   channel_title
--   category_id
--   view_count
--   region
--   source_format
--
-- The view does NOT invent a trending_date because the current
-- deployed Silver schema does not contain that field.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW trending_silver_unified AS

SELECT
    video_id,
    title,
    channel_title,
    category_id,
    view_count,
    region,
    'csv' AS source_format
FROM trending_silver_csv

UNION ALL

SELECT
    video_id,
    title,
    channel_title,
    category_id,
    view_count,
    region,
    'json' AS source_format
FROM trending_silver_json

UNION ALL

SELECT
    video_id,
    title,
    channel_title,
    category_id,
    view_count,
    region,
    'api' AS source_format
FROM youtube_api;


-- ------------------------------------------------------------
-- 3. Basic verification
-- ------------------------------------------------------------

SELECT
    source_format,
    region,
    COUNT(*) AS row_count,
    COUNT(DISTINCT video_id) AS unique_videos
FROM trending_silver_unified
GROUP BY
    source_format,
    region
ORDER BY
    source_format,
    region;


-- ------------------------------------------------------------
-- 4. Overall Silver verification
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT video_id) AS unique_videos,
    COUNT(DISTINCT region) AS regions,
    COUNT(DISTINCT source_format) AS source_types
FROM trending_silver_unified;
