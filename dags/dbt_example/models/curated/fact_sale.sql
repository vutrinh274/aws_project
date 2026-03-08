{% set process_date = var('process_date') %}
{{- config(
  partition_by={
    'field': 'snapshot_date',
    'data_type': 'date',
  },
  materialized='incremental',
  incremental_strategy='insert_overwrite',
)-}}

with tmp as (
SELECT
    PARSE_DATE('%m/%d/%Y', s.order_date) as order_date,
    s.territory_key,
    s.snapshot_date,
    (s.order_quantity * p.product_price) as revenue,
    (s.order_quantity * p.product_cost) as cost,
    (s.order_quantity * p.product_price) - (s.order_quantity * p.product_cost) as profit,
    p.product_surrogate_key,

FROM {{ ref("stg_sales") }} s
LEFT JOIN {{ ref("dim_product") }} p
    ON s.product_key = p.product_key
    AND s.snapshot_date between p.effective_date and p.expired_date
WHERE s.snapshot_date = '{{ process_date }}'
)

SELECT 
  tmp.* EXCEPT(territory_key),
  sales_territory_surrogate_key
FROM tmp 
LEFT JOIN {{ ref("dim_territories") }} t
    ON tmp.territory_key = t.sales_territory_key
  AND  tmp.snapshot_date between t.effective_date and t.expired_date





  