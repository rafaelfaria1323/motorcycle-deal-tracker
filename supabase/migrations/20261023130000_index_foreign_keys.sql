-- Foreign keys without an index (found by splinter, make sql-lint): a
-- delete or key change on the referenced table scanned the whole
-- referencing table, e.g. deleting a saved search read every alert.
create index if not exists alerts_price_history_idx on public.alerts (price_history_id);
create index if not exists alerts_saved_search_idx on public.alerts (saved_search_id);
create index if not exists listings_relisted_from_idx on public.listings (relisted_from);
create index if not exists saved_searches_motorcycle_idx on public.saved_searches (motorcycle_id);
create index if not exists user_home_place_key_idx on public.user_home (place_key);
