# Motorcycle Deal Tracker

Personal web app/PWA (single owner: Rafael) that watches the Portuguese used
and semi-new motorcycle market, tracks price and status history, and ranks
listings with an explainable **Deal Score** plus a separate **Risk Score**.
Alerts go to the app and to the owner's phone (Telegram).

Progress lives in `docs/roadmap.status.md` (step by step) and
`docs/concept.status.md` (against the original concept). **Update both in
the same PR as the work.** Also keep the READMEs (`README.md`,
`app/README.md`, `collector/README.md`) and this file true in the same PR
when a change affects what they say (screens, commands, secrets, layout,
pipeline, rules).

Catalog (table `motorcycles`): 13 models, chosen in the app ("Modelos
acompanhados"). Tracked by default: Yamaha MT-07, Yamaha R7, Honda CB650R,
Honda CBR650R. Available, off by default: Tracer 7, R1, R3, R9, CB125R,
CB300R, CBR500R, CB750 Hornet, CBR600RR. The owner can add more from the app:
brand and model picked from `site_models` (the sites' filter lists, stored
by every import from the search pages; view `site_makes` for the brands),
optional engine size (name "Forza 350", Standvirtual `q-350`, engine range
+-10 %), searches built from the sites' ids (OLX only when OLX's own list
has the model), or typed by hand.

## How to work on this project

- Rafael wants you to **make the technical decisions yourself** (best,
  most robust option) and explain them briefly, not present menus of choices.
  Ask only when a decision is really his (cost, risk he takes on, loosening
  the fetching rules).
- Work in small verifiable steps: implement → test → commit. Each step ends
  with a definition of done.
- Answers to Rafael in English; **all UI text in Portuguese (pt-PT)**,
  speaking to the user as "você" ("Verifique", "a sua conta"; never "tu",
  checked by `app/test/voice_test.dart`); code, comments and commit
  messages in English.
- Commit style: `feat(scope): what (step id)`, e.g.
  `feat(alerts): push new alerts to Telegram after each run (11.1)`.
- Flow: push to the `claude/...` branch, open a PR, Rafael merges. Once a PR
  is merged, start the next work from a fresh `origin/main`.
- **Migrations** are applied on merge: `deploy-web.yml`'s `migrate` job
  (skipped when the merge adds none) runs `make db-test` again, then
  `tool/apply_migrations.sh` (psql through the Session pooler, each
  migration in one transaction with its row in the CLI's
  `supabase_migrations.schema_migrations`; not `supabase db push`, which
  rewrites a pooler URL to the IPv6-only direct host; secrets
  `SUPABASE_DB_URL` + `SUPABASE_DB_PASSWORD`, joined and TLS-required by
  `tool/db_url.py`), and only then deploys the app. Never change, rename or delete a migration already on `main` (it
  may be live; add a new one); new ones must sort after main's latest
  (`tool/check_migrations.sh`, also run by `check.yml`). The collector runs
  from `main` on its own schedule, so keep a migration compatible with the
  code on `main` before the merge. `make db-push` still works by hand.
- You cannot reach Supabase from the sandbox. SQL tests live in
  `supabase/tests/*_test.sql` (`make db-test`, also run by `check.yml`):
  `tool/db_test.sh` applies every migration (each in one transaction, as
  the merge does: a new enum value can't be used in the file that adds it)
  to a fresh Postgres after
  `supabase/tests/stubs.sql` (roles, `auth`, pg_cron/pg_net/Vault
  stand-ins, Supabase's default grants), then runs each test in a
  transaction that is rolled back; a test fails by raising (`assert`).
  `set local test.uid` / `test.jwt` act as a user. `now()` is fixed inside
  a transaction, so date rows explicitly when their order matters. Add or
  extend a test with every migration that changes behaviour.
- Flutter is not installed in the sandbox and must not be downloaded: Rafael
  tests the app. Pure Dart logic in the app can be tested with plain Dart
  (`package:test`) on copies of the files. The deploy runs `flutter test`
  and `flutter build web`.

## Layout

```
app/        Flutter Web/PWA (package name: motorcycle_deal_tracker)
collector/  Pure Dart CLI: fetch, parse, store, score, alert (service-role key)
supabase/   Migrations (Postgres: scoring, alerts, views, RLS); tests/ SQL tests
docs/       sources.md (data-source decisions, keep updated), hosting.md,
            roadmap.status.md, concept.status.md, code-quality.md and
            test-hardening.md (backlogs of the automatic passes)
.github/workflows/collect.yml     Collection every 4 hours (minute 40, UTC),
                                  started by Supabase pg_cron (see below)
.github/workflows/weekly-summary.yml  Mondays 07:52 UTC (pg_cron): the week's summary
                                  on Telegram (bin/weekly_summary.dart)
.github/workflows/check.yml       `make check` (with Flutter) and `make
                                  db-test` (Postgres service) on every pull
                                  request to main
.github/workflows/preview-web.yml Every PR touching app/: the app built and
                                  published to pr-<number>.<project>.pages.dev,
                                  linked in one comment on the PR (real
                                  database; the PR's migrations not applied);
                                  older builds deleted on each push, the
                                  preview deleted when the PR closes
.github/workflows/deploy-web.yml  On merges touching app/ or adding
                                  migrations: apply new migrations
                                  (tested again first; skipped if none),
                                  then test, build and publish the app to
                                  Cloudflare Pages
.github/workflows/code-quality.yml  Claude pass on docs/code-quality.md: how
                                  the code is written (duplication, dead
                                  code, structure, theme, names); one PR
                                  labelled code-quality; merges since the
                                  tag code-quality-reviewed are counted
.github/workflows/test-hardening.yml  The same on docs/test-hardening.md:
                                  bugs, surviving mutants, redundant tests
                                  (label test-hardening); never overlaps
                                  with code quality
.github/workflows/mutation.yml    Mutation testing without AI (mutation_test,
                                  tool/mutation.py) on the files in
                                  */mutation_targets.txt: after merges only
                                  the changed ones, "Run workflow" all (4+4
                                  parallel jobs). Report only (run summary,
                                  HTML artifacts); test hardening's find
                                  runs start from the last full run's
                                  surviving mutants
.github/workflows/backlog-pass.yml  Shared by both: "To do" empty -> after 10
                                  merges, only find up to 10 items, no code
                                  change; otherwise every 5 merges do up to
                                  3 items, find nothing.
                                  One pass at a time, none while one of
                                  the same backlog is open. Its PR merges
                                  itself when its check passes (not when it
                                  touches supabase/, .github/, tool/ or the
                                  Makefile; variable AUTO_MERGE_BACKLOG=false
                                  turns it off) and starts the app deploy
.claude/hooks/session-start.sh  Cloud sessions only: Dart SDK on PATH, collector
                                  dependencies, local Postgres (PGHOST set), so
                                  make collector-check / tool-check / db-test run
Makefile    All commands (`make help`)
```

## Commands

```
make check                     analyze + test app and collector, test tool/ (before every commit)
make app-run                   run the app in Chrome (app/env/dev.json)
make db-new NAME=x / db-push   create / apply migrations (merging applies them too)
make db-test                   migrations + SQL tests on a local Postgres
make searches SITE=olx|standvirtual   write the tracked models' searches
make fetch-dry|fetch SITE=...  download those search pages (polite, capped)
make collect-dry|collect SOURCE=manual|standvirtual|standvirtual-search|olx-search FILE=... [ARGS=--full]
make enrich-dry|enrich         read Standvirtual listing pages for details (max 10 per run)
make refresh ARGS=--full       one process for both sites (bin/refresh.dart): searches -> fetch
                               -> import (with removal) -> enrich, then scores/alerts once
make refresh-olx|refresh-standvirtual   the same for one site
make weekly-summary [ARGS=--dry-run]   send (or print) the week's Telegram summary
make mutation PKG=collector|app FILES="lib/..."   mutation testing of those files
                               (needs `dart pub global activate mutation_test`)
```

Local secrets live in `collector/.env` (gitignored, loaded by the Makefile):
`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `TELEGRAM_BOT_TOKEN`,
`TELEGRAM_CHAT_ID`. GitHub Actions uses repository secrets with the same
names, plus `SUPABASE_PUBLISHABLE_KEY`, `CLOUDFLARE_API_TOKEN` and
`CLOUDFLARE_ACCOUNT_ID` for the web deploy, `SUPABASE_DB_URL` (Session
pooler connection string, `[YOUR-PASSWORD]` left in) and
`SUPABASE_DB_PASSWORD` for the migrations, and `CLAUDE_CODE_OAUTH_TOKEN`
for the code-quality review. Supabase's Vault holds `github_dispatch_token`
(starts the scheduled workflows) and `telegram_bot_token` /
`telegram_chat_id` (the watchdog's messages).

## App conventions (Flutter)

- Clean architecture per feature: `domain/` (entities, repository interfaces),
  `data/` (models with `fromJson`, Supabase repositories), `presentation/`
  (cubits, pages, widgets). Features: `listings`, `collector_status`,
  `settings` (the "Mais" tab).
- Text built from data lives in pure functions (`*_text.dart`) with tests.
- State: flutter_bloc Cubits + Equatable states. DI: get_it. Shared cubits
  (`ListingsCubit`, `SavedSearchesCubit`, `AlertsCubit`, `CollectorStatusCubit`,
  `FavouritesCubit`, and `SessionCubit` for the signed-in state: widgets never
  read Supabase's auth directly) are lazy singletons, provided in routes with
  `BlocProvider.value`. The shell (`AppShell`) loads `AlertsCubit` at start
  and on app resume for the unread badge on Alertas, and `FavouritesCubit`
  at start for the stars on the cards; the account sheet reloads the shared
  cubits after sign-in/out.
- Routing: go_router `StatefulShellRoute` (Ofertas / Pesquisas / Alertas /
  Mais). Account, "Modelos acompanhados" and collection status live in Mais.
  Use `context.go`, not `push`, so web URLs stay correct. Exception: full
  pages outside the shell (`/models`, `/market`, `/favourites`,
  `/compare?ids=a,b,c`) are pushed.
  The comparison picks live in `CompareCubit` (lazy singleton, max 3);
  its table is `compare_text.dart` (`compareRows`, tested).
- Formatting: `Formatters.price`, `.mileage`, `.date`, `.daysAgo`,
  `.percent` ("5,3 %": decimal comma, space before the sign)
  (`core/formatting/formatters.dart`). A listing is an "anúncio" (Ofertas
  is only the tab's name); a repeat of another listing is "duplicado".
- Auth: anonymous session on first visit; the owner signs in with
  email + password (user created by hand in Supabase, no SMTP). Catalog
  changes go through RPCs that call `require_account()` (signed in, not
  anonymous).
- Photos: `Image.network` with `WebHtmlElementStrategy.prefer` (the photo
  CDNs don't send CORS headers, so an `<img>` element is the only way).
- Lists load `ListingModel.summaryColumns`, never `*` (descriptions are big);
  the deals list is paged (40 per page, more on scroll).
- Look: `app/theme/app_theme.dart` (hand-made colour schemes: cool greys,
  racing-orange primary, white cards with a hairline border, no shadows or
  tints) and `app_colors.dart` (`AppColors.of(context)`: positive/negative
  and Deal Score band colours, light and dark). Never hard-code colours in
  widgets. Fonts are bundled (`assets/fonts`, Latin subset): Barlow for
  text, Barlow Semi Condensed (`AppTheme.displayFont`) for titles, prices
  and scores; prices use tabular figures.
- Hosting: Cloudflare Pages, installed on the iPhone from Safari ("Adicionar
  ao ecrã principal"). Status bar: Safari 26+ ignores `theme-color` and tints
  its bars from a solid `position: fixed` element at the top/bottom edge, so
  `web/index.html` has two 12px iOS-only strips (`.edge-tint`, taps pass
  through): the top one copies the `theme-color` tag, the bottom one is the
  tab bar colour (`surfaceContainerLowest`: `#FFFFFF` / `#171A20`). Flutter
  writes each AppBar's `systemOverlayStyle.statusBarColor` into
  `theme-color`, so `AppBarTheme.systemOverlayStyle` sets it to the page
  background (`AppTheme.lightBackground` `#F4F5F7`, `darkBackground`
  `#0F1115`; Material 3's default is transparent black) and an AppBar with
  its own background sets its own (the photo viewer: black). Keep these
  colours in step with `index.html` and `web/manifest.json`. In the
  home-screen app the bottom strip is hidden (no Safari toolbar). Flutter
  web reports no safe area, so `MaterialApp.builder` adds a bottom inset
  (`iosBottomInset`, `core/platform/home_screen_app.dart`): 12px in Safari
  on iPhone/iPad (the strip's height, so it sits under the tab bar labels),
  24px in the home-screen app on iPhones with a home bar, 0 elsewhere.

## Database conventions (Supabase / Postgres)

- Functions: `security definer`, `set search_path = ''`, fully qualified
  names, and `revoke all ... from public, anon, authenticated` unless the app
  must call them. Views: `with (security_invoker = true)`.
- Pure scoring functions take plain values (testable with literals).
- The service-role key is only ever used by the collector, never the app.
- `source_data_quality` (view, readable by everyone) feeds "Qualidade dos
  dados" in Mais, including `last_seen_at` (stale after 24 h: "verifique a
  recolha") and `sharp_price_changes` (live listings whose price moved by
  50 % or more in one step in the last 30 days).
- `collector_runs` is readable only by non-anonymous users. `requests` holds
  the requests each site used (from refresh.dart's "Requests used:" lines,
  parsed by report_run.dart), `counts` what the run did over both sites
  (`new`, `price_changes`, `removed`, `alerts`, from the log's own lines:
  `runCounts`; keep those log lines' wording). report_run.dart also sends a Telegram message
  when a run's status differs from the previous run's (`run_health.dart`:
  the error lines of each site, or "voltou a funcionar"), never twice for
  the same problem.
- Schedules live in Supabase, not in the workflows (GitHub's scheduler never
  started `collect.yml`): pg_cron jobs `collect-listings` (`40 */4 * * *`)
  and `weekly-summary` (`52 7 * * 1`) call `dispatch_workflow()`, which
  starts the workflow through GitHub's workflow_dispatch API with pg_net and
  the Vault secret `github_dispatch_token` (fine-grained, this repo only,
  Actions read/write; created by Rafael, see `docs/hosting.md`). Change a
  schedule with a migration calling `cron.schedule` with the same job name.
- Watchdog: pg_cron job `collection-watchdog` (`20 * * * *`) runs
  `check_collection_runs()`: no run recorded for 9 h sends a Telegram
  message (`send_telegram()`, pg_net, Vault secrets `telegram_bot_token`
  and `telegram_chat_id`), repeated once a day; the next run sends the
  recovery. State in `collection_watchdog` (one row, no API access).
- The app's next-run time (`collection_text.dart`) mirrors the
  `collect-listings` job: change both together.
- Watch out: `greatest`/`least` ignore nulls.

## Collection pipeline

`make refresh` runs `bin/refresh.dart`, one Dart process per run (Dart
starts once, the catalog is loaded once). For each site:
`planSearches` (tracked models) → `fetchSearches` saves the pages plus
`searches.json` (planned searches, search of each page) → `importBatch`:
save → markSeen → rematch → applyPriceChanges → setSearchKeys → applyPricesBeforeDrop
→ applyListingDates → saveSiteModels → (if `--full`) markRemoved; Standvirtual then reads new listings' details
(`enrichDetails`) with the same fetcher. Then once for all sites
(`finishRun`): markDuplicates → recalculateScores → generateAlerts →
Telegram notifications. The single-step commands (`fetch.dart`,
`collector.dart`, `enrich.dart`, `searches.dart`) reuse the same library
functions for manual work.

- **Searches** come from `motorcycles.olx_search` / `standvirtual_search` of
  the tracked models (`planSearches`). Models with the same address share one
  search; OLX gets `search[filter_float_year:from]` = the earliest
  `min_year` of those models. Oldest models first, so when the budget runs
  out the newest models' searches wait.
- **Removal is per search** (`removalPlan`): each listing stores the search
  that found it (`listings.search_key`); a run removes only listings of the
  searches it read in full. A search with a problem (unreadable page,
  missing pages, stale page, rejected record without an id) or not fetched
  keeps its listings. Listings with no search key are covered only when
  every planned search was read in full. Without a manifest (hand-saved
  pages, manual JSON) the whole input must be clean. The database refuses
  to remove more than 50% at once unless forced.
- **Standvirtual** search pages hold everything except the description
  (including `createdAt` -> `published_at` and the bump date ->
  `site_refreshed_at`; `apply_listing_dates` keeps the earliest publication
  and latest renewal); one
  page per search. Listing pages are read only for matched, non-duplicate
  listings without details (`details_checked_at is null`). The search
  result's `priceDrop` is stored as `price_before_drop` (highest seen, never
  creates alerts).
- **OLX** search results (`__PRERENDERED_STATE__`, 40 per page, `page=N`)
  hold the full description; no listing pages. Ads with
  `partner.code = 'standvirtual'` are copies of Standvirtual ads and are
  skipped. Ads without a price are rejected but count as live. `createdTime`
  is stored as `published_at`, `lastRefreshTime` (the date OLX shows) as
  `site_refreshed_at`.
- **Model matching** (`ModelResolver`, shared by all sources) reads its rules
  from the catalog: model name and `aliases` spelled within the first three
  words (also without closing letters: "CBR 650" = CBR650R), Honda code
  suffixes (A, AC), per-model `excluded_words` ("tracer" for the MT-07,
  "650f", "125f"), `engine_cc_min/max` as tiebreaker and guard (a model
  without limits, e.g. added in the app, is never picked by engine size
  alone). Ambiguous stays unmatched. Every import re-checks the model of
  the ads it read (`rematch_listings`), so a better rule also fixes
  listings already stored. Switching a model off unmatches its listings at once;
  switching it on matches them again by their stored brand and model
  (a matched listing stores the catalog names), removed ones included.
- Dealer boilerplate sentences are stripped from descriptions (they caused
  false duplicates). Duplicates are detected across sources too.
- Relisted ads (`mark_relists`, called at the end of `mark_duplicates`): a
  live listing that matches a gone ad (same model and year, duplicate
  similarity >= 70) which disappeared up to 90 days before it was first
  seen gets `relisted_from`, `relisted_since` (when the bike first went on
  sale, following earlier relists) and `relisted_price`. Shown on the
  listing page ("Anúncio publicado de novo") and a risk reason (see Scoring
  model).

## Fetching rules (do not loosen without asking Rafael)

- Only `https://www.standvirtual.com/motos/...` and
  `https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/...`,
  robots.txt read every run.
- 6-10 s between requests (counted from the end of the previous request,
  so work done in between counts), max 20 per run and 120 per day **per
  site** (Standvirtual's searches and listing pages share one fetcher, one
  robots.txt read and one budget),
  **never parallel**, no retries; stop on 403/429/503 or a non-normal page,
  then pause 24 h (state in `collector/.fetch_state.json` and
  `.fetch_state.olx.json`, cached between Actions runs). Reaching the run or
  daily limit after some pages were saved is not a failure: what was saved
  is imported.
- Honest user agent. Saved pages, manifests, generated search lists and
  fetch state are never committed (they contain sellers' contact details).
- Never store private sellers' names or anyone's phone numbers.

## Scoring model

- Fair value per listing (`listing_fair_prices`): median of the OTHER live
  listings of the same model, each adjusted with `age_mileage_factor` using
  the model's own rates (`model_depreciation`): least-squares fit of
  ln(price) on year and mileage over its live listings, from 30 listings,
  clamped (0-15 %/year, 0-1 %/1000 km) and blended with the general rates
  (4 %/year, 0.2 %/1000 km) weighted by count; below 30 the general rates.
  The mileage rate is never below 0.5 %/1000 km (a buyer's minimum: asking
  prices understate mileage). Comparables without year or mileage are left
  out when the listing has them. The app says the estimate comes from
  asking prices.
  Price score needs >= 2 comparables; risk price signal needs >= 3.
- Deal score = weighted average of available slices: price 35, year/mileage 20
  (70% mileage), risk 10 (inverted), equipment 15 (`listing_extras`: keywords
  in variant/description for quickshifter, exhaust, luggage, heated grips,
  protection, new tyres; 70 for one, +10 each, max 100; none found = slice
  skipped, never a penalty). Missing slices are skipped.
- Risk signals: price far below market, possible accident (text), missing
  mileage/year/location, thin description (only private sellers with details
  read), 3+ owners, no service book, imported, implausible mileage (under
  100 km on a bike 3+ years old, or over 25 000 km a year), relisted (5;
  `relisted_often` 10: twice, or on sale for over 90 days counting the
  earlier ads), the text contradicting the ad's fields
  (`text_contradictions`: year 2+ apart, more km, imported, no service
  book; 10 each); reassuring: first owner,
  service book, factory warranty (negative points, floor 0).
- Market behaviour per model (`model_market_behaviour`): time until leaving
  the market, share and size of price drops (measured from the higher of the
  first price seen and `price_before_drop`), depreciation rates. Show "ainda
  poucos dados" below 5 data points.
- Price to offer (`offer_text.dart`, app only): ceiling = asking price or
  the estimated value when asking is > 2 % above it; opening 6 % (private) /
  3 % (dealer) below it, more for long on sale (+3/5/7 % past 1x/2x/3x the
  model's typical time), relisted (+2 %), a model whose sellers often
  drop, high risk; less after a drop; 1-15 %, rounded down to 50 €.
- Distance from home: `places` (towns, municipalities, districts with
  coordinates; GeoNames CC BY 4.0), `user_home` (one place per account,
  set in Mais), `place_key()` (= the app's `placeKey`, keep them equal),
  and the computed field `listings.distance_km` (from the caller's home;
  select it explicitly, it is never part of `*`). Saved searches have
  `max_distance_km`, matched against the search owner's home.
- Dealer figures (`dealer_reliability` view, per dealer name trimmed and
  case-folded, both sites; shown as "O stand" on dealer listings): bikes,
  live, relisted, sharp price changes, missing mileage, repeated used
  bikes on the same site, price dropped. Not in the Deal Score yet (15.7).
- Cost of ownership (`ownership_cost.dart`, app only): per year =
  average depreciation over the years kept (model's curve at the owner's
  km/year) + IUC (category E table by the model's engine size, nothing
  under 10 €; **check `iucBands` every January**) + the owner's insurance
  (left out until entered) + tyres, services and chain kit by engine size.
  The owner's figures live in `ownership_settings` (one row per account).
- New-bike comparison: `motorcycles.new_price_reference` (+ checked date),
  shown on the detail page; hidden when the model has no reference price.

## Alerts

Types: `new_listing`, `price_reduction` (>= 1% drop, one per price-history
row), `excellent_opportunity` (score >= 80, risk < 50, one per user/listing,
`excellent_since`), `listing_removed` (only for listings the user was already
alerted about), `back_on_market` (a relist of an ad the person followed:
favourite or alerted by an active saved search; once per person and new
ad; relists first seen in the last 14 days). Only events after the saved search was created. Saved
searches can also require a minimum Deal Score / maximum Risk Score,
a maximum distance from the owner's home and equipment (`extras`, all
required; `listing_extras` codes); all in `saved_search_matches`.
`notified_at` marks alerts already pushed to Telegram (only real accounts).
Weekly summary (Mondays, `weekly_summary.dart`, pure logic in
`notify/weekly_summary.dart`): tracked models, non-duplicates; new = first
seen in the last 7 days, gone = removed with `last_checked_at` in them,
drop = last price this week >= 1% below the price the week started with
(live listings), best deals = live, risk < 50, by Deal Score.
Favourites (`listing_favourites`: user, listing, private note; owner-only
RLS) alert their owner without a saved search (`saved_search_id` null):
`generate_favourite_alerts()` gives every `price_reduction` (>= 1%) and the
`listing_removed` after the listing became a favourite; the alerts' unique
indexes keep one alert per price change / removal when a saved search also
covers it. A favourite also holds the viewing checklist's marks
(`checklist jsonb`, `{"tyres": {"mark": "ok"|"issue", "note": ...}}`); the
items live in the app (`viewing_checklist.dart`), keys never change.
Reimporting everything after a reset: create saved searches AFTER the import,
or every listing counts as new.
