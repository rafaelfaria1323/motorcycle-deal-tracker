# Motorcycle Deal Tracker

A personal web app that watches the Portuguese used and semi-new motorcycle
market and answers one question: **is this motorcycle a good deal right
now?**

Every 4 hours it reads Standvirtual and OLX for the models being tracked,
keeps each listing's price and status history, and ranks the listings with
an explainable **Deal Score** (price against similar bikes, year and
mileage) and a separate **Risk Score** (missing details, possible accident,
several owners, price too good to be true…). Saved searches raise alerts in
the app and on the phone through Telegram.

The app is in Portuguese and installs on the iPhone from Safari
("Adicionar ao ecrã principal").

## How it works

```text
Tracked models (chosen in the app)
  → collector (GitHub Actions, every 4 hours): searches → polite fetch → parse → store
  → Supabase / Postgres: price history, duplicates, fair value, scores, alerts
  → app (Flutter Web on Cloudflare Pages): Ofertas · Pesquisas · Alertas · Mais
  → Telegram: new alerts after each run, and a summary of the week every Monday
```

| Folder | What it is |
|---|---|
| [`app/`](app/README.md) | Flutter Web/PWA |
| [`collector/`](collector/README.md) | Dart command line: fetches, parses and stores listings, then scores and alerts |
| `supabase/` | Database migrations: tables, scoring, alerts, views, access rules |
| `docs/` | Progress and decisions (see below) |
| `.github/workflows/` | `collect.yml` (every 4 hours), `deploy-web.yml` (app on merge), `weekly-summary.yml` (Mondays, the week on Telegram), `notify-test.yml` (Telegram test), `code-quality.yml` (after every 5 merged PRs, Claude works through the backlog in `docs/code-quality.md`) |

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
for the code-quality review. Database changes: `make db-new
NAME=...`, then `make db-push`.

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
- [`CLAUDE.md`](CLAUDE.md): conventions and the detailed pipeline, scoring and alert rules.
