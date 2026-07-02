select
    coin_id,
    symbol,
    name,
    current_price,
    price_change_percentage_24h,
    market_cap_rank
from {{ ref('stg_coin_prices') }}
where price_change_percentage_24h is not null
order by price_change_percentage_24h desc
limit 10
