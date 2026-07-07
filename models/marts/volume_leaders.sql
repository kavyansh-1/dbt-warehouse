select
    coin_id,
    symbol,
    name,
    current_price,
    total_volume,
    market_cap_rank,
    price_change_percentage_24h,
    loaded_at
from {{ ref('silver_coin_prices') }}
where data_quality_flag = 'valid'
  and total_volume is not null
order by total_volume desc
limit 10
