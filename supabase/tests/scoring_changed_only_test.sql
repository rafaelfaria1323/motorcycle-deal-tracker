-- recalculate_deal_scores writes only the listings whose score changed
-- (20261116090000_faster_scoring_runs.sql): a second run with nothing new
-- rewrites no row and still returns every listing scored; a price change
-- is written; a listing that leaves the market loses its score. The risk
-- view (listing_risk) gives the same score and reasons the run stores.
insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model,
                             year, mileage, price, location, description, status)
select 'olx', v.sid, 'https://x/' || v.sid, m.id, m.brand, m.model,
       v.year, v.km, v.price, 'Porto', 'Revisões feitas, sempre na garagem.', 'active'
from public.motorcycles m,
     (values ('s1', 2021, 12000, 6500), ('s2', 2022, 9000, 6900),
             ('s3', 2021, 15000, 6200), ('s4', 2023, 5000, 7400),
             ('s5', 2020, 20000, 5600)) v(sid, year, km, price)
where m.slug = 'yamaha-mt-07';

create temporary table listing_versions as
select id, ctid::text as version from public.listings where false;

do $$
declare
  first_count integer := public.recalculate_deal_scores();
  n integer;
  rewritten integer;
  before_score smallint;
begin
  assert first_count >= 5, format('listings scored, got %s', first_count);
  assert (select bool_and(deal_score is not null and scored_at is not null)
          from public.listings where source_listing_id like 's_'),
    'every new listing scored';
  assert (select bool_and((score_breakdown ->> 'market_listing_count')::int = 4)
          from public.listings where source_listing_id like 's_'),
    'four other ads to compare with';

  insert into listing_versions select id, ctid::text from public.listings;
  n := public.recalculate_deal_scores();
  assert n = first_count, format('the same count, got %s vs %s', n, first_count);
  select count(*) into rewritten
  from public.listings l join listing_versions v on v.id = l.id
  where l.ctid::text <> v.version;
  assert rewritten = 0, format('nothing changed, %s row(s) rewritten', rewritten);

  -- A cheaper price is scored again.
  select deal_score into before_score from public.listings where source_listing_id = 's1';
  update public.listings set price = 5000 where source_listing_id = 's1';
  perform public.recalculate_deal_scores();
  assert (select deal_score from public.listings where source_listing_id = 's1') > before_score,
    'the drop raises the score';

  -- The view reads the same risk the run stored.
  assert not exists (
    select 1 from public.listings l
    join public.listing_risk_scores r on r.listing_id = l.id
    where l.source_listing_id like 's_'
      and (r.risk_score is distinct from l.risk_score
           or r.reasons is distinct from
              array(select jsonb_array_elements_text(l.score_breakdown -> 'risk_reasons')))),
    'the risk view and the stored risk agree';

  -- Gone: no score.
  update public.listings set status = 'removed' where source_listing_id = 's5';
  perform public.recalculate_deal_scores();
  assert (select deal_score is null and scored_at is null
          from public.listings where source_listing_id = 's5'), 'a gone ad loses its score';
end $$;
