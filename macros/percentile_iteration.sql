{%- macro percentile_iteration(percentile) %}
{%- for i in range(0, percentile|length) %}
    , ceil(approx_quantiles(fee_charged/
        case
            when new_max_fee is null then txn_operation_count
            else (txn_operation_count+1)
        end
     , 100)[offset({{percentile[i]}})]
     ) as fee_charged_p{{percentile[i]}}
    , ceil(approx_quantiles(coalesce(new_max_fee, max_fee)/
        case
            when new_max_fee is null then txn_operation_count
            else (txn_operation_count+1)
        end
    , 100)[offset({{percentile[i]}})]
    ) as max_fee_p{{percentile[i]}}
{%- endfor %}
{%- endmacro %}
