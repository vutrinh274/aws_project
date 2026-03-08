{% set process_date = var('process_date') %}
{{
    config(
        materialized='incremental',
        unique_key=['sales_territory_surrogate_key', 'sales_territory_key', 'effective_date'],
        incremental_strategy='merge'
    )
}}

with source as (
    SELECT
    {{ dbt_utils.generate_surrogate_key([
        'sales_territory_key',
        'region',
        'country',
        'continent'
    ]) }} AS sales_territory_surrogate_key,
        sales_territory_key,
        region,
        country,
        continent,
        DATE(snapshot_date) as effective_date, 
        DATE('9999-12-31') as expired_date,
        true as is_current
    FROM {{ ref('stg_territories') }}
    WHERE snapshot_date = '{{ process_date }}'
)


{% if is_incremental() %}
, target_data as (
    SELECT
        *
    FROM {{ this }}
    WHERE is_current
)
,incremental_scd as (
    with tmp as (
        SELECT

        -- data from source
        s.sales_territory_key as s_sales_territory_key,
        s.sales_territory_surrogate_key as s_sales_territory_surrogate_key,
        s.region as s_region,
        s.country as s_country,
        s.continent as s_continent,
        s.effective_date as s_effective_date,
        s.expired_date as s_expired_date,
        s.is_current as s_is_current,

        -- data from target
        t.sales_territory_key as t_sales_territory_key,
        t.sales_territory_surrogate_key as t_sales_territory_surrogate_key,
        t.region as t_region,
        t.country as t_country,
        t.continent as t_continent,
        t.effective_date as t_effective_date,
        t.expired_date as t_expired_date,
        t.is_current as t_is_current,
        
        FROM source s
        LEFT JOIN target_data t ON s.sales_territory_key = t.sales_territory_key
    )

    -- NEW + UPDATE PRODUCT: INSERT
    SELECT
        s_sales_territory_key as sales_territory_key,
        s_sales_territory_surrogate_key as sales_territory_surrogate_key,
        s_region as region,
        s_country as country,
        s_continent as continent,
        s_effective_date as effective_date,
        s_expired_date as expired_date,
        s_is_current as is_current
    FROM tmp
    WHERE t_sales_territory_key is null
    OR (t_sales_territory_key is not null AND s_sales_territory_surrogate_key != t_sales_territory_surrogate_key)

    -- EXPIRE EXISTING VERSIONS
    UNION ALL
    SELECT
        t_sales_territory_key as sales_territory_key,
        t_sales_territory_surrogate_key as sales_territory_surrogate_key,
        t_region as region,
        t_country as country,
        t_continent as continent,
        t_effective_date as effective_date,
        DATE_SUB(DATE '{{ process_date }}', INTERVAL 1 DAY) as expired_date, 
        false as is_current
    FROM tmp
    WHERE t_sales_territory_key is not null AND s_sales_territory_surrogate_key != t_sales_territory_surrogate_key
)
    SELECT * FROM incremental_scd

{% else %}

    SELECT * FROM source

{% endif %}