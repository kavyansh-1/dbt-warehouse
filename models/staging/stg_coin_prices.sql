select
    id as coin_id,
    symbol,
    name, 
    current_price,
    market_cap,
    market_cap_rank,
    total_volume,
    price_change_percentage_24h,
    last_updated
from {{ source('public','coin_prices')}}
