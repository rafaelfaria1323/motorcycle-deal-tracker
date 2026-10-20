# Hosting the web app

The app is built and published to Cloudflare Pages by
`.github/workflows/deploy-web.yml` on every merge to `main` that touches
`app/` or adds a migration, and from the Actions tab ("Deploy web app" →
"Run workflow"). Tests must pass before anything is published.

Database migrations are applied by the same workflow, before the app: when
a merge adds files to `supabase/migrations/`, the `migrate` job tests every
migration and SQL test again on an empty Postgres, then runs
`supabase db push` against Supabase. A merge without new migrations skips
it. A failure stops the app deploy (fix it with a new migration; "Run
workflow" applies whatever is missing). `make db-push` still works by hand.

## One-time setup

1. **Cloudflare account** (free plan) at dash.cloudflare.com.
2. **Account ID**: Workers & Pages → Overview, right-hand column
   ("Account ID").
3. **API token**: My Profile → API Tokens → Create Token → "Create Custom
   Token", permission *Account · Cloudflare Pages · Edit*, limited to your
   account.
4. **GitHub secrets** (repo → Settings → Secrets and variables → Actions):
   - `CLOUDFLARE_ACCOUNT_ID`
   - `CLOUDFLARE_API_TOKEN`
   - `SUPABASE_PUBLISHABLE_KEY` — Supabase dashboard → Project Settings →
     API Keys, the publishable key (the same value as in `app/env/dev.json`).
   - `SUPABASE_URL` already exists for the collector.
   - `SUPABASE_DB_URL` — for the migrations: Supabase dashboard → Connect
     → "Session pooler" connection string (GitHub's runners have no IPv6,
     so not the direct one), with `[YOUR-PASSWORD]` replaced by the
     database password (Project Settings → Database; reset it there if
     unknown). Characters such as `@`, `#`, `/` or `%` in the password must
     be URL-encoded (`%40`, `%23`, `%2F`, `%25`).
5. Run "Deploy web app" once. The first run creates the Pages project
   `motorcycle-deal-tracker`; the log ends with the address
   (`https://motorcycle-deal-tracker.pages.dev`, or with a suffix if the
   name was taken).

## Scheduled runs (Supabase starts them)

GitHub's own scheduler never started `collect.yml`, so Supabase does:
pg_cron jobs `collect-listings` (every 4 hours, minute 40 UTC) and
`weekly-summary` (Mondays 07:52 UTC) call GitHub's "Run workflow" API.
They need one token, created once:

1. GitHub → Settings → Developer settings → Personal access tokens →
   Fine-grained tokens → Generate new token. Repository access: *Only
   select repositories* → `motorcycle-deal-tracker`. Permissions:
   *Actions: Read and write* (nothing else). Pick the longest expiry you
   are comfortable with and note the date.
2. Supabase → SQL Editor, run (with your token in place of the dots):
   `select vault.create_secret('github_pat_...', 'github_dispatch_token');`
3. Check it: `select public.dispatch_workflow('collect.yml');` starts a
   run (Actions tab), and
   `select status_code from net._http_response order by created desc limit 1;`
   shows 204.

When the token expires, make a new one and replace it:
`select vault.update_secret(id, 'github_pat_...') from vault.secrets where name = 'github_dispatch_token';`.
The app's "Mais" shows a warning when no run happened recently.

### Warning on Telegram when no run starts

Every hour (minute 20) the pg_cron job `collection-watchdog` checks the
last recorded run. When none started in 9 hours (an expired token, for
example) it sends a Telegram message, again once a day while it lasts,
and "As recolhas de anúncios voltaram a começar" after the next run. It
needs the bot's token and chat id in the Vault too (the same values as the
`TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` repository secrets), saved once
in the SQL Editor:

```sql
select vault.create_secret('<bot token>', 'telegram_bot_token');
select vault.create_secret('<chat id>', 'telegram_chat_id');
```

Check it with `select public.send_telegram('Teste');` (the message arrives
on the phone). If pg_cron itself stops, this check stops too; the app's
warning is then the only sign.

## On the iPhone

Open the address in Safari → Share → "Adicionar ao ecrã principal". The app
opens full screen with its own icon. Every deploy is picked up the next time
it opens.

The home-screen app keeps its own storage, separate from Safari, so it starts
as a new anonymous user: sign in from the account sheet to see your saved
searches.

## Privacy

The address is public: anyone who has it can browse the listings (as on the
listing sites themselves) but saved searches and alerts stay per user under
row-level security. Cloudflare Access (free for up to 50 users) can put an
email login in front of the whole site if that is ever needed.
