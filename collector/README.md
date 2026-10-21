# Collector

Dart command line that fills the database. GitHub Actions runs it every
4 hours (`.github/workflows/collect.yml`, minute 40 UTC); it uses the
Supabase service-role key, which the app never sees.

## One run (`make refresh`, `bin/refresh.dart`)

For each site (Standvirtual, OLX):

1. **Plan:** the searches of the models any account follows, read from the catalog
   (models that share a search share one request).
2. **Fetch:** every page of each search (from the earliest tracked year),
   politely (see the root README) and capped.
3. **Import:** parse, match each listing to a model, store it, record price
   changes and dates, and mark listings that left the searches read in full
   as removed (`--full`). The brand and model lists in the search pages'
   filters are stored too (`site_models`, for the app's model picker; no
   extra requests).
4. **Details** (Standvirtual only): read the listing page of new listings.

Then, once for both sites: find duplicates, recalculate the scores,
generate the alerts and send the new ones to each account's devices (Web
Push) and to Telegram.

After each scheduled run `bin/report_run.dart` records it in `collector_runs`
and, when its status differs from the previous run's (ok, blocked, failed),
sends one Telegram message: what went wrong on which site
(`notify/run_health.dart`), or that the collection works again. The same
problem is not repeated every 4 hours.

Every Monday `bin/weekly_summary.dart` (workflow `weekly-summary.yml`) sends
one Telegram message about the tracked models' last 7 days: new listings per
model, price drops (1 % or more, biggest first), listings gone, and the 5
best live deals with a Risk Score below 50. It only reads the database.

## Commands

| Command | What it does |
|---|---|
| `make refresh [ARGS=--full]` | The whole run for both sites |
| `make refresh-olx` / `refresh-standvirtual` | The same for one site |
| `make searches SITE=olx\|standvirtual` | Write the planned searches |
| `make fetch-dry` / `fetch SITE=...` | Check, or download, the search pages |
| `make collect-dry` / `collect SOURCE=... FILE=...` | Import saved pages or a JSON file |
| `make enrich-dry` / `enrich` | Standvirtual listing details |
| `make notify-test` | Send a test message to Telegram |
| `make weekly-summary [ARGS=--dry-run]` | Send (or print) the week's summary |
| `make collector-check` | Format check, analyze and test |

Secrets go in `collector/.env` (gitignored): `SUPABASE_URL`,
`SUPABASE_SERVICE_ROLE_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`.

## Code layout

```text
bin/        entry points (refresh, fetch, collector, enrich, searches, report_run, notify_test, weekly_summary)
lib/        fetcher, site adapters and mappers, model matching, store, run steps
test/       unit tests
samples/    small listing files for trying `make collect` by hand
```

Saved pages, `searches.json` and the fetch state (`.fetch_state*.json`) hold
sellers' contact details and are never committed.
