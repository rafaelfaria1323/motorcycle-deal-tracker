-- Null means "not scored yet". Computed by the deal engine (Sprint 4).
alter table public.listings
  add column deal_score smallint check (deal_score between 0 and 100);

create index listings_deal_score_idx on public.listings (deal_score desc nulls last);