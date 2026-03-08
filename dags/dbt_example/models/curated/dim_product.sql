{% set process_date = var('process_date') %}
{{
    config(
        materialized='incremental',
        unique_key=['product_surrogate_key', 'product_key', 'effective_date'],
        incremental_strategy='merge'
    )
}}
with product as (
    SELECT
        product_key,
        product_subcategory_key,
        product_sku,
        product_name,
        product_description,
        product_price,
        product_cost,
        product_color,
        product_size,
        snapshot_date
    FROM {{ ref('stg_products') }}
    WHERE snapshot_date = '{{ process_date }}'
    
)
, product_subcategories as (
    SELECT
        product_subcategory_key,
        subcategory_name,
        product_category_key,
        snapshot_date
    FROM {{ ref('stg_product_subcategories') }}
    WHERE snapshot_date = '{{ process_date }}'
)
, product_categories as (
    SELECT
        product_category_key,
        category_name,
        snapshot_date
    FROM {{ ref('stg_product_categories') }}
    WHERE snapshot_date = '{{ process_date }}'
)
, source as (
    SELECT
    {{ dbt_utils.generate_surrogate_key([
        'product_key',
        'product_sku',
        'product_name',
        'product_description',
        'product_price',
        'product_cost',
        'product_color',
        'product_size',
        'subcategory_name',
        'category_name'
    ]) }} AS product_surrogate_key,
        product_key,
        product_sku,
        product_name,
        product_description,
        product_price,
        product_cost,
        product_color,
        product_size,
        subcategory_name,
        category_name,
        DATE(snapshot_date) as effective_date, 
        DATE('9999-12-31') as expired_date,
        true as is_current
    FROM product
    LEFT JOIN product_subcategories USING (product_subcategory_key, snapshot_date)
    LEFT JOIN product_categories USING (product_category_key, snapshot_date)
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
        s.product_key as s_product_key,
        s.product_surrogate_key as s_product_surrogate_key,
        s.product_sku as s_product_sku,
        s.product_name as s_product_name,
        s.product_description as s_product_description,
        s.product_price as s_product_price,
        s.product_cost as s_product_cost,
        s.product_color as s_product_color,
        s.product_size as s_product_size,
        s.subcategory_name as s_subcategory_name,
        s.category_name as s_category_name,
        s.effective_date as s_effective_date,
        s.expired_date as s_expired_date,
        s.is_current as s_is_current,

        -- data from target
        t.product_key as t_product_key,
        t.product_surrogate_key as t_product_surrogate_key,
        t.product_sku as t_product_sku,
        t.product_name as t_product_name,
        t.product_description as t_product_description,
        t.product_price as t_product_price,
        t.product_cost as t_product_cost,
        t.product_color as t_product_color,
        t.product_size as t_product_size,
        t.subcategory_name as t_subcategory_name,
        t.category_name as t_category_name,
        t.effective_date as t_effective_date,
        t.expired_date as t_expired_date,
        t.is_current as t_is_current,
        
        FROM source s
        LEFT JOIN target_data t ON s.product_key = t.product_key
    )

    -- NEW + UPDATE PRODUCT: INSERT
    SELECT
        s_product_key as product_key,
        s_product_surrogate_key as product_surrogate_key,
        s_product_sku as product_sku,
        s_product_name as product_name,
        s_product_description as product_description,
        s_product_price as product_price,
        s_product_cost as product_cost,
        s_product_color as product_color,
        s_product_size as product_size,
        s_subcategory_name as subcategory_name,
        s_category_name as category_name,
        s_effective_date as effective_date,
        s_expired_date as expired_date,
        s_is_current as is_current,
    FROM tmp
    WHERE t_product_key is null
    OR (t_product_key is not null AND s_product_surrogate_key != t_product_surrogate_key)

    -- EXPIRE EXISTING VERSIONS
    UNION ALL
    SELECT
        t_product_key as product_key,
        t_product_surrogate_key as product_surrogate_key,
        t_product_sku as product_sku,
        t_product_name as product_name,
        t_product_description as product_description,
        t_product_price as product_price,
        t_product_cost as product_cost,
        t_product_color as product_color,
        t_product_size as product_size,
        t_subcategory_name as subcategory_name,
        t_category_name as category_name,
        t_effective_date as effective_date,
        DATE_SUB(DATE '{{ process_date }}', INTERVAL 1 DAY) as expired_date, 
        false as is_current
    FROM tmp
    WHERE t_product_key is not null AND s_product_surrogate_key != t_product_surrogate_key
)
    SELECT * FROM incremental_scd

{% else %}

    SELECT * FROM source

{% endif %}