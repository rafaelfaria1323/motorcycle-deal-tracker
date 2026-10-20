-- Viewing checklist: a new favourite starts empty, its owner saves marks,
-- nobody else can, and only an object of reasonable size is stored.
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000c1'),
                                   ('00000000-0000-0000-0000-0000000000c2');

insert into public.listings (source, source_listing_id, url, motorcycle_id, brand, model, price)
select 'olx', 'chk', 'https://x/chk', m.id, m.brand, m.model, 7000
from public.motorcycles m where m.slug = 'yamaha-mt-07';

set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000c1';
set local test.jwt = '{"is_anonymous": false}';
insert into public.listing_favourites (listing_id)
select id from public.listings where source_listing_id = 'chk';

do $$
declare
  refused boolean;
begin
  assert (select checklist from public.listing_favourites) = '{}'::jsonb,
    'a new favourite has an empty checklist';

  update public.listing_favourites
  set checklist = '{"tyres": {"mark": "issue", "note": "DOT 2017"}, "documents": {"mark": "ok"}}';
  assert (select checklist -> 'tyres' ->> 'note' from public.listing_favourites) = 'DOT 2017',
    'the owner saves marks and notes';

  refused := false;
  begin
    update public.listing_favourites set checklist = '["tyres"]';
  exception when check_violation then refused := true;
  end;
  assert refused, 'a checklist that is not an object is refused';

  refused := false;
  begin
    update public.listing_favourites
    set checklist = jsonb_build_object('x', repeat('a', 40000));
  exception when check_violation then refused := true;
  end;
  assert refused, 'an oversized checklist is refused';
end $$;
reset role;

-- The other person can neither see nor change it.
set local role authenticated;
set local test.uid = '00000000-0000-0000-0000-0000000000c2';
update public.listing_favourites set checklist = '{}';
reset role;

do $$
begin
  assert (select checklist ? 'tyres' from public.listing_favourites
          where user_id = '00000000-0000-0000-0000-0000000000c1'),
    'another person changed nothing';
end $$;
