-- A price that went up (N.125): its own alert type. Alone in its file: a
-- new enum value can't be used in the transaction that adds it.
alter type public.alert_type add value 'price_increase';
