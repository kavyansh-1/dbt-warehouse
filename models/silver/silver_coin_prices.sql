select
    coin_id,
    symbol,
    upper(symbol) as symbol_upper,
    name,
    current_price::numeric as current_price,
    market_cap,
    market_cap_rank,
    total_volume,
    price_change_percentage_24h,
    last_updated,
    loaded_at,
    'silver' as data_tier,
    case
        when current_price::numeric <= 0 then 'flagged'
        when market_cap is null then 'flagged'
        when price_change_percentage_24h is null then 'flagged'
        else 'valid'
    end as data_quality_flag
from {{ ref('stg_coin_prices') }}
where current_price is not null
  and coin_id is not null
  and last_updated is not null
