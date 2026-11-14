-- A favourite whose ad gives no year heard of none of its model's recalls,
-- though the app shows them all as applying (`model_recalls`: no year,
-- every recall applies) and puts them on the viewing checklist. The same
-- rule here.
create or replace function public.pending_recall_notices(p_at timestamptz)
returns table (
  user_id     uuid,
  case_number text,
  bike_id     uuid,
  listing_id  uuid,
  brand       text,
  model       text,
  year        integer,
  recall_name text,
  recall_code text,
  danger_en   text,
  danger_pt   text
)
language sql
stable
security definer
set search_path = ''
as $$
  with bikes as (
    select b.user_id, b.id as bike_id, b.listing_id, b.motorcycle_id,
           b.year::integer as year, b.created_at, 0 as rank
    from public.owned_bikes b
    union all
    select f.user_id, null, f.listing_id, l.motorcycle_id,
           l.year, f.created_at, 1
    from public.listing_favourites f
    join public.listings l on l.id = f.listing_id
    where l.status in ('active', 'price_changed')
      and l.motorcycle_id is not null
  )
  select distinct on (k.user_id, r.case_number)
         k.user_id, r.case_number, k.bike_id, k.listing_id,
         m.brand, m.model, k.year,
         concat_ws(' ', nullif(r.product, 'Motorcycle'), r.name),
         r.recall_code, r.danger_en, r.danger_pt
  from bikes k
  join auth.users u on u.id = k.user_id and not coalesce(u.is_anonymous, false)
  join public.motorcycles m on m.id = k.motorcycle_id
  join public.vehicle_recalls r on public.recall_is_of_model(r, m)
  where r.stored_at > k.created_at
    and r.published_on >= (p_at at time zone 'Europe/Lisbon')::date
                          - public.recall_notice_days()
    and (k.year is null or r.from_year is null
         or k.year between r.from_year and r.to_year + 1)
    and not exists (select 1 from public.recall_notices n
                    where n.user_id = k.user_id and n.case_number = r.case_number)
    and not public.account_quiet_at(k.user_id, p_at)
  order by k.user_id, r.case_number, k.rank, k.created_at desc
$$;
revoke all on function public.pending_recall_notices(timestamptz)
  from public, anon, authenticated;
