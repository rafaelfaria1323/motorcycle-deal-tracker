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
