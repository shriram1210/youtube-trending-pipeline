-- ============================================================
-- YouTube Trending Data Pipeline
-- Data Validation Queries
-- ============================================================
--
-- Purpose:
--   SQL queries used to inspect, validate and troubleshoot
--   the Bronze, Silver and Gold layers.
--
-- These queries are intended for:
--   - schema validation
--   - row-count validation
--   - source validation
--   - NULL checks
--   - invalid-value checks
--   - duplicate investigation
--   - Silver validation
--   - Gold validation
--
-- IMPORTANT:
--   Duplicate video_id values are NOT automatically treated as
--   errors. The current Silver schema does not contain
--   trending_date, so repeated video IDs cannot safely be
--   classified as invalid duplicates.
--
-- ============================================================


-- ============================================================
-- 1. DATABASE / TABLE DISCOVERY
-- ============================================================

SHOW DATABASES;

SHOW TABLES;


-- ============================================================
-- 2. INSPECT SILVER TABLE SCHEMAS
-- ============================================================

DESCRIBE trending_silver_csv;

DESCRIBE trending_silver_json;

DESCRIBE youtube_api;

DESCRIBE trending_silver_unified;


-- ============================================================
-- 3. SILVER TOTAL ROW COUNT
-- ============================================================

SELECT
    COUNT(*) AS total_rows
FROM trending_silver_unified;


-- ============================================================
-- 4. SILVER UNIQUE VIDEO COUNT
-- ============================================================

SELECT
    COUNT(DISTINCT video_id) AS unique_videos
FROM trending_silver_unified;


-- ============================================================
-- 5. ROW COUNT BY SOURCE
-- ============================================================

SELECT
    source_format,
    COUNT(*) AS row_count
FROM trending_silver_unified
GROUP BY source_format
ORDER BY source_format;


-- ============================================================
-- 6. ROW COUNT BY SOURCE AND REGION
-- ============================================================

SELECT
    source_format,
    region,
    COUNT(*) AS row_count
FROM trending_silver_unified
GROUP BY
    source_format,
    region
ORDER BY
    source_format,
    region;


-- ============================================================
-- 7. UNIQUE VIDEOS BY SOURCE AND REGION
-- ============================================================

SELECT
    source_format,
    region,
    COUNT(DISTINCT video_id) AS unique_videos
FROM trending_silver_unified
GROUP BY
    source_format,
    region
ORDER BY
    source_format,
    region;


-- ============================================================
-- 8. SOURCE DUPLICATE INVESTIGATION
-- ============================================================
--
-- Shows the difference between total observations and
-- distinct video IDs.
--
-- Repeated video IDs are reported for investigation only.
-- They are not automatically deleted.
-- ============================================================

SELECT
    source_format,
    region,

    COUNT(*) AS total_rows,

    COUNT(DISTINCT video_id) AS unique_videos,

    COUNT(*) - COUNT(DISTINCT video_id) AS repeated_rows

FROM trending_silver_unified

GROUP BY
    source_format,
    region

ORDER BY
    source_format,
    region;


-- ============================================================
-- 9. FIND VIDEO IDs OCCURRING MORE THAN ONCE
-- ============================================================

SELECT
    video_id,
    region,
    source_format,
    COUNT(*) AS occurrences

FROM trending_silver_unified

GROUP BY
    video_id,
    region,
    source_format

HAVING COUNT(*) > 1

ORDER BY
    occurrences DESC;


-- ============================================================
-- 10. NULL CHECK - VIDEO ID
-- ============================================================

SELECT
    COUNT(*) AS null_video_ids
FROM trending_silver_unified
WHERE video_id IS NULL;


-- ============================================================
-- 11. NULL CHECK - TITLE
-- ============================================================

SELECT
    COUNT(*) AS null_titles
FROM trending_silver_unified
WHERE title IS NULL;


-- ============================================================
-- 12. NULL CHECK - REGION
-- ============================================================

SELECT
    COUNT(*) AS null_regions
FROM trending_silver_unified
WHERE region IS NULL;


-- ============================================================
-- 13. NULL SUMMARY
-- ============================================================

SELECT

    COUNT(*) AS total_rows,

    SUM(
        CASE
            WHEN video_id IS NULL
            THEN 1
            ELSE 0
        END
    ) AS null_video_ids,

    SUM(
        CASE
            WHEN title IS NULL
            THEN 1
            ELSE 0
        END
    ) AS null_titles,

    SUM(
        CASE
            WHEN region IS NULL
            THEN 1
            ELSE 0
        END
    ) AS null_regions

FROM trending_silver_unified;


-- ============================================================
-- 14. INVALID VIEW COUNTS
-- ============================================================

SELECT
    COUNT(*) AS negative_view_count_rows
FROM trending_silver_unified
WHERE view_count < 0;


-- ============================================================
-- 15. EXTREMELY LARGE VIEW COUNTS
-- ============================================================

SELECT
    COUNT(*) AS extreme_view_count_rows
FROM trending_silver_unified
WHERE view_count > 50000000000;


-- ============================================================
-- 16. SOURCE COVERAGE
-- ============================================================

SELECT
    source_format,
    COUNT(*) AS row_count
FROM trending_silver_unified
GROUP BY source_format
ORDER BY row_count DESC;


-- ============================================================
-- 17. REGION COVERAGE
-- ============================================================

SELECT
    region,
    COUNT(*) AS row_count
FROM trending_silver_unified
GROUP BY region
ORDER BY region;


-- ============================================================
-- 18. GOLD TABLE AVAILABILITY
-- ============================================================

SHOW TABLES;


-- ============================================================
-- 19. GOLD TRENDING ANALYTICS
-- ============================================================

SELECT *
FROM trending_analytics
ORDER BY total_views DESC;


-- ============================================================
-- 20. GOLD CHANNEL ANALYTICS
-- ============================================================

SELECT *
FROM channel_analytics
ORDER BY total_views DESC
LIMIT 20;


-- ============================================================
-- 21. GOLD CATEGORY ANALYTICS
-- ============================================================

SELECT *
FROM category_analytics
ORDER BY total_views DESC;


-- ============================================================
-- 22. GOLD ROW COUNTS
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


-- ============================================================
-- 23. TOP CHANNELS BY REGION
-- ============================================================

SELECT
    region,
    channel_title,
    total_views,
    total_videos

FROM channel_analytics

ORDER BY
    region,
    total_views DESC

LIMIT 100;


-- ============================================================
-- 24. TOP CATEGORIES BY REGION
-- ============================================================

SELECT
    region,
    category_id,
    total_views,
    unique_videos

FROM category_analytics

ORDER BY
    region,
    total_views DESC

LIMIT 100;


-- ============================================================
-- END OF VALIDATION QUERIES
-- ============================================================
