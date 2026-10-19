-- The collector's matching rules move from code into the catalog, so models
-- can be added with data and switched on or off from the app.
alter table public.motorcycles
  add column aliases        text[]   not null default '{}',
  add column excluded_words text[]   not null default '{}',
  add column engine_cc_min  smallint check (engine_cc_min > 0),
  add column engine_cc_max  smallint check (engine_cc_max > 0),
  add constraint motorcycles_engine_cc_range
    check (engine_cc_min is null or engine_cc_max is null
           or engine_cc_min <= engine_cc_max);

comment on column public.motorcycles.aliases is
  'Other names sellers use for the model, e.g. "Hornet 750".';
comment on column public.motorcycles.excluded_words is
  'Text that makes a listing another bike even though it names this model.';
comment on column public.motorcycles.is_active is
  'Tracked: the collector matches, scores and alerts on this model.';

-- The rules the collector had in code for the first four models.
update public.motorcycles set excluded_words = '{tracer}',
  engine_cc_min = 680, engine_cc_max = 710 where slug = 'yamaha-mt-07';
update public.motorcycles set
  engine_cc_min = 680, engine_cc_max = 710 where slug = 'yamaha-r7';
update public.motorcycles set excluded_words = '{650f}',
  engine_cc_min = 640, engine_cc_max = 660 where slug = 'honda-cb650r';
update public.motorcycles set excluded_words = '{650f}',
  engine_cc_min = 640, engine_cc_max = 660 where slug = 'honda-cbr650r';

-- Models the current searches already bring in (OLX MT-07, R/YZF and CB/CBR
-- from 2023). Off until switched on in the app; the next collection then
-- matches their listings, including those already stored.
insert into public.motorcycles
  (brand, model, slug, min_year, is_active, aliases, excluded_words,
   engine_cc_min, engine_cc_max)
values
  ('Yamaha', 'Tracer 7',     'yamaha-tracer-7',    2023, false,
   '{"Tracer 700","Tracer 07"}', '{}',       680, 710),
  ('Yamaha', 'R1',           'yamaha-r1',          2023, false,
   '{R1M}',                      '{}',       990, 1000),
  ('Yamaha', 'R3',           'yamaha-r3',          2023, false,
   '{}',                         '{}',       315, 330),
  ('Yamaha', 'R9',           'yamaha-r9',          2023, false,
   '{}',                         '{}',       880, 900),
  ('Honda',  'CB125R',       'honda-cb125r',       2023, false,
   '{}',                         '{125f}',   120, 130),
  ('Honda',  'CB300R',       'honda-cb300r',       2023, false,
   '{}',                         '{300f}',   280, 290),
  ('Honda',  'CBR500R',      'honda-cbr500r',      2023, false,
   '{}',                         '{}',       465, 475),
  ('Honda',  'CB750 Hornet', 'honda-cb750-hornet', 2023, false,
   '{"Hornet 750"}',             '{}',       750, 760),
  ('Honda',  'CBR600RR',     'honda-cbr600rr',     2023, false,
   '{}',                         '{}',       595, 600);

-- Switches a model on or off. Only a signed-in account may do it (visitors
-- get an anonymous session); the app's only accounts are the owner's.
create function public.set_model_tracked(p_motorcycle_id uuid, p_tracked boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Sign in to choose the tracked models'
      using errcode = '42501';
  end if;

  update public.motorcycles
  set is_active = p_tracked, updated_at = now()
  where id = p_motorcycle_id;

  if not found then
    raise exception 'Unknown model %', p_motorcycle_id using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.set_model_tracked(uuid, boolean)
  from public, anon;
grant execute on function public.set_model_tracked(uuid, boolean)
  to authenticated;
