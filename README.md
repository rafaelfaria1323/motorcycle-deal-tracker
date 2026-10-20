# Motorcycle Deal Tracker

A personal web app that watches the Portuguese used and semi-new motorcycle
market and answers one question: **is this motorcycle a good deal right
now?**

Every 4 hours it reads Standvirtual and OLX for the models being tracked,
keeps each listing's price and status history, and ranks the listings with
an explainable **Deal Score** (price against similar bikes, year and
mileage) and a separate **Risk Score** (missing details, possible accident,
several owners, price too good to be true…). Saved searches and favourite
listings (with private notes) raise alerts in the app and on the phone
through Telegram.

The app is in Portuguese and installs on the iPhone from Safari
("Adicionar ao ecrã principal").

## How it works

```text
Tracked models (chosen in the app)
  → collector (GitHub Actions, started every 4 hours by Supabase pg_cron): searches → polite fetch → parse → store
  → Supabase / Postgres: price history, duplicates, fair value, scores, alerts
  → app (Flutter Web on Cloudflare Pages): Ofertas · Pesquisas · Alertas · Mais
  → Telegram: new alerts after each run, a message when the collection breaks, stops starting or recovers,
    and a summary of the week every Monday
```

| Folder | What it is |
|---|---|
| [`app/`](app/README.md) | Flutter Web/PWA |
| [`collector/`](collector/README.md) | Dart command line: fetches, parses and stores listings, then scores and alerts |
| `supabase/` | Database migrations: tables, scoring, alerts, views, access rules; `tests/`: SQL tests (`make db-test`) |
| `docs/` | Progress and decisions (see below) |
| `.github/workflows/` | `collect.yml` (every 4 hours, started by Supabase pg_cron), `check.yml` (`make check` and `make db-test` on every pull request), `deploy-web.yml` (app on merge), `weekly-summary.yml` (Mondays, the week on Telegram), `notify-test.yml` (Telegram test), `mutation.yml` (mutation testing without AI: after merges the changed files, by hand all of them; report on the run's page), `code-quality.yml` and `test-hardening.yml` (Claude works through the backlogs, fixing every 5 merged PRs and finding new items after 10 in `docs/code-quality.md` and `docs/test-hardening.md`; shared steps in `backlog-pass.yml`) |

## Getting started

Requirements: Flutter (stable), the Supabase CLI and `make`.

```sh
make help                 # every command
cp app/env/dev.example.json app/env/dev.json   # Supabase URL + publishable key
make app-get app-run      # the app in Chrome
make collector-get        # collector dependencies; secrets in collector/.env
make refresh              # one collection run for both sites
make check                # analyze and test everything (before each commit)
```

`collector/.env` (never committed) holds `SUPABASE_URL`,
`SUPABASE_SERVICE_ROLE_KEY`, `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`.
GitHub Actions uses repository secrets with the same names, plus
`SUPABASE_PUBLISHABLE_KEY`, `CLOUDFLARE_API_TOKEN` and
`CLOUDFLARE_ACCOUNT_ID` for the web deploy, and `CLAUDE_CODE_OAUTH_TOKEN`
for the code-quality review. Supabase's Vault holds `github_dispatch_token`,
which the scheduled jobs use to start the workflows (`docs/hosting.md`).
Database changes: `make db-new
NAME=...`, a test in `supabase/tests/` (`make db-test` runs them on a local
Postgres; CI runs them on every pull request), then `make db-push`.

## Fetching rules

The collector is a low-volume personal reader: robots.txt read every run,
6–10 s between requests, at most 20 requests per run and 120 per day per
site, never in parallel, no retries, and a 24-hour pause after any refusal.
Private sellers' names and phone numbers are never stored, and saved pages
are never committed.

## Docs

- [`docs/roadmap.status.md`](docs/roadmap.status.md): the roadmap, step by step, with what is done.
- [`docs/concept.status.md`](docs/concept.status.md): the original concept and how far it is built.
- [`docs/sources.md`](docs/sources.md): data-source decisions.
- [`docs/hosting.md`](docs/hosting.md): Cloudflare Pages and installing on the iPhone.
- [`docs/code-quality.md`](docs/code-quality.md): code improvements to do and done (worked through automatically).
- [`docs/test-hardening.md`](docs/test-hardening.md): bugs, missing and redundant tests found by the automatic mutation-style pass, to do and done.
- [`CLAUDE.md`](CLAUDE.md): conventions and the detailed pipeline, scoring and alert rules.
