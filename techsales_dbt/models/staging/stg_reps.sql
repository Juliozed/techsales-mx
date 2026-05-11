-- stg_reps.sql
-- Purpose: clean and standardize reps reference table

WITH source AS (

    SELECT * FROM {{ source('techsales', 'reps') }}

),

cleaned AS (

    SELECT
        rep_id,
        TRIM(rep_name)          AS rep_name,
        hire_date::DATE         AS hire_date,
        TRIM(region)            AS region,
        annual_quota::NUMERIC   AS annual_quota,
        base_salary::NUMERIC    AS base_salary,
        TRIM(manager)           AS manager
    FROM source

)

SELECT * FROM cleaned