-- Viewing checklist (15.3): what the owner checked when seeing a favourite
-- bike, item by item. The list of items lives in the app
-- (viewing_checklist.dart); here only the marks, keyed by item:
-- {"tyres": {"mark": "issue", "note": "DOT 2017"}, "documents": {"mark": "ok"}}.
-- Unknown keys are kept and ignored by the app, so items can change later.
alter table public.listing_favourites
  add column checklist jsonb not null default '{}'::jsonb
    constraint listing_favourites_checklist_object
      check (jsonb_typeof(checklist) = 'object'
             and octet_length(checklist::text) <= 32000);

comment on column public.listing_favourites.checklist is
  'Viewing checklist marks per item key: {"mark": "ok"|"issue", "note": text}.';
