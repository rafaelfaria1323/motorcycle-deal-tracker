-- Some sellers leave the site's mileage field empty and write the km in the
-- description ("Mota com 12.000 km"). Such an ad was scored as hidden
-- mileage (risk "no_mileage", a middling mileage slice, no comparables).
-- When the field is empty the mileage is now read from the text, and
-- mileage_from_text says so (the app tells it on the listing page).

alter table public.listings
  add column mileage_from_text boolean not null default false;

-- The bike's km in a description, or null when the text doesn't say it
-- clearly. A number counts when it is followed by "km" / "kms" /
-- "quilómetros" ("12.000 km", "12 mil km", "15000kms") or follows a label
-- ("Quilometragem: 12000", "kms: 12.000"). Numbers about something else
-- are left out by the words before them in the same clause (tyres,
-- services, chain, warranty, "aos 10.000 km", "a cada", "mais de") or
-- after them ("km/h", "por mês", "de autonomia"). Numbers after "tem",
-- "com", "apenas", "só" or a label win; otherwise the one number left is
-- taken. Two different values are a doubt: null.
create function public.mileage_in_text(p_description text)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  d      constant text := lower(coalesce(p_description, ''));
  num    constant text := '(\d{1,3}(?:[.\s]\d{3})+|\d+(?:[.,]\d{1,2})?)';
  unit   constant text :=
    '\s*(mil)?\s*(?:km|kms|quil[oó]metros)\M'
    '(?!\s*(?:/|por\M|p/|h\M|de\s+autonomia))';
  other  constant text :=
    '(pneu|revis|[óo]leo|corrente|\mkit|garantia|autonomia|pr[oó]xim|troc'
    '|mud[aeo]|embraiag|pastilh|trav[õoã]|filtro|\mvelas?\M|\mcada\M'
    '|[uú]ltim|manuten|servi[çc]o|feit[ao]|bateria|viage|percurso'
    '|\m(?:aos|dos|at[eé]|h[aá]|faz)\s*$|(?:menos|mais)\s+de\s*$)';
  leads  constant text :=
    '(?:\mtem|\mcom|apenas|\ms[oó]|c/|quilometragem|marca)\s*$';
  r      record;
  n      numeric;
  led    integer[] := '{}'::integer[];
  plain  integer[] := '{}'::integer[];
begin
  -- "... com 12.000 km": the clause before the number, the number, "mil".
  for r in
    select x.m
    from regexp_matches(d, '([^.,;:!?\n]*?)\m' || num || unit, 'g') as x(m)
  loop
    continue when right(r.m[1], 50) ~ other;
    n := public.mileage_number(r.m[2], r.m[3] is not null);
    continue when n is null;
    if r.m[1] ~ leads then led := led || n::integer;
    else plain := plain || n::integer;
    end if;
  end loop;

  -- "Quilometragem: 12000", "Kms: 12.000".
  for r in
    select x.m
    from regexp_matches(d,
      '(?:quilometragem\s*[:=-]?|(?:quil[oó]metros|\mkms?)\s*[:=-])\s*'
      || num || '\s*(mil)?\M', 'g') as x(m)
  loop
    n := public.mileage_number(r.m[1], r.m[2] is not null);
    continue when n is null;
    led := led || n::integer;
  end loop;

  if cardinality(led) > 0 then
    plain := led;
  end if;
  if (select count(distinct v) from unnest(plain) v) = 1 then
    return plain[1];
  end if;
  return null;
end;
$$;

-- "12.000" -> 12000, "12,5" with "mil" -> 12500; a decimal without "mil"
-- ("12,5 km") or more than 300 000 km is not a bike's mileage.
create function public.mileage_number(p_number text, p_thousands boolean)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select v
  from (
    select case
      when p_thousands then
        replace(regexp_replace(p_number, '\s', '', 'g'), ',', '.')::numeric
        * 1000
      when p_number ~ '^\d+[.,]\d{1,2}$' then null
      else regexp_replace(p_number, '[.\s]', '', 'g')::numeric
    end as v
  ) x
  where v <= 300000
$$;

revoke all on function public.mileage_in_text(text)
  from public, anon, authenticated;
revoke all on function public.mileage_number(text, boolean)
  from public, anon, authenticated;

-- Fills an empty mileage from the description, on insert (OLX's results
-- hold the description) and when the description arrives or changes
-- (Standvirtual's listing page, apply_listing_details). A mileage read
-- from the text is read again when the text changes.
create function public.fill_mileage_from_text()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.mileage is null or new.mileage_from_text then
    new.mileage := public.mileage_in_text(new.description);
    new.mileage_from_text := new.mileage is not null;
  end if;
  return new;
end;
$$;

revoke all on function public.fill_mileage_from_text()
  from public, anon, authenticated;

create trigger listings_mileage_from_text
  before insert or update of description, mileage on public.listings
  for each row execute function public.fill_mileage_from_text();

-- The listings already stored (the next run scores them again).
update public.listings
set mileage = public.mileage_in_text(description),
    mileage_from_text = true
where mileage is null
  and description is not null
  and public.mileage_in_text(description) is not null;
