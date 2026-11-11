-- N.55: the weekly description check's samples. Matched, non-duplicate ads
-- of the week with a description of 80+ characters, with what the rules
-- read; unmatched titles once each; only the service role reads them.
insert into public.listings
  (source, source_listing_id, url, motorcycle_id, brand, model, variant,
   description, first_seen_at)
select 'olx', v.sid, 'https://x/' || v.sid,
       case when v.matched then (select id from public.motorcycles where slug = 'yamaha-mt-07') end,
       'Yamaha', v.model, v.variant, v.description, now() - v.age
from (values
  ('fresh', true, 'MT-07', 'MT-07 ABS',
   'Mota em bom estado, com 12.000 km, teve uma queda ligeira, tem quickshifter e punhos aquecidos.',
   interval '1 day'),
  ('short', true, 'MT-07', 'MT-07', 'Vendo mota.', interval '1 day'),
  ('old', true, 'MT-07', 'MT-07',
   'Mota em bom estado, sempre na garagem, revisões feitas na marca, nunca caiu nem teve acidentes.',
   interval '20 days'),
  ('other1', false, 'MT-09', 'Tracer 9 GT', null, interval '1 day'),
  ('other2', false, 'MT-09', 'tracer 9 gt', null, interval '2 days'),
  ('other3', false, 'XSR', 'XSR 700', null, interval '30 days')
) v(sid, matched, model, variant, description, age);

insert into public.listings
  (source, source_listing_id, url, motorcycle_id, brand, model, description, duplicate_of)
select 'standvirtual', 'copy', 'https://x/copy', motorcycle_id, brand, model, description, id
from public.listings where source_listing_id = 'fresh';

do $$
declare
  r record;
begin
  assert (select count(*) from public.text_audit_sample(now() - interval '7 days', 10)) = 1,
    'only the week''s matched originals with a real description';
  select * into r from public.text_audit_sample(now() - interval '7 days', 10);
  assert r.url = 'https://x/fresh', 'the fresh ad';
  assert 'possible_accident' = any(r.signals), 'the rules'' signals come with it';
  assert r.extras @> array['heated_grips', 'quickshifter'], 'and its extras';
  assert r.mileage_in_text = 12000, 'and the km read from the text';
  assert (select count(*) from public.text_audit_sample(now() - interval '7 days', 0)) = 0,
    'the limit holds';

  assert (select count(*) from public.unmatched_title_sample(now() - interval '7 days', 10)) = 1,
    'one row per title, only the week''s';
  assert (select count(*) from public.unmatched_title_sample(now() - interval '60 days', 10)) = 2,
    'older titles with an older start';
end $$;

set local role authenticated;
do $$
begin
  perform public.text_audit_sample(now(), 1);
  assert false, 'the app read the sample';
exception when insufficient_privilege then null;
end $$;
reset role;
