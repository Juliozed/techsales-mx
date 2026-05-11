-- stg_sales_orders.sql
-- Purpose: clean and standardize raw sales orders

WITH source AS (

    SELECT * FROM {{ source('techsales', 'sales_orders') }}

),

cleaned AS (

    SELECT
        order_id,
        order_date::DATE                                       AS order_date,
        customer_id,
        rep_id,
        product_id,
        UPPER(TRIM(status))                                    AS status,
        units,
        unit_price::NUMERIC(10,2)                             AS unit_price,
        revenue::NUMERIC(12,2)                                AS revenue,
        cost::NUMERIC(12,2)                                   AS cost,
        profit::NUMERIC(12,2)                                 AS profit,
        ROUND(profit::NUMERIC / NULLIF(revenue::NUMERIC,0), 4) AS profit_pct,
        days_to_ship,
        region,
        EXTRACT(YEAR  FROM order_date::DATE)::INTEGER          AS order_year,
        EXTRACT(MONTH FROM order_date::DATE)::INTEGER          AS order_month,
        TO_CHAR(order_date::DATE, 'YYYY-MM')                   AS order_period

    FROM source
    WHERE order_id IS NOT NULL

)

SELECT * FROM cleaned