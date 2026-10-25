-- Card customization (15.31), shared by Ofertas and Favoritos on every device.
create table public.listing_card_preferences (
  user_id uuid primary key default auth.uid()
    references auth.users (id) on delete cascade,
  visible_fields text[] not null default array[
    'source', 'deal_score', 'price_change', 'year', 'mileage', 'location',
    'preferred_colour'
  ],
  constraint listing_card_preferences_known_fields check (
    visible_fields <@ array[
      'source', 'deal_score', 'price_change', 'year', 'mileage', 'location',
      'preferred_colour', 'risk_score', 'seller_type', 'first_seen_at'
    ]::text[]
    and coalesce(array_ndims(visible_fields), 1) = 1
  )
);

alter table public.listing_card_preferences enable row level security;

revoke all on public.listing_card_preferences from public, anon, authenticated;
grant select, insert, update on public.listing_card_preferences to authenticated;

create policy "Accounts manage their own card preferences"
  on public.listing_card_preferences
  for all to authenticated
  using (
    user_id = (select auth.uid())
    and not (select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true))
  )
  with check (
    user_id = (select auth.uid())
    and not (select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true))
  );
