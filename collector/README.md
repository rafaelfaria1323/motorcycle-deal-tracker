# Collector

Dart command line that fills the database. GitHub Actions runs it at
00:00 and every 2 hours from 08:00 to 22:00, Lisbon time
(`.github/workflows/collect.yml`, started by Supabase pg_cron); it uses the
Supabase service-role key, which the app never sees.

## One run (`make refresh`, `bin/refresh.dart`)

For each site (Standvirtual, OLX):

1. **Plan:** the searches of the models any account follows, read from the catalog
   (models that share a search share one request).
2. **Fetch:** every page of each search (from the earliest tracked year),
   politely (see the root README), at most 30 minutes per site. A light
   run (`--light`: `collect.yml` at 10, 12, 16, 18 and 22 h Lisbon time)
   reads a search read in full in the last 12 h newest first and stops at
   the page that reaches ads 2 h older than that read; such a search
   removes nothing, the full runs (00, 08, 14 and 20 h) do.
3. **Import:** parse, match each listing to a model, store it, record price
   changes and dates, and mark listings that left the searches read in full
   as removed (`--full`). The brand and model lists in the search pages'
   filters are stored too (`site_models`, for the app's model picker; no
   extra requests). The log says, per search, the pages it spans (from its
   first page, kept in `searches.json`) and the pages read, the ads found,
   how many are a followed model and whether it was read in full
   ("Search (olx): yamaha-mt-07 · read 2 of 3 page(s) · 80 ad(s), 9
   followed · in full"), so a search that spends requests on other bikes
   shows up; an ad no followed model matched is logged with
   the site's brand and model ("unmatched \"Honda NSS 350 Forza\""; on OLX
   the model is the title, long digit runs masked), so a missed rule can
   be spotted.
4. **Details** (Standvirtual only): read the listing page of new listings
   (favourites and alerted ones first, then by Deal Score, so what waits
   for the next run when time runs out matters least).

Then, once for both sites: find duplicates, recalculate the scores,
generate the alerts and send the new ones to each account's devices (Web
Push; the Android app's through Firebase Cloud Messaging, `notify/fcm.dart`,
with the service account in env `FIREBASE_SERVICE_ACCOUNT`).

Alerts dismissed in the app keep their event history. The owner-checked
`dismiss_alert` RPC sets `dismissed_at` and marks them read and handled
(`notified_at`), preserving existing timestamps, so the collector neither
regenerates the same event nor picks it up as a pending notification, and
a dismissed alert brings no later "removed" or "back on the market" alert
for its listing.

Every catalog model has searches for both OLX and Standvirtual, including
models added before automatic source coverage. The database keeps existing
addresses and fills missing ones from known site filters or a word search
for the model (and brand when its filter is unknown). The planner applies
the same year and OLX engine-band filters to these searches. This does not
change the fetching rules, model matching, or per-search removal safeguards.

After each scheduled run `bin/report_run.dart` records it in `collector_runs`
(with the error lines of a run that was not ok, each search's pages and
ads from those lines, each site's requests today
and pause from its fetch state file, how long the scores took
(`scoring_ms`) and the GitHub run's address; shown
in the app's "Estado da recolha") and, when its status differs from the previous run's (ok, partial, blocked, failed),
sends one notification to the admins' devices (Web Push; a tap opens
"Estado da recolha"): what went wrong on which site
(`notify/run_health.dart`), or that the collection works again. The same
problem is not repeated on every run. A run is `partial` when its only
problems were passing fetch failures (`Failed:` lines: a timeout or server
error after the retry, and the pages they left unread; or one page the site
served without its results while another search of it was read in full) and
it still finished scores and alerts: it is told
only when the same site fails in the next run too, and its GitHub job stays
green with a warning.

Readable records are kept even when other records cannot be read. These
`Read issue:` lines fail the run (also for a saved-file import or dry run),
while ordinary rejected/unmatched listings and mapper warnings do not.
Only trusted searches may remove missing listings; repeated Standvirtual
page offsets make that search incomplete, not artificially complete.
`--force` can override removal safeguards, but never hides read failures.

For listing details, gone pages (HTTP 404/410), unreadable individual
pages, refused addresses and redirects to another ad remain skips.
Transport failures and other HTTP errors stop enrichment, store the
details already read, then fail the run. Blocking HTTP statuses start the
24-hour pause as soon as their headers arrive, even if their body is
broken. Timed-out requests are cancelled before another request can start.

Every Monday `bin/weekly_summary.dart` (workflow `weekly-summary.yml`) makes
each account's summary of its own models' last 7 days: new listings per
model, price drops (1 % or more, biggest first), listings gone, and the 5
best live deals with a Risk Score below 50. It keeps it in
`weekly_summaries` (the app's "Resumo da semana") and sends it to the
account's devices (Web Push; a tap opens that page). Asked for in the app,
the workflow gets the account as its input (`SUMMARY_ACCOUNT`) and makes
only that one. It only reads the listings.

## Notification languages

`notify/notification_text.dart` contains bundled Portuguese/English copy and
the stable `NotificationLanguage` codes (`pt`, `en`). Alerts, test pushes,
weekly-summary pushes and collection-health notices use each recipient's
`account_languages` preference; missing rows preserve Portuguese. Preference
reads are batched by 100 accounts. Failed reads do not send fallback-language
messages or mark pending alerts handled.

Weekly summaries are stored as language-independent data before preferences
are loaded, so the app can render existing summaries in either language.
Push URLs, tags, ownership and delivery/retry rules are unchanged. Language
metadata reaches Web Push/FCM and the Android channel's display name, while
its channel ID remains `alerts`. Seller/model names and raw collection
diagnostics stay unchanged; the database's Telegram watchdog/token warnings
remain operational messages. There is no translation service or AI.

## Commands

| Command | What it does |
|---|---|
| `make refresh [ARGS=--full]` | The whole run for both sites (`ARGS="--full --light"`: a light run) |
| `make refresh-olx` / `refresh-standvirtual` | The same for one site |
| `make searches SITE=olx\|standvirtual` | Write the planned searches |
| `make fetch-dry` / `fetch SITE=...` | Check, or download, the search pages |
| `make collect-dry` / `collect SOURCE=... FILE=...` | Import saved pages or a JSON file |
| `make enrich-dry` / `enrich` | Standvirtual listing details |
| `make notify-test` | Send a test message to Telegram |
| `make push-test` | Send a test notification (Web Push) to the admins' devices (`push-test.yml` from the app: to the asking account's; `PUSH_KIND=price_reduction` etc. sends an example of that notification, `pushTestKinds`) |
| `make weekly-summary [ARGS=--dry-run]` | Make and send (or print) each account's summary of the week |
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

The collector remains pure Dart. `html` reads Standvirtual's
`__NEXT_DATA__` script without relying on attribute order or quoting and
cleans description fragments using HTML5 entity decoding. Paragraphs,
breaks and list markers are kept; comments, scripts, styles and known
dealer boilerplate are left out. OLX's JavaScript state still uses its
source-specific reader. Matching and phone-number removal stay in the
shared normalization pipeline. Oversized numeric entities in surrounding
HTML cannot break JSON extraction or change literal strings inside the
script. Standvirtual's exact model names cannot bypass the resolver's
engine-size guard; those listings remain unmatched.

`clock` supplies the fetcher's current time. `fake_async` tests request
spacing, run deadlines, robots-cache expiry, block cooldowns and UTC-day
rollover without real waits or network/filesystem I/O. Separate local-HTTP
tests still cover fetching pages. The fetching rules are unchanged.

Saved pages, `searches.json` and the fetch state (`.fetch_state*.json`) hold
sellers' contact details and are never committed.
