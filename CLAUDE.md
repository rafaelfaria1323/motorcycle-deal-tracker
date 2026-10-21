# Motorcycle Deal Tracker

Personal web app/PWA (single owner: Rafael) that watches the Portuguese used
and semi-new motorcycle market, tracks price and status history, and ranks
listings with an explainable **Deal Score** plus a separate **Risk Score**.
Alerts go to the app, to each account's devices as notifications (Web
Push) and, an admin's, to the owner's Telegram chat. Others join through
invite links made in the app.

Progress lives in `docs/roadmap.status.md` (step by step) and
`docs/concept.status.md` (against the original concept). **Update both in
the same PR as the work.** Also keep the READMEs (`README.md`,
`app/README.md`, `collector/README.md`) and this file true in the same PR
when a change affects what they say (screens, commands, secrets, layout,
pipeline, rules).

Catalog (table `motorcycles`): 13 models. Each account chooses its own
models and first years in the app ("Modelos acompanhados", table
`user_models`); the collector searches every model any account follows
(`motorcycles.is_active` = someone follows it, `min_year` = the earliest
year asked, kept by `refresh_collected_model()`), so one collection fills
the database for every account. Collected at the switch: Yamaha MT-07,
Yamaha R7, Honda CB650R, Honda CBR650R. Available: Tracer 7, R1, R3, R9,
CB125R, CB300R, CBR500R, CB750 Hornet, CBR600RR. Any account can add more
from the app (it then follows them):
brand and model picked from `site_models` (the sites' filter lists, stored
by every import from the search pages; view `site_makes` for the brands),
optional engine size (name "Forza 350", Standvirtual `q-350`, engine range
+-10 %; a model named with a size but added without one gets that size's
range, `engine_range_from_name`), searches built from the sites' ids (OLX only when OLX's own list
has the model), or typed by hand.

## How to work on this project

- Rafael wants you to **make the technical decisions yourself** (best,
  most robust option) and explain them briefly, not present menus of choices.
  Ask only when a decision is really his (cost, risk he takes on, loosening
  the fetching rules).
- **Prefer tools without AI.** AI is fine only where it is free, and a
  fixed, free tool wins whenever it can do the same job. The app and the
  collector use no AI (scores, estimates and alerts are rules and
  statistics). Checks: analyzer rules (`*/analysis_options.yaml`),
  `make duplication` (jscpd), `make coverage` (floors in the Makefile),
  `make lint-scripts` (actionlint, shellcheck), `make dead-code`
  (dart_code_linter, app only), `make sql-lint`
  (plpgsql_check, splinter, squawk), mutation testing, Dependabot; the
  Claude backlog passes only look for what needs judgment.
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
  extend a test with every migration that changes behaviour. `make sql-lint`
  must stay clean: fix a splinter finding, or allow it in
  `supabase/lint_allow.txt` with the reason.
- Flutter is not installed in the sandbox and must not be downloaded: Rafael
  tests the app. Pure Dart logic in the app can be tested with plain Dart
  (`package:test`) on copies of the files. The deploy runs `flutter test`
  and `flutter build web --wasm` (WebAssembly where the browser supports
  it, JavaScript otherwise; no cross-origin isolation headers, which would
  block the listing photos).

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
                                  Lighthouse (mobile) scores and load times
                                  in that comment (report only,
                                  tool/lighthouse_summary.py); older builds
                                  deleted on each push, the preview deleted
                                  when the PR closes
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
                                  Both PAUSED since 2026-10-20 (Rafael): no
                                  runs after merges until he says so; only
                                  "Run workflow" starts one
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
.github/dependabot.yml            Weekly dependency PRs (app, collector, Actions)
.claude/hooks/session-start.sh  Cloud sessions only: Dart SDK on PATH, collector
                                  dependencies, local Postgres (PGHOST set), so
                                  make collector-check / tool-check / db-test run
Makefile    All commands (`make help`)
```

## Commands

```
make check                     analyze + test app and collector, test tool/ (before every commit)
make coverage / duplication    coverage floors and copy-paste check (also in CI)
make lint-scripts              actionlint on the workflows, shellcheck on tool/*.sh (also in CI)
make dead-code                 unused code and files in the app (dart_code_linter; also in CI)
make app-run                   run the app in Chrome (app/env/dev.json)
make db-new NAME=x / db-push   create / apply migrations (merging applies them too)
make db-test                   migrations + SQL tests on a local Postgres
make sql-lint                  db-test, then plpgsql_check, splinter (supabase/lint_allow.txt)
                               and squawk on new migrations (.squawk.toml); also in CI
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
(starts the scheduled workflows), `telegram_bot_token` /
`telegram_chat_id` (the watchdog's messages), `vapid_private_key` (Web
Push) and `service_url` / `service_role_key` (Auth's admin API, for
invites; written by the collector on each run).

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
- Auth: anonymous session on first visit; accounts sign in with email +
  password. Accounts come from invites (no SMTP, no open sign-up): an
  admin (`app_admins`, `is_admin()`, `require_admin()`; the oldest account
  was the first) creates one in Mais › "Contas e convites" (`create_invite`,
  table `invites`: one account, 14 days) and shares the link
  (`/#/join?code=…`, `core/platform/share.dart`: the phone's share sheet,
  else the link is copied); the invite page calls `redeem_invite`, which
  makes the account, already confirmed, through Supabase Auth's admin API
  (`auth_admin_request`: the `http` extension with the URL and
  service-role key the collector stores in the Vault each run,
  `store_service_access`; never writes `auth.users`), then signs in.
  Admins also list accounts (`admin_accounts`), make or unmake admins
  (`set_admin`, never themselves) and remove accounts (`remove_account`).
  Catalog
  changes go through RPCs that call `require_account()` (signed in, not
  anonymous). Models per account: lists read `listings.in_my_models` and
  `motorcycles.tracked_by_me` / `my_min_year` (computed fields: the
  caller's own list, or every collected model for an anonymous session; a
  new account follows nothing). Saved searches match only their owner's
  models (`owner_tracks`). Notifications reach each account's own devices
  (Web Push, see Alerts); Telegram still goes to the owner's one chat.
- Photos: `Image.network` with `WebHtmlElementStrategy.prefer` (the photo
  CDNs don't send CORS headers, so an `<img>` element is the only way).
- Lists load `ListingModel.summaryColumns`, never `*` (descriptions are big);
  the deals list is paged (40 per page, more on scroll).
- Look: `app/theme/app_theme.dart` (hand-made colour schemes: cool greys,
  racing-orange primary, white cards with a hairline border, no shadows or
  tints) and `app_colors.dart` (`AppColors.of(context)`: positive/negative
  and Deal Score band colours, light and dark). Never hard-code colours in
  widgets. `theme_contrast_test.dart` checks the WCAG contrast of the
  colours (text 4.5:1, score badges 3:1): keep it green when changing them. Fonts are bundled (`assets/fonts`, Latin subset): Barlow for
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
  search, asking for the earliest `min_year` of those models (OLX
  `search[filter_float_year:from]`, Standvirtual
  `search[filter_float_first_registration_year:from]`). On OLX, whose model
  filter is a family ("R", "CB"), a search also asks for the engine-size
  band that holds all its models (`olxEngineBand`, only bands seen on the
  site: today `501-1000-cc`), so other models' ads aren't read. Every page of a
  search is read (OLX 40 listings each, Standvirtual 32, `?page=N`). Oldest models first, so when the budget runs
  out the newest models' searches wait.
- **Removal is per search** (`removalPlan`): each listing stores the search
  that found it (`listings.search_key`); a run removes only listings of the
  searches it read in full. A search with a problem (unreadable page,
  missing pages, stale page, rejected record without an id) or not fetched
  keeps its listings. Listings with no search key, or one no planned
  search has any more (the address changed), are covered only when every
  planned search was read in full; the latter only for a tracked model and
  within its years (`in_removal_scope`). Without a manifest (hand-saved
  pages, manual JSON) the whole input must be clean. The database refuses
  to remove more than 50% at once unless forced.
- **Standvirtual** search pages hold everything except the description
  (including `createdAt` -> `published_at` and the bump date ->
  `site_refreshed_at`; `apply_listing_dates` keeps the earliest publication
  and latest renewal). Listing pages are read only for matched, non-duplicate
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
  without limits is never picked by engine size alone; "350cc" reads as
  "350"). Ambiguous stays unmatched. Every import re-checks the model of
  the ads it read (`rematch_listings`), so a better rule also fixes
  listings already stored. When the last account stops following a model
  its listings are unmatched at once; when one follows it again they are
  matched by their stored brand and model (a matched listing stores the
  catalog names), removed ones included.
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
  is imported. A request that fails (a timeout) or a block after some pages
  were saved also imports them, but the run still counts as failed; a
  search with a page missing is not read in full, so it removes nothing.
- Honest user agent. Saved pages, manifests, generated search lists and
  fetch state are never committed (they contain sellers' contact details).
- Never store private sellers' names or anyone's phone numbers.

## Scoring model

- Fair value per listing (`listing_fair_prices`): median of the OTHER live
  listings of the same model (only those within 3 years of the listing's
  when there are at least 5 of them; ads under 300 € never count), each
  adjusted with `age_mileage_factor` (x0.35-2.5) using
  the model's own rates (`model_depreciation`): least-squares fit of
  ln(price) on year and mileage over its live listings (ads under 300 € left out), from 30 listings,
  clamped (0-15 %/year, 0-1 %/1000 km) and blended with the general rates
  (4 %/year, 0.2 %/1000 km) weighted by count; below 30 the general rates.
  The mileage rate is never below 0.5 %/1000 km (a buyer's minimum: asking
  prices understate mileage). Comparables without year or mileage are left
  out when the listing has them. The app says the estimate comes from
  asking prices.
  Price score (2.5 points per %: 0 / 100 at 20 % above / below) and the
  risk's price signal need >= 3 comparables; so does the app's offer.
- Deal score = weighted average of the available slices: price 35,
  year/mileage 20 (70% mileage, judged against the bike's age:
  `mileage_use_score`, normal = 5 000 km a year from mid-year registration,
  at least one year's, age counted in days (`decimal_year`, so nothing
  jumps on 1 January) (`expected_mileage`); 100 up to half the normal, 75
  at it, 50 at 1.5x, 0 from 2.5x; no mileage but a year: 50; the app's
  `mileageForAge` says the same in words, keep both in step), risk 10
  (inverted); then + 2 points per extra found, at most + 10, never above
  100 (`listing_extras`: keywords in variant/description for quickshifter,
  exhaust, luggage, heated grips, protection (also "cogumelos"), new tyres,
  short plate holder, tinted or sport screen, adjustable levers, bar-end
  mirrors, phone mount/USB, alarm/tracker, steering damper, centre stand,
  cruise control, upgraded suspension, LED indicators, passenger grab
  handles, original parts included (so it can go back to stock); codes
  never change, the app's `extraLabels` and the saved-search check list the
  same). Extras are a bonus, not a slice: as a slice they lowered good
  scores. Without the price slice the score is at most 70
  (`capped_without_price`). Missing slices are skipped.
- Risk signals: price far below market, possible accident (text,
  `mentions_accident`: "nunca teve acidentes", "livre de sinistros" and
  insurance wording don't count), missing
  mileage/year/location, thin description (only private sellers with details
  read), 3+ owners, no service book, imported, implausible mileage (under
  100 km on a bike 3+ years old, or over 25 000 km a year), relisted (5;
  `relisted_often` 10: twice, or on sale for over 90 days counting the
  earlier ads), the text contradicting the ad's fields
  (`text_contradictions`: year 2+ apart (not a year still to come or after
  "até"), more km, imported, no service
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
  drop, high risk; less after a drop and less by however far the asking
  price is already below the estimate; 1-10 %, and never under 90 % of the
  estimated value; rounded down to 50 €. The plan: the opening, one offer
  halfway ("Se recusar") and the ceiling as the last, each with a message
  to copy; "O vendedor pediu" answers a counter-offer (accept up to the
  second offer, propose halfway up to the ceiling, above it offer the
  ceiling and walk away) with the message to send. Arguments to quote
  (`negotiation_text.dart`, strongest first): problems marked at the visit,
  price above the estimate, up to 3 cheaper live ads of the same model
  (year +-1, no more km: `getCheaperSimilar`), km above normal, risk
  reasons, long on sale, an earlier drop, tyres of a 5+ year-old bike.
  Visit: a checklist item marked "Problema" takes its repair cost
  (`repairCost`, tyres/chain/service from the running costs) off the
  opening and the ceiling; documents, registry, cold start and test ride
  are blockers, not prices. Also shown: "Pressa do vendedor"
  (`sellerUrgency`: past the model's typical time 1 point, twice it 2,
  three times it 3, an earlier drop 1, relisted 1 / often 2, an ad 30+
  days old renewed on the site in the last 30 days 1; 3+ alta, 1-2 média,
  else baixa)
  and, for dealers, what to ask for besides the price (`dealerAsks`:
  service, tyres when due, written warranty, registration paid) with a
  message.
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

Types: `target_price_reached` (a favourite's `target_price`, set from
"Quanto oferecer": the listing is live at that price or less, at a price
seen after `target_set_at` (stamped by a trigger); old_price = the target,
one alert per target), `new_listing`, `price_reduction` (>= 1% drop, one per price-history
row), `excellent_opportunity` (score >= 80, risk < 50, one per user/listing,
`excellent_since`), `listing_removed` (only for listings the user was already
alerted about), `back_on_market` (a relist of an ad the person followed:
favourite or alerted by an active saved search; once per person and new
ad; relists first seen in the last 14 days). Only events after the saved search was created. Saved
searches can also require a minimum Deal Score / maximum Risk Score,
a maximum distance from the owner's home and equipment (`extras`, all
required; `listing_extras` codes); all in `saved_search_matches`.
`notified_at` marks alerts already sent (only real accounts): to the
account's devices by Web Push (`push_subscriptions`, saved from Mais ›
"Notificações neste aparelho"; on the iPhone only in the home-screen app)
and, admins' only (`pending_notifications.to_telegram`), to the owner's
Telegram chat. The collector sends them itself
(`notify/web_push.dart`: RFC 8291 encryption and RFC 8292 VAPID with
pointycastle, no third party); its key pair is made on the first run
(`store_push_keys`: public key in `push_config`, private in Vault
`vapid_private_key`). The app's `web/push.js` (subscribe, state) and
`web/push_sw.js` (shows the notification; a tap opens `/#/deals/<id>`)
are plain JS called from `core/platform/push.dart`; gone devices (404/410)
are deleted.
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
