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
CB300R, CBR500R, CB750 Hornet, CBR600RR. The owner can add more from the app.

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
- **Migrations:** Rafael runs `make db-push`. When the new collector code
  needs the new schema, say "run `make db-push` before merging" and keep the
  migration compatible with the code still on `main`.
- You cannot reach Supabase from the sandbox. Test SQL on a local Postgres
  with all migrations applied (stub the `auth` schema: `uid()`, `jwt()`,
  `role()`, `users`; roles `anon`, `authenticated`, `service_role`).
- Flutter is not installed in the sandbox and must not be downloaded: Rafael
  tests the app. Pure Dart logic in the app can be tested with plain Dart
  (`package:test`) on copies of the files. The deploy runs `flutter test`
  and `flutter build web`.

## Layout

```
app/        Flutter Web/PWA (package name: motorcycle_deal_tracker)
collector/  Pure Dart CLI: fetch, parse, store, score, alert (service-role key)
supabase/   Migrations (Postgres: scoring, alerts, views, RLS)
docs/       sources.md (data-source decisions, keep updated), hosting.md,
            roadmap.status.md, concept.status.md, code-quality.md (backlog)
.github/workflows/collect.yml     Collection every 4 hours (minute 40, UTC)
.github/workflows/weekly-summary.yml  Mondays 07:52 UTC: the week's summary
                                  on Telegram (bin/weekly_summary.dart)
.github/workflows/deploy-web.yml  Test, build and publish the app to
                                  Cloudflare Pages on merges touching app/
.github/workflows/code-quality.yml  After every 5 merged PRs, Claude does up
                                  to 3 items of docs/code-quality.md (or
                                  refills it with up to 10 when empty) and
                                  opens one PR labelled code-quality
                                  (merges since the tag
                                  code-quality-reviewed are counted)
Makefile    All commands (`make help`)
```

## Commands

```
make check                     analyze + test app and collector (before every commit)
make app-run                   run the app in Chrome (app/env/dev.json)
make db-new NAME=x / db-push   create / apply migrations
make searches SITE=olx|standvirtual   write the tracked models' searches
make fetch-dry|fetch SITE=...  download those search pages (polite, capped)
make collect-dry|collect SOURCE=manual|standvirtual|standvirtual-search|olx-search FILE=... [ARGS=--full]
make enrich-dry|enrich         read Standvirtual listing pages for details (max 10 per run)
make refresh ARGS=--full       one process for both sites (bin/refresh.dart): searches -> fetch
                               -> import (with removal) -> enrich, then scores/alerts once
make refresh-olx|refresh-standvirtual   the same for one site
make weekly-summary [ARGS=--dry-run]   send (or print) the week's Telegram summary
```

Local secrets live in `collector/.env` (gitignored, loaded by the Makefile):
`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `TELEGRAM_BOT_TOKEN`,
`TELEGRAM_CHAT_ID`. GitHub Actions uses repository secrets with the same
names, plus `SUPABASE_PUBLISHABLE_KEY`, `CLOUDFLARE_API_TOKEN` and
`CLOUDFLARE_ACCOUNT_ID` for the web deploy, and `CLAUDE_CODE_OAUTH_TOKEN`
for the code-quality review.

## App conventions (Flutter)

- Clean architecture per feature: `domain/` (entities, repository interfaces),
  `data/` (models with `fromJson`, Supabase repositories), `presentation/`
  (cubits, pages, widgets). Features: `listings`, `collector_status`,
  `settings` (the "Mais" tab).
- Text built from data lives in pure functions (`*_text.dart`) with tests.
- State: flutter_bloc Cubits + Equatable states. DI: get_it. Shared cubits
  (`ListingsCubit`, `SavedSearchesCubit`, `AlertsCubit`, `CollectorStatusCubit`)
  are lazy singletons, provided in routes with `BlocProvider.value`. The
  shell (`AppShell`) loads `AlertsCubit` at start and on app resume for the
  unread badge on Alertas.
- Routing: go_router `StatefulShellRoute` (Ofertas / Pesquisas / Alertas /
  Mais). Account, "Modelos acompanhados" and collection status live in Mais.
  Use `context.go`, not `push`, so web URLs stay correct. Exception: full
  pages outside the shell (`/models`, `/add`) are pushed. `/add` (Adicionar
  anúncio) also opens from the iPhone share button with the ad in its query
  (`u`, `t`, `p`, `d`, `l`, `i`; `shared_listing_text.dart`,
  `share_script.dart`).
- Formatting: `Formatters.price`, `.mileage`, `.date`, `.daysAgo`
  (`core/formatting/formatters.dart`).
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
  dados" in Mais.
- `collector_runs` is readable only by non-anonymous users. `requests` holds
  the requests each site used (from refresh.dart's "Requests used:" lines,
  parsed by report_run.dart).
- The app's next-run time (`collection_text.dart`) mirrors the cron in
  `collect.yml`: change both together.
- Watch out: `greatest`/`least` ignore nulls.

## Collection pipeline

`make refresh` runs `bin/refresh.dart`, one Dart process per run (Dart
starts once, the catalog is loaded once). For each site:
`planSearches` (tracked models) → `fetchSearches` saves the pages plus
`searches.json` (planned searches, search of each page) → `importBatch`:
save → markSeen → applyPriceChanges → setSearchKeys → applyPricesBeforeDrop
→ applyListingDates → (if `--full`) markRemoved; Standvirtual then reads new listings' details
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
- **Standvirtual** search pages hold everything except the description; one
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
  "650f", "125f"), `engine_cc_min/max` as tiebreaker and guard. Ambiguous
  stays unmatched. Switching a model off unmatches its listings at once;
  switching it on matches them again by their stored brand and model
  (a matched listing stores the catalog names), removed ones included.
- Dealer boilerplate sentences are stripped from descriptions (they caused
  false duplicates). Duplicates are detected across sources too.

## Fetching rules (do not loosen without asking Rafael)

- Only `https://www.standvirtual.com/motos/...` and
  `https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/...`,
  robots.txt read every run. Facebook Marketplace and CustoJusto forbid
  automated access (`docs/sources.md`): never collect them; their ads are
  saved by the owner ("Adicionar anúncio", `add_shared_listing`).
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
  Price score needs >= 2 comparables; risk price signal needs >= 3.
- Deal score = weighted average of available slices: price 35, year/mileage 20
  (70% mileage), risk 10 (inverted). Missing slices are skipped.
- Risk signals: price far below market, possible accident (text), missing
  mileage/year/location, thin description (only private sellers with details
  read), 3+ owners, no service book, imported; reassuring: first owner,
  service book, factory warranty (negative points, floor 0).
- Market behaviour per model (`model_market_behaviour`): time until leaving
  the market, share and size of price drops (measured from the higher of the
  first price seen and `price_before_drop`), depreciation rates. Show "ainda
  poucos dados" below 5 data points.
- New-bike comparison: `motorcycles.new_price_reference` (+ checked date),
  shown on the detail page; hidden when the model has no reference price.

## Alerts

Types: `new_listing`, `price_reduction` (>= 1% drop, one per price-history
row), `excellent_opportunity` (score >= 80, risk < 50, one per user/listing,
`excellent_since`), `listing_removed` (only for listings the user was already
alerted about). Only events after the saved search was created. Saved
searches can also require a minimum Deal Score / maximum Risk Score.
`notified_at` marks alerts already pushed to Telegram (only real accounts).
Weekly summary (Mondays, `weekly_summary.dart`, pure logic in
`notify/weekly_summary.dart`): tracked models, non-duplicates; new = first
seen in the last 7 days, gone = removed with `last_checked_at` in them,
drop = last price this week >= 1% below the price the week started with
(live listings), best deals = live, risk < 50, by Deal Score.
Reimporting everything after a reset: create saved searches AFTER the import,
or every listing counts as new.
