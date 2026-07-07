select
    coin_id,
    symbol,
    name,
    current_price,
    market_cap,
    market_cap_rank,
    case
        when market_cap >= 10000000000 then 'Large Cap'
        when market_cap >= 1000000000 then 'Mid Cap'
        else 'Small Cap'
    end as market_cap_tier,
    data_quality_flag,
    loaded_at
from {{ ref('silver_coin_prices') }}
where data_quality_flag = 'valid'
order by market_cap desc
