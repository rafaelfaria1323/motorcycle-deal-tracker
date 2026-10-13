-- Price component of the Deal Score (0-100). 50 = priced at market median.
-- Pure function: no table access, so it is easy to test and reuse.
create function public.price_score(
  p_price               numeric,
  p_market_price        numeric,
  p_points_per_percent  numeric default 5
)
returns smallint
language sql
immutable
set search_path = ''
as $$
  select case
    when p_price is null or p_market_price is null or p_market_price <= 0
      then null
    else greatest(0, least(100, round(
      50 + (p_market_price - p_price) / p_market_price * 100 * p_points_per_percent
    )))::smallint
  end
$$;

-- Price score per live listing, with the numbers the explanation (4.8) needs.
create view public.listing_price_scores
with (security_invoker = true) as
select
  l.id                                                         as listing_id,
  l.motorcycle_id,
  l.price,
  s.median_price                                               as market_price,
  s.listing_count,
  round((s.median_price - l.price) / s.median_price * 100, 1)  as pct_below_market,
  public.price_score(l.price, s.median_price)                  as price_score,
  s.listing_count >= 3                                         as is_reliable
from public.listings l
join public.model_market_stats s on s.motorcycle_id = l.motorcycle_id
where l.status in ('active', 'price_changed')
  and l.price is not null;