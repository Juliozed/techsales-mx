-- mart_rep_performance.sql
-- Purpose: pre-calculated rep performance KPIs
-- Used by: executive dashboards, rep scorecards

WITH sales AS (
    SELECT * FROM {{ ref('fct_sales') }}
)

SELECT
    rep_name,
    annual_quota,
    region,

    -- Volume
    COUNT(*)                                    AS total_orders,
    SUM(revenue)                                AS total_revenue,
    ROUND(AVG(revenue), 2)                      AS avg_order_value,

    -- Completed only
    SUM(CASE WHEN status = 'COMPLETED' 
        THEN revenue ELSE 0 END)                AS completed_revenue,
    COUNT(CASE WHEN status = 'COMPLETED' 
        THEN 1 END)                             AS completed_orders,

    -- Rates
    ROUND(COUNT(CASE WHEN status = 'COMPLETED' THEN 1 END) 
        * 100.0 / COUNT(*), 1)                  AS completion_rate_pct,
    ROUND(COUNT(CASE WHEN status = 'CANCELLED' THEN 1 END) 
        * 100.0 / COUNT(*), 1)                  AS cancel_rate_pct,

    -- Quota attainment
    ROUND(SUM(CASE WHEN status = 'COMPLETED' 
        THEN revenue ELSE 0 END) 
        * 100.0 / annual_quota, 1)              AS quota_attainment_pct,

    -- Shipping
    ROUND(AVG(days_to_ship), 1)                 AS avg_days_to_ship

FROM sales
GROUP BY rep_name, annual_quota, region
ORDER BY total_revenue DESC