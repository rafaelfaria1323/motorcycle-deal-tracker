# Motorcycle Deal Tracker

A personal web app that watches the Portuguese used and semi-new motorcycle
market and answers one question: **is this motorcycle a good deal right
now?**

Nine times a day (00:00, then every 2 hours from 08:00 to 22:00,
Lisbon time) it reads Standvirtual and OLX for the models being tracked,
keeps each listing's price and status history, and ranks the listings with
an explainable **Deal Score** (price against similar bikes, year and
mileage) and a separate **Risk Score** (missing details, possible accident
or damage, several owners, price too good to be true…). Saved searches and favourite
listings (with private notes and a viewing checklist) raise alerts in the
app and as notifications on each account's phone (Web Push; Firebase Cloud
Messaging in the Android app), except during each account's quiet hours
(23:00 to 08:00 unless changed), when they wait for the next collection.

The app supports **Portuguese (Portugal) and English**, with Portuguese as
the default. Choose Mais › "Idioma" / More › "Language"; accounts keep their
choice across devices, including notifications and weekly summaries.
Translations are bundled, with no translation service. Original seller
content, model/place names and private notes are not translated. The app
installs on the iPhone from Safari ("Adicionar ao ecrã principal").

The interface pairs Barlow typography with an orange-and-ink palette, clear
price and score hierarchy, and photo-led listing cards. It adapts from a
phone's bottom navigation to a desktop sidebar and three-column listings;
filters, sorting, saving searches and comparing ads have visible controls.
Each account can choose the details shown on its cards in Ofertas and
Favoritos ("Cartões" in Ofertas, or Mais › "Cartões dos anúncios"); the
current layout remains the default. Options include first owner / number
of owners, service book, origin, warranties, colour and the ad's publication
and renewal dates, distinct from when it was first found.
Saved-search and alert cards support swipe actions: right to edit (an
alert opens its originating saved search), left to confirm deletion.
The options menus remain available without gestures. Dismissing an alert
hides it without erasing the history that prevents repeated notifications.

Add a bike by brand, model and first year, with an optional engine size.
Every model is searched on **both OLX and Standvirtual**: known site filters
are kept, and missing ones get a name-based search. No search URLs to copy.

## How it works

```text
Tracked models (chosen in the app)
  → collector (GitHub Actions, started 9 times a day by Supabase pg_cron): searches → polite fetch → parse → store
  → photo fingerprints (photo CDN only, after the run): ads with the same photos
    + damage hints (CLIP, a free image model run on the same photos)
    + a classifier trained on the admins' marks on those photos (no AI service)
  → Supabase / Postgres: price history, duplicates, fair value, scores, alerts
  → app (Flutter Web on Cloudflare Pages): Ofertas · Pesquisas · Alertas · Mais
  → phones (Web Push; FCM in the Android app): each account's new alerts after each run (a tap opens the listing), its
    summary of the week every Monday (a tap opens "Resumo da semana"), and the admins' when the
    collection breaks or recovers
  → Telegram: a message when no collection starts or the GitHub token is ending (sent by the database,
    so it works when GitHub doesn't)
```

| Folder | What it is |
|---|---|
| [`app/`](app/README.md) | Flutter Web/PWA |
| [`collector/`](collector/README.md) | Dart command line: fetches, parses and stores listings, then scores and alerts |
| `supabase/` | Database migrations: tables, scoring, alerts, views, access rules; `tests/`: SQL tests (`make db-test`) |
| `docs/` | Progress and decisions (see below) |
| `.github/workflows/` | `collect.yml` (00:00 and every 2 hours from 08:00 to 22:00, Lisbon time, started by Supabase pg_cron), `check.yml` (three parallel jobs: the app's analyze, unused code and tests with coverage; `make app-smoke`; the collector and database, using the collection's shared Dart setup and startup smoke before its checks, coverage, `tool/` and database tests), `deploy-web.yml` (on merge: new migrations, the app's tests and the builds side by side, then the web app and the Android APK published, the APK on the release `android`, which the Android app installs as its update), `android-check.yml` (the APK built on pull requests that touch the Android side), `weekly-summary.yml` (Mondays, each account's week in the app and on its devices; or one account's when asked in the app), `photos.yml` (the photo fingerprints and damage hints: after each collection, and at once when someone asks for every photo of an ad; shared setup in `.github/actions/collector`), `push-test.yml` (a test notification to the devices of whoever asked in the app), `mutation.yml` (mutation testing without AI: after merges the changed files, by hand all of them, held to a minimum score; report on the run's page), `code-quality.yml` and `test-hardening.yml` (Claude works through the backlogs, fixing every 5 merged PRs and finding new items after 10 in `docs/code-quality.md` and `docs/test-hardening.md`; shared steps in `backlog-pass.yml`) |

## Getting started

Requirements: **Flutter 3.47.8 with its bundled Dart 3.13.7**, the Supabase
CLI and `make`. `.fvmrc` pins Flutter for FVM and every Flutter workflow;
`.dart-version` pins the same Dart for standalone collector jobs and cloud
sessions. The collector/database PR job needs only Dart, not Flutter, and
also checks the production collector setup instead of installing it again
in a separate job.

With FVM, run `fvm use 3.47.8` and put `.fvm/flutter_sdk/bin` first on
`PATH` before using `make`; otherwise install that Flutter version and use
its bundled `dart`. Changing `.fvmrc` also triggers previews and Android
builds, and deployment on merge.

```sh
make help                 # every command
cp app/env/dev.example.json app/env/dev.json   # Supabase URL + publishable key
make app-get app-run      # the app in Chrome
make collector-get        # collector dependencies; secrets in collector/.env
make refresh              # one collection run for both sites
make check                # analyze and test everything (before each commit)
make app-smoke            # offline browser flow (Chrome + matching ChromeDriver)
```

The browser smoke uses Flutter's SDK `integration_test` and in-memory
repositories, not Supabase credentials or live listings. It runs separately
from `make check`; CI runs both (the tests inside `make app-coverage` /
`collector-coverage`, so each suite runs once). The collector stays pure Dart, using `html`
for HTML5 parsing and `clock` / `fake_async` for deterministic timing tests.

`collector/.env` (never committed) holds `SUPABASE_URL`,
and `SUPABASE_SERVICE_ROLE_KEY`.
GitHub Actions uses repository secrets with the same names, plus
`SUPABASE_PUBLISHABLE_KEY`, `CLOUDFLARE_API_TOKEN` and
`CLOUDFLARE_ACCOUNT_ID` for the web deploy, `ANDROID_KEYSTORE_BASE64`
and `ANDROID_KEYSTORE_PASSWORD` for the Android app's signing key,
`SUPABASE_DB_URL` and `SUPABASE_DB_PASSWORD` for the migrations,
`FIREBASE_ANDROID_CONFIG` and `FIREBASE_SERVICE_ACCOUNT` for the Android
app's notifications, and `CLAUDE_CODE_OAUTH_TOKEN`
for the code-quality review. Supabase's Vault holds `github_dispatch_token`,
which the scheduled jobs use to start the workflows (`docs/hosting.md`).
Database changes: `make db-new
NAME=...`, a test in `supabase/tests/` (`make db-test` runs them on a local
Postgres; CI runs them on every pull request). Merging applies new
migrations to Supabase before the app deploys (`deploy-web.yml`);
`make db-push` does the same by hand.

## Fetching rules

The collector is a low-volume personal reader: robots.txt read once a day
(kept up to 24 hours), 6–10 s between requests, never in parallel, one retry a minute later only after a timeout or a
passing server error (500/502/504), at most 30 minutes
per site and run (no request cap since 2026-10-22; the requests are shown
per run, day and month in the app), and a 24-hour pause after any refusal.
Private sellers' names and phone numbers are never stored, and saved pages
are never committed.
After each run, up to 3 photos of each new listing are hashed (no AI) from
the photo CDN the sites use, never their pages: one at a time 2-3 s apart,
at most 5 minutes, counted apart from the sites' requests. Only the hashes
are kept; they find ads with the same photos (duplicates, relists, photos
reused from another bike). The same photos go to a free image model run on
the runner for damage hints (P.2); admins can mark them as a problem or fine
in the full-screen photos, and the collector learns from those marks (P.3:
a logistic regression in plain Dart on the stored embeddings). An account can
ask for every photo of one ad to be examined (P.4, "Examinar todas as
fotos": up to 30, within the same 5 minutes; 5 a day). The request starts
the photo step at once (P.7), and the account is told on its devices when
it is done.

Partial imports keep readable listings but report parsing or transport
failures instead of a successful run. Repeated Standvirtual pages are not
treated as complete searches for removal.

## Docs

- [`docs/roadmap.status.md`](docs/roadmap.status.md): the roadmap, step by step, with what is done.
- [`docs/concept.status.md`](docs/concept.status.md): the original concept and how far it is built.
- [`docs/sources.md`](docs/sources.md): data-source decisions.
- [`docs/hosting.md`](docs/hosting.md): Cloudflare Pages, installing on the iPhone, and the Android app.
- [`docs/paid-plans.md`](docs/paid-plans.md): the plan for paid subscriptions and other income: what to decide first, free and paid features, prices to test. Not started (roadmap Sprint 16).
- [`docs/code-quality.md`](docs/code-quality.md): code improvements to do and done (worked through automatically).
- [`docs/test-hardening.md`](docs/test-hardening.md): bugs, missing and redundant tests found by the automatic mutation-style pass, to do and done.
- [`docs/feature-review.md`](docs/feature-review.md): the review of every feature (2026-10-31): what to improve in each, what doesn't make sense, code and UI/UX changes, and their order (steps F.1-F.11).
- [`CLAUDE.md`](CLAUDE.md): conventions and the detailed pipeline, scoring and alert rules.

## Credits

Place coordinates (distance from home): [GeoNames](https://www.geonames.org), CC BY 4.0.
