-- Model specifications (N.75): the catalog's figures, readable by everyone,
-- and the rider's height in the owner-only ownership_settings.
do $$
begin
  assert (select count(*) from public.motorcycles
          where slug in ('yamaha-mt-07', 'yamaha-r7', 'honda-cb650r', 'honda-cbr650r')
            and torque_nm is not null and weight_kg is not null
            and seat_height_mm is not null and tank_l is not null) = 4;
  assert (select seat_height_mm from public.motorcycles where slug = 'yamaha-mt-07') = 805;
  begin
    update public.motorcycles set seat_height_mm = 300 where slug = 'yamaha-mt-07';
    assert false, 'a seat height of 300 mm was stored';
  exception when check_violation then null;
  end;
end $$;

insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a1'),
                                   ('00000000-0000-0000-0000-0000000000a2');

-- Everyone reads the specs.
set local role anon;
do $$
begin
  assert (select tank_l from public.motorcycles where slug = 'honda-cb650r') = 15.4;
end $$;
reset role;

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000a1';
set local test.jwt = '{"is_anonymous": false}';
do $$
begin
  insert into public.ownership_settings (rider_height_cm) values (178);
  assert (select rider_height_cm from public.ownership_settings) = 178;
  begin
    update public.ownership_settings set rider_height_cm = 300 where true;
    assert false, 'a height of 300 cm was stored';
  exception when check_violation then null;
  end;
end $$;

-- Another account sees no one else's height.
set local test.uid = '00000000-0000-0000-0000-0000000000a2';
do $$
begin
  assert (select count(*) from public.ownership_settings) = 0;
end $$;
reset role;
