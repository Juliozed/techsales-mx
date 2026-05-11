-- stg_products.sql
-- Purpose: clean and standardize products reference table

WITH source AS (

    SELECT * FROM {{ source('techsales', 'products') }}

),

cleaned AS (

    SELECT
        product_id,
        TRIM(product_name)      AS product_name,
        TRIM(category)          AS category,
        unit_price::NUMERIC     AS unit_price,
        supplier_id,
        launch_date::DATE       AS launch_date,
        is_active
    FROM source

)

SELECT * FROM cleaned