-- Good deals that went fast (N.68): a model's ads gone in the last
-- p_days that likely sold (exit_kind, N.61: not expired, relisted or
-- still on the other site), not duplicates, at a real price, each with
-- its last Deal Score and how long the bike was on sale (from the
-- earliest of its first ad's publication, the ad's publication and
-- when we first saw it, to when it was last seen). The app picks the
-- good ones (Deal Score 80+) and compares their time on sale with the
-- rest. Shown only; never a score.
create function public.gone_deals(
  p_motorcycle_id uuid,
  p_days integer default 90
)
returns table (
  listing_id uuid,
  year integer,
  mileage integer,
  price numeric,
  deal_score integer,
  days_listed integer,
  gone_at timestamptz
)
language sql
stable
set search_path = ''
as $$
  select l.id,
         l.year::integer,
         l.mileage,
         l.price,
         l.last_deal_score::integer,
         greatest(
           floor(extract(epoch from
             l.last_seen_at
             - least(l.relisted_since, l.published_at, l.first_seen_at)
           ) / 86400),
           0
         )::integer,
         l.last_seen_at
  from public.listings l
  where l.motorcycle_id = p_motorcycle_id
    and l.status in ('removed', 'sold')
    and l.last_seen_at >= now() - make_interval(days => p_days)
    and l.duplicate_of is null
    and l.price >= 300
    and public.exit_kind(l) in ('sold_in_text', 'likely_sold')
  order by l.last_seen_at desc, l.id;
$$;

revoke all on function public.gone_deals(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.gone_deals(uuid, integer)
  to anon, authenticated;
