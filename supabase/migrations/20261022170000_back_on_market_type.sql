-- "Voltou ao mercado": a bike someone followed comes back in a new ad.
-- A new enum value can't be used in the transaction that adds it, so the
-- alerts themselves come in the next migration.
alter type public.alert_type add value if not exists 'back_on_market';
