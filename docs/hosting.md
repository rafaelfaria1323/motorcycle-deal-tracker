# Hosting the web app

The app is built and published to Cloudflare Pages by
`.github/workflows/deploy-web.yml` on every merge to `main` that touches
`app/`, and from the Actions tab ("Deploy web app" → "Run workflow").
Tests must pass before anything is published.

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
