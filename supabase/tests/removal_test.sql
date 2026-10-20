-- Removal is per search: only the searches read in full lose the listings
-- they no longer show, unkeyed listings only when asked, never another
-- site's, and never more than half at once unless forced.
insert into public.listings (source, source_listing_id, url, brand, model, price, search_key)
values ('olx', 'r1', 'https://x/r1', 'Yamaha', 'MT-07', 6000, 'A'),
       ('olx', 'r2', 'https://x/r2', 'Yamaha', 'MT-07', 6000, 'A'),
       ('olx', 'r5', 'https://x/r5', 'Yamaha', 'MT-07', 6000, 'A'),
       ('olx', 'r6', 'https://x/r6', 'Yamaha', 'MT-07', 6000, 'A'),
       ('olx', 'r3', 'https://x/r3', 'Honda', 'CB650R', 7000, 'B'),
       ('olx', 'r4', 'https://x/r4', 'Honda', 'CB650R', 7000, null),
       ('standvirtual', 'r6', 'https://y/r6', 'Yamaha', 'MT-07', 6000, 'A');

do $$
declare
  removed int;
  refused boolean;
begin
  refused := false;
  begin
    perform public.mark_removed_listings('olx', array[]::text[]);
  exception when others then
    refused := sqlerrm like 'Refusing%no listings%';
  end;
  assert refused, 'an empty import removes nothing';

  removed := public.mark_removed_listings('olx', array['r1', 'r2', 'r5'], 0.5, array['A'], false);
  assert removed = 1, format('one listing gone from search A, got %s', removed);
  assert (select status from public.listings where source = 'olx' and source_listing_id = 'r6') = 'removed',
    'r6 is removed';
  assert (select last_checked_at from public.listings where source = 'olx' and source_listing_id = 'r6') = now(),
    'the removal is dated';
  assert (select count(*) from public.listings where status = 'removed') = 1,
    'other searches, unkeyed listings and the other site keep theirs';

  refused := false;
  begin
    perform public.mark_removed_listings('olx', array['r1'], 0.5, array['A'], false);
  exception when others then
    refused := sqlerrm like 'Refusing to remove 2 of 3%';
  end;
  assert refused, 'more than half of a search at once is refused';
  assert (select count(*) from public.listings where status = 'removed') = 1,
    'a refusal changes nothing';

  removed := public.mark_removed_listings('olx', array['r1'], 1.0, array['A'], false);
  assert removed = 2, format('forced, two more removed, got %s', removed);

  removed := public.mark_removed_listings('olx', array['r3'], 0.5, array['B'], true);
  assert removed = 1, format('the unkeyed listing goes with the complete run, got %s', removed);
  assert (select status from public.listings where source_listing_id = 'r4') = 'removed',
    'r4 (no search key) is removed';
  assert (select status from public.listings where source = 'standvirtual') = 'active',
    'the other site''s listing with the same id stays';
end $$;
