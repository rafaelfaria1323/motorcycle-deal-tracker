-- Replace each number with the price you verified on the official site,
-- and use the date you checked it.
update public.motorcycles set new_price_reference = 10640.00, new_price_checked_at = '2026-10-13' where slug = 'yamaha-r7';
update public.motorcycles set new_price_reference = 8250.00, new_price_checked_at = '2026-10-13' where slug = 'yamaha-mt-07';
update public.motorcycles set new_price_reference = 9500.00, new_price_checked_at = '2026-10-13' where slug = 'honda-cb650r';
update public.motorcycles set new_price_reference = 10450.00, new_price_checked_at = '2026-10-13' where slug = 'honda-cbr650r';