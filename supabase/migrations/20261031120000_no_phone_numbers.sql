-- "Never store private sellers' names or anyone's phone numbers": OLX's
-- titles had their phone numbers removed (OlxMapper), but descriptions
-- were kept as the seller wrote them, and sellers often write their
-- number there ("Contacto 912 345 678"). Every listing's description,
-- version and dealer name now loses anything shaped like a Portuguese
-- phone number on the way in, whatever the source, and the rows already
-- stored are cleaned once.

-- [p_text] without Portuguese phone numbers: nine digits starting with 2
-- (landlines) or 9 (mobiles), written together or grouped 3-3-3, 3-2-2-2
-- or 2-3-4 (spaces, dots or dashes), with or without +351 / 00351 in
-- front, and no digit right before or after (a longer number is something
-- else). The spaces left around a removed number are folded.
create function public.without_phone_numbers(p_text text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  phone constant text :=
    '(?<![0-9])(?:(?:\+|00)?351[ .-]?)?(?:'
    || '[29][0-9]{2}[ .-]?[0-9]{3}[ .-]?[0-9]{3}'
    || '|[29][0-9]{2}[ .-][0-9]{2}[ .-][0-9]{2}[ .-][0-9]{2}'
    || '|[29][0-9][ .-][0-9]{3}[ .-][0-9]{4}'
    || ')(?![0-9])';
  t text;
begin
  if p_text is null or p_text !~ phone then
    return p_text;
  end if;
  t := regexp_replace(p_text, phone, '', 'g');
  t := regexp_replace(t, '[ \t]{2,}', ' ', 'g');
  t := regexp_replace(t, '[ \t]+(\n|$)', '\1', 'g');
  t := regexp_replace(t, '(^|\n)[ \t]+', '\1', 'g');
  t := btrim(t);
  return nullif(t, '');
end;
$$;

revoke all on function public.without_phone_numbers(text)
  from public, anon, authenticated;

create function public.strip_phone_numbers()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.description := public.without_phone_numbers(new.description);
  new.variant := public.without_phone_numbers(new.variant);
  new.seller_name := public.without_phone_numbers(new.seller_name);
  return new;
end;
$$;

revoke all on function public.strip_phone_numbers()
  from public, anon, authenticated;

-- "listings_a_": before triggers run in name order, and this one must come
-- first, so the text signals, colour and mileage read the cleaned text and
-- an unchanged description sent again with its number counts as unchanged.
create trigger listings_a_strip_phone_numbers
  before insert or update of description, variant, seller_name
  on public.listings
  for each row execute function public.strip_phone_numbers();

-- The rows already stored (the trigger cleans them).
update public.listings
set description = description,
    variant = variant,
    seller_name = seller_name
where description ~ '[29][0-9 .-]{7,12}[0-9]'
   or variant ~ '[29][0-9 .-]{7,12}[0-9]'
   or seller_name ~ '[29][0-9 .-]{7,12}[0-9]';
