-- fct_sales.sql
-- Purpose: final sales fact table for dashboards
-- Joins orders with rep and product details
-- This is what Power BI connects to

WITH orders AS (
    SELECT * FROM {{ ref('stg_sales_orders') }}
),

reps AS (
    SELECT * FROM {{ ref('stg_reps') }}
),

products AS (
    SELECT * FROM {{ ref('stg_products') }}
)

SELECT
    o.order_id,
    o.order_date,
    o.order_year,
    o.order_month,
    o.order_period,
    o.status,
    o.units,
    o.revenue,
    o.cost,
    o.profit,
    o.profit_pct,
    o.days_to_ship,
    o.region,

    -- Rep details
    r.rep_name,
    r.annual_quota,

    -- Product details
    p.product_name,
    p.category,
    p.unit_price

FROM orders o
LEFT JOIN reps r     ON o.rep_id     = r.rep_id
LEFT JOIN products p ON o.product_id = p.product_id