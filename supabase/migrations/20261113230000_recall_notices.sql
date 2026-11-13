-- Recall notifications (N.87): when Safety Gate brings a recall that can
-- cover a bike of the account's own ("A minha mota") or a live favourite
-- (same model, a year within its production years), the collector pushes
-- it to the account's devices once, outside quiet hours. Only recalls
-- published in the last 60 days and stored after the bike or favourite
-- was added: the reports read back to 2010 never notify, and what was
-- already there when it was added is on its page.

-- When each recall was stored; those stored before this migration stay
-- null and never notify (they are on the pages already).
alter table public.vehicle_recalls add column stored_at timestamptz;
alter table public.vehicle_recalls alter column stored_at set default now();

-- The recalls each account was told of: one notification per account and
-- recall, whichever of its bikes it covers. No API access.
create table public.recall_notices (
  user_id     uuid not null references auth.users (id) on delete cascade,
  case_number text not null references public.vehicle_recalls (case_number) on delete cascade,
  noticed_at  timestamptz not null default now(),
  primary key (user_id, case_number)
);

create index recall_notices_case_number on public.recall_notices (case_number);

alter table public.recall_notices enable row level security;
revoke all on public.recall_notices from public, anon, authenticated;

-- How long after its publication a recall still notifies.
create function public.recall_notice_days()
returns integer
language sql
immutable
set search_path = ''
as $$ select 60 $$;
revoke all on function public.recall_notice_days() from public, anon, authenticated;

-- The recalls to tell of at [p_at] (the run's time): one row per account
-- and recall, its own bike first, else the favourite seen most recently;
-- accounts in their quiet hours wait. `listing_id` is the favourite's ad
-- (or the ad the bike was bought from), `bike_id` the owned bike's.
create function public.pending_recall_notices(p_at timestamptz)
returns table (
  user_id     uuid,
  case_number text,
  bike_id     uuid,
  listing_id  uuid,
  brand       text,
  model       text,
  year        integer,
  recall_name text,
  recall_code text,
  danger_en   text,
  danger_pt   text
)
language sql
stable
security definer
set search_path = ''
as $$
  with bikes as (
    select b.user_id, b.id as bike_id, b.listing_id, b.motorcycle_id,
           b.year::integer as year, b.created_at, 0 as rank
    from public.owned_bikes b
    union all
    select f.user_id, null, f.listing_id, l.motorcycle_id,
           l.year, f.created_at, 1
    from public.listing_favourites f
    join public.listings l on l.id = f.listing_id
    where l.status in ('active', 'price_changed')
      and l.motorcycle_id is not null
  )
  select distinct on (k.user_id, r.case_number)
         k.user_id, r.case_number, k.bike_id, k.listing_id,
         m.brand, m.model, k.year,
         concat_ws(' ', nullif(r.product, 'Motorcycle'), r.name),
         r.recall_code, r.danger_en, r.danger_pt
  from bikes k
  join auth.users u on u.id = k.user_id and not coalesce(u.is_anonymous, false)
  join public.motorcycles m on m.id = k.motorcycle_id
  join public.vehicle_recalls r on public.recall_is_of_model(r, m)
  where r.stored_at > k.created_at
    and r.published_on >= (p_at at time zone 'Europe/Lisbon')::date
                          - public.recall_notice_days()
    and (r.from_year is null or k.year between r.from_year and r.to_year + 1)
    and not exists (select 1 from public.recall_notices n
                    where n.user_id = k.user_id and n.case_number = r.case_number)
    and not public.account_quiet_at(k.user_id, p_at)
  order by k.user_id, r.case_number, k.rank, k.created_at desc
$$;
revoke all on function public.pending_recall_notices(timestamptz)
  from public, anon, authenticated;

-- Marks a recall told to an account (twice changes nothing).
create function public.mark_recall_noticed(p_user uuid, p_case text)
returns boolean
language sql
security definer
set search_path = ''
as $$
  with marked as (
    insert into public.recall_notices (user_id, case_number)
    values (p_user, p_case)
    on conflict do nothing
    returning 1)
  select exists (select 1 from marked)
$$;
revoke all on function public.mark_recall_noticed(uuid, text)
  from public, anon, authenticated;

-- Computed fields: a model's recalls (all years) for Mercado's models,
-- and an owned bike's, `applies` for its year ("A minha mota").
create function public.recalls(m public.motorcycles)
returns jsonb
language sql
stable
set search_path = ''
as $$ select public.model_recalls(m.id) $$;
revoke all on function public.recalls(public.motorcycles) from public;
grant execute on function public.recalls(public.motorcycles) to anon, authenticated;

create function public.recalls(b public.owned_bikes)
returns jsonb
language sql
stable
set search_path = ''
as $$ select public.model_recalls(b.motorcycle_id, b.year) $$;
revoke all on function public.recalls(public.owned_bikes) from public;
grant execute on function public.recalls(public.owned_bikes) to authenticated;

-- The test notification of a recall (push-test.yml's `kind`).
create or replace function public.start_workflow(p_workflow text, p_kind text default null)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token    text;
  v_response extensions.http_response;
  v_at       timestamptz;
begin
  if p_workflow in ('push-test.yml', 'weekly-summary.yml') then
    perform public.require_account();
  else
    perform public.require_admin();
  end if;
  if p_workflow is null
     or p_workflow not in ('collect.yml', 'weekly-summary.yml', 'push-test.yml') then
    raise exception 'unknown workflow %', p_workflow using errcode = '22023';
  end if;
  if p_kind is not null and (p_workflow <> 'push-test.yml' or p_kind not in (
       'test', 'new_listing', 'price_reduction', 'excellent_opportunity',
       'listing_removed', 'back_on_market', 'target_price_reached',
       'run_failed', 'run_blocked', 'run_recovered', 'visit_reminder',
       'bike_value_month', 'recall')) then
    raise exception 'unknown kind %', p_kind using errcode = '22023';
  end if;

  -- One at a time per workflow, so two taps can't both pass the check.
  perform pg_advisory_xact_lock(hashtext('start_workflow ' || p_workflow));
  if exists (select 1 from public.workflow_starts w
             where w.workflow = p_workflow
               and (p_workflow = 'collect.yml' or w.started_by = auth.uid())
               and w.started_at > now() - case p_workflow
                 when 'collect.yml' then interval '15 minutes'
                 when 'push-test.yml' then interval '30 seconds'
                 else interval '2 minutes' end) then
    raise exception '% was started too recently', p_workflow
      using errcode = '55006';
  end if;

  select s.decrypted_secret into v_token
  from vault.decrypted_secrets s where s.name = 'github_dispatch_token';
  if v_token is null then
    raise exception 'github_dispatch_token is not in the Vault' using errcode = '55000';
  end if;

  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS', '15000');
  v_response := extensions.http((
    'POST',
    'https://api.github.com/repos/rafaelfaria1323/motorcycle-deal-tracker'
      || '/actions/workflows/' || p_workflow || '/dispatches',
    array[extensions.http_header('Authorization', 'Bearer ' || v_token),
          extensions.http_header('Accept', 'application/vnd.github+json'),
          extensions.http_header('X-GitHub-Api-Version', '2022-11-28'),
          extensions.http_header('User-Agent', 'motorcycle-deal-tracker')],
    'application/json',
    case p_workflow
      when 'weekly-summary.yml' then
        jsonb_build_object('ref', 'main',
                           'inputs', jsonb_build_object('account', auth.uid()))::text
      when 'push-test.yml' then
        jsonb_build_object('ref', 'main',
                           'inputs', jsonb_build_object(
                             'account', auth.uid(),
                             'kind', coalesce(p_kind, 'test')))::text
      else '{"ref": "main"}'
    end
  )::extensions.http_request);

  -- 204 = started (200 when GitHub answers with the run's details).
  if v_response.status not in (200, 204) then
    raise exception 'GitHub answered % to %', v_response.status, p_workflow
      using errcode = '58000';
  end if;

  insert into public.workflow_starts (workflow, started_by)
  values (p_workflow, auth.uid())
  returning started_at into v_at;
  return v_at;
end;
$$;
