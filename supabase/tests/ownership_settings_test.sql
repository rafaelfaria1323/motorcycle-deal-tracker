-- Ownership settings: defaults, limits, and each person sees and changes
-- only their own.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000d1'),
                                   ('00000000-0000-0000-0000-0000000000d2');

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000d1';
insert into public.ownership_settings (insurance_per_year) values (240);

do $$
declare
  refused boolean;
begin
  assert (select (km_per_year, years_to_keep) = (5000, 3::smallint)
          from public.ownership_settings),
    'km per year and years to keep start at the defaults';

  -- Saving again replaces the row (the app upserts).
  insert into public.ownership_settings (insurance_per_year, km_per_year, years_to_keep)
  values (300, 8000, 5)
  on conflict (user_id) do update
    set insurance_per_year = excluded.insurance_per_year,
        km_per_year = excluded.km_per_year,
        years_to_keep = excluded.years_to_keep;
  assert (select (insurance_per_year, km_per_year, years_to_keep) = (300, 8000, 5::smallint)
          from public.ownership_settings),
    'an upsert updates the row';

  refused := false;
  begin
    update public.ownership_settings set years_to_keep = 0;
  exception when check_violation then refused := true;
  end;
  assert refused, 'zero years is refused';

  refused := false;
  begin
    update public.ownership_settings set insurance_per_year = -1;
  exception when check_violation then refused := true;
  end;
  assert refused, 'a negative insurance is refused';
end $$;
reset role;

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000d2';
do $$
declare
  refused boolean := false;
begin
  assert (select count(*) from public.ownership_settings) = 0, 'another person sees none';
  update public.ownership_settings set km_per_year = 1;
  begin
    insert into public.ownership_settings (user_id)
    values ('00000000-0000-0000-0000-0000000000d1');
  exception when insufficient_privilege then refused := true;
  end;
  assert refused, 'settings for someone else are refused';
end $$;
reset role;

do $$
begin
  assert (select km_per_year from public.ownership_settings
          where user_id = '00000000-0000-0000-0000-0000000000d1') = 8000,
    'another person changed nothing';
end $$;
