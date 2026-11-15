-- B.4 (docs/bug-hunt.md 3.1): models added later join their platform
-- group. The groups of N.106b (20261115130000_similar_models.sql) were set
-- once, by an update when that migration ran, so an "XSR 700" added from
-- the app afterwards stayed alone. The table of names now lives in
-- similar_group_of(), which a trigger asks for every new model (unless it
-- comes with a group), and which fills the models added since.

create function public.similar_group_of(p_brand text, p_model text)
returns text
language sql
immutable
set search_path = ''
as $$
  select v.grp
  from (values
    ('yamaha', 'mt07',       'yamaha-cp2'),
    ('yamaha', 'r7',         'yamaha-cp2'),
    ('yamaha', 'yzfr7',      'yamaha-cp2'),
    ('yamaha', 'tracer7',    'yamaha-cp2'),
    ('yamaha', 'tracer700',  'yamaha-cp2'),
    ('yamaha', 'xsr700',     'yamaha-cp2'),
    ('yamaha', 'mt09',       'yamaha-cp3'),
    ('yamaha', 'r9',         'yamaha-cp3'),
    ('yamaha', 'yzfr9',      'yamaha-cp3'),
    ('yamaha', 'tracer9',    'yamaha-cp3'),
    ('yamaha', 'tracer9gt',  'yamaha-cp3'),
    ('yamaha', 'xsr900',     'yamaha-cp3'),
    ('yamaha', 'mt03',       'yamaha-321'),
    ('yamaha', 'r3',         'yamaha-321'),
    ('yamaha', 'yzfr3',      'yamaha-321'),
    ('honda',  'cb650r',     'honda-650-four'),
    ('honda',  'cbr650r',    'honda-650-four'),
    ('honda',  'cb650f',     'honda-650-four'),
    ('honda',  'cbr650f',    'honda-650-four'),
    ('honda',  'cbr500r',    'honda-500-twin'),
    ('honda',  'cb500f',     'honda-500-twin'),
    ('honda',  'cb500x',     'honda-500-twin'),
    ('honda',  'cb500hornet','honda-500-twin'),
    ('honda',  'nx500',      'honda-500-twin')
  ) as v(brand_key, model_key, grp)
  where v.brand_key = public.name_key(p_brand)
    and v.model_key = public.name_key(p_model)
$$;

revoke all on function public.similar_group_of(text, text) from public, anon, authenticated;

create function public.fill_similar_group()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.similar_group := coalesce(new.similar_group,
                                public.similar_group_of(new.brand, new.model));
  return new;
end;
$$;

revoke all on function public.fill_similar_group() from public, anon, authenticated;

create trigger motorcycles_similar_group
  before insert on public.motorcycles
  for each row execute function public.fill_similar_group();

-- The models added since N.106b.
update public.motorcycles m
set similar_group = public.similar_group_of(m.brand, m.model)
where m.similar_group is null
  and public.similar_group_of(m.brand, m.model) is not null;
