[comment]: < Trade Aggregations -

{% docs trade_agg %}

This table contains the aggregated values for the trades involving different pairs of selling/buying assets, over different time periods in the past.

{% enddocs %}

{% docs trade_day_agg %}

Date from which all metrics are aggregated. In the Trade Aggregations table, the day_agg represents the day in which the daily aggregations were built.

{% enddocs %}

{% docs asset_a %}

Hashed id for the selling_asset.

{% enddocs %}

{% docs asset_a_type %}

The identifier for type of asset code used for the sold asset within the trade
Notes:

XLM is the native asset to the network. XLM has no asset code or issuer representation and will instead be displayed with an asset type of 'native'

{% enddocs %}

{% docs asset_a_code %}

The 4 or 12 character code of the sold asset within a trade
Notes:

Asset codes have no guarantees of uniqueness. The combination of asset code, issuer and type represents a distinct asset

{% enddocs %}

{% docs asset_a_issuer %}

The account address of the original asset issuer for the sold asset within a trade

{% enddocs %}

{% docs asset_b %}

Hashed id for the buying_asset.

{% enddocs %}

{% docs asset_b_type %}

The identifier for type of asset code used for the bought asset within the trade
Notes:

XLM is the native asset to the network. XLM has no asset code or issuer representation and will instead be displayed with an asset type of 'native'

{% enddocs %}

{% docs asset_b_code %}

The 4 or 12 character code of the bought asset within a trade
Notes:

Asset codes have no guarantees of uniqueness. The combination of asset code, issuer and type represents a distinct asset

{% enddocs %}

{% docs asset_b_issuer %}

The account address of the original asset issuer for the bought asset within a trade

{% enddocs %}

{% docs trade_count_daily %}

The count of trades executed against the network in a day.

{% enddocs %}

{% docs asset_a_volume_daily %}

The total raw amount of the asset being sold in all trades within that day.

{% enddocs %}

{% docs asset_b_volume_daily %}

The total raw amount of the asset being bought in all trades within that day.

{% enddocs %}

{% docs avg_price_daily %}

The total amount of the asset being bought in all trades divided by the total amount of the asset being sold in all trades, within that day.

{% enddocs %}

{% docs high_price_daily %}

the highest price obtained from the ratio between denominator and numerator for that day, for the selling:buying asset price.

{% enddocs %}

{% docs low_price_daily %}

the lowest price obtained from the ratio between denominator and numerator for that day, for the selling:buying asset price.

{% enddocs %}

{% docs open_n_daily %}

The opening price of the numerator within that day, for the selling:buying asset prices ratio.

{% enddocs %}

{% docs open_d_daily %}

The opening price of the denominator within that day, for the selling:buying asset prices ratio.

{% enddocs %}

{% docs close_n_daily %}

The closing price of the numerator within that day, for the selling:buying asset prices ratio.

{% enddocs %}

{% docs close_d_daily %}

The closing price of the denominator within that day, for the selling:buying asset prices ratio.

{% enddocs %}

{% docs trade_count_weekly %}

The count of trades executed against the network during the past 7 days.

{% enddocs %}

{% docs asset_a_volume_weekly %}

The total amount of the asset being sold in all trades during the past 7 days.

{% enddocs %}

{% docs asset_b_volume_weekly %}

The total amount of the asset being bought in all trades during the past 7 days.

{% enddocs %}

{% docs avg_price_weekly %}

The total amount of the asset being bought in all trades divided by the total amount of the asset being sold in all trades, during the past 7 days.

{% enddocs %}

{% docs high_price_weekly %}

the highest price obtained from the ratio between denominator and numerator during the past 7 days, for the selling:buying asset price.

{% enddocs %}

{% docs low_price_weekly %}

the lowest price obtained from the ratio between denominator and numerator during the past 7 days, for the selling:buying asset price.

{% enddocs %}

{% docs open_n_weekly %}

The opening price of the numerator during the past 7 days, for the selling:buying asset prices ratio.

{% enddocs %}

{% docs open_d_weekly %}

The opening price of the denominator during the past 7 days, for the selling:buying asset prices ratio.

{% enddocs %}

{% docs close_n_weekly %}

The closing price of the numerator during the past 7 days, for the selling:buying asset prices ratio.

{% enddocs %}

{% docs close_d_weekly %}

The closing price of the denominator during the past 7 days, for the selling:buying asset prices ratio.

{% enddocs %}

{% docs trade_count_monthly %}

The count of trades executed against the network during the past 30 days.

{% enddocs %}

{% docs asset_a_volume_monthly %}

The total amount of the asset being sold in all trades during the past 30 days.

{% enddocs %}

{% docs asset_b_volume_monthly %}

The total amount of the asset being bought in all trades during the past 30 days.

{% enddocs %}

{% docs avg_price_monthly %}

The total amount of the asset being bought in all trades divided by the total amount of the asset being sold in all trades, during the past 30 days.

{% enddocs %}

{% docs high_price_monthly %}

the highest price obtained from the ratio between denominator and numerator during the past 30 days, for the selling:buying asset price.

{% enddocs %}

{% docs low_price_monthly %}

the lowest price obtained from the ratio between denominator and numerator during the past 30 days, for the selling:buying asset price.

{% enddocs %}

{% docs open_n_monthly %}

The opening price of the numerator during the past 30 days, for the selling:buying asset prices ratio.

{% enddocs %}

{% docs open_d_monthly %}

The opening price of the denominator during the past 30 days, for the selling:buying asset prices ratio.

{% enddocs %}

{% docs close_n_monthly %}

The closing price of the numerator during the past 30 days, for the selling:buying asset prices ratio.

{% enddocs %}

{% docs close_d_monthly %}

The closing price of the denominator during the past 30 days, for the selling:buying asset prices ratio.

{% enddocs %}

{% docs trade_count_yearly %}

The count of trades executed against the network during the past 365 days.

{% enddocs %}

{% docs asset_a_volume_yearly %}

The total amount of the asset being sold in all trades during the past 365 days.

{% enddocs %}

{% docs asset_b_volume_yearly %}

The total amount of the asset being bought in all trades during the past 365 days.

{% enddocs %}

{% docs avg_price_yearly%}

The total amount of the asset being bought in all trades divided by the total amount of the asset being sold in all trades, during the past 365 days.

{% enddocs %}

{% docs high_price_yearly %}

the highest price obtained from the ratio between denominator and numerator during the past 365 days, for the selling:buying asset price.

{% enddocs %}

{% docs low_price_yearly %}

the lowest price obtained from the ratio between denominator and numerator during the past 365 days, for the selling:buying asset price.

{% enddocs %}

{% docs open_n_yearly %}

The opening price of the numerator during the past 365 days, for the selling:buying asset prices ratio.

{% enddocs %}

{% docs open_d_yearly %}

The opening price of the denominator during the past 365 days, for the selling:buying asset prices ratio.

{% enddocs %}

{% docs close_n_yearly %}

The closing price of the numerator during the past 365 days, for the selling:buying asset prices ratio.

{% enddocs %}

{% docs close_d_yearly %}

The closing price of the denominator during the past 365 days, for the selling:buying asset prices ratio.

{% enddocs %}
