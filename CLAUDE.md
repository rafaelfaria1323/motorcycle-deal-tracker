# Motorcycle Deal Tracker

Personal web app/PWA (single owner: Rafael) that watches the Portuguese used
and semi-new motorcycle market, tracks price and status history, and ranks
listings with an explainable **Deal Score** plus a separate **Risk Score**.
Alerts go to the app and to each account's devices as notifications (Web
Push; Firebase Cloud Messaging in the Android app), and so does each account's weekly summary; Telegram keeps the
database's own warnings (watchdog, GitHub token). Others join through
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
range, `engine_range_from_name`), or brand and model entered by name.
Both OLX and Standvirtual are always searched: `ensure_model_searches()`
keeps existing addresses and fills missing ones with `catalog_search_url()`
(known site ids first; model words otherwise, plus the brand if its filter
is unknown). Existing single-source models are backfilled too. The form
never asks for search URLs; aliases sit under "Outros nomes do modelo".

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
  (plpgsql_check, splinter, squawk, safeupdate), mutation testing, Dependabot; the
  Claude backlog passes only look for what needs judgment.
- Work in small verifiable steps: implement → test → commit. Each step ends
  with a definition of done.
- Answers to Rafael in English; **all UI text has Portuguese (pt-PT) and
  English (en-GB) resources**, Portuguese by default. Portuguese speaks to
  the user as "você" ("Verifique", "a sua conta"; never "tu", checked by
  `app/test/voice_test.dart`, including the Portuguese ARB). Code, comments
  and commit messages are in English.
- Commit style: `feat(scope): what (step id)`, e.g.
  `feat(alerts): push new alerts to Telegram after each run (11.1)`.
- Flow: push to the `claude/...` branch, open a PR, Rafael merges. Once a PR
  is merged, start the next work from a fresh `origin/main`.
- **Migrations** are applied on merge: `deploy-web.yml`'s `migrate` job
  asks the database which migrations it is missing (dry run; not the
  merge's diff: a queued deploy is replaced by the next merge's, so a
  merge's own run may never happen); if any, it runs `make db-test` again, then
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
docs/       sources.md (data-source decisions, keep updated), hosting.md
            (also how to replace each secret),
            roadmap.status.md, concept.status.md, code-quality.md and
            test-hardening.md (backlogs of the automatic passes),
            paid-plans.md (paid plans and other income: a plan, not
            started; roadmap Sprint 16)
.github/workflows/collect.yml     Collection at 00:00, 08:00 and every 2 h
                                  from 12:00 to 20:00 (Lisbon time),
                                  started by Supabase pg_cron (see below)
.github/workflows/weekly-summary.yml  Mondays 07:52 UTC (pg_cron): each account's
                                  summary of the week, kept for the app and
                                  pushed to its devices (bin/weekly_summary.dart);
                                  input `account`: only that one
.github/workflows/push-test.yml   A test notification (bin/push_test.dart) to the
                                  devices of whoever asked in the app; input
                                  `kind`: an example of one alert or
                                  collection message (`pushTestKinds`)
.github/workflows/check.yml       `make check` (with Flutter), `make app-smoke`
                                  (offline Chrome flow) and `make db-test`
                                  (Postgres service) on every pull request to main
.github/workflows/preview-web.yml Every PR touching app/: the app built and
                                  published to pr-<number>.<project>.pages.dev,
                                  linked in one comment on the PR (real
                                  database; the PR's migrations not applied);
                                  Lighthouse (mobile) scores, load times,
                                  largest element, biggest downloads and
                                  failed checks in that comment (report
                                  only, tool/lighthouse_summary.py; the
                                  whole report kept 14 days as the run's
                                  artifact lighthouse-pr-<number>); older builds
                                  deleted on each push, the preview deleted
                                  when the PR closes
.github/workflows/deploy-web.yml  On merges touching app/ or adding
                                  migrations: apply the migrations the
                                  database is missing (tested again
                                  first; skipped if none),
                                  then test, build and publish the app to
                                  Cloudflare Pages; then the Android APK
                                  (job android, tool/android_build.sh:
                                  app/android made by `flutter create`,
                                  never committed, fitted by
                                  tool/android_manifest.py; signed with
                                  the secrets' key, on the GitHub release
                                  `android` with android.json, the build
                                  number the app compares with its own)
.github/workflows/android-check.yml  PRs touching app/packages, the
                                  pubspec or the Android build scripts:
                                  the APK built (not signed or published),
                                  so a broken Android build shows before
                                  the merge
.github/workflows/code-quality.yml  Claude pass on docs/code-quality.md: how
                                  the code is written (duplication, dead
                                  code, structure, theme, names); one PR
                                  labelled code-quality; merges since the
                                  tag code-quality-reviewed are counted
.github/workflows/test-hardening.yml  The same on docs/test-hardening.md:
                                  bugs, surviving mutants, redundant tests
                                  (label test-hardening); never overlaps
                                  with code quality. Both passes PAUSED since
                                  2026-10-20 (Rafael): no runs after merges
                                  until he says so; only "Run workflow"
                                  starts one (mutation testing still runs)
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
.github/dependabot.yml            Weekly dependency PRs (app, collector, Actions)
                                  (not shared_preferences_android 2.4.28 or
                                  path_provider_android 2.2.23: their JNI
                                  releases fail in the release APK)
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
make app-smoke                 offline Chrome flow; matching ChromeDriver on PATH
make db-new NAME=x / db-push   create / apply migrations (merging applies them too)
make db-test                   migrations + SQL tests on a local Postgres
make sql-lint                  db-test, then plpgsql_check, splinter (supabase/lint_allow.txt),
                               squawk on new migrations (.squawk.toml) and safeupdate
                               (tool/safe_updates.py); also in CI
make searches SITE=olx|standvirtual   write the tracked models' searches
make fetch-dry|fetch SITE=...  download those search pages (polite, capped)
make collect-dry|collect SOURCE=manual|standvirtual|standvirtual-search|olx-search FILE=... [ARGS=--full]
make enrich-dry|enrich         read Standvirtual listing pages for details (10 by default)
make refresh ARGS=--full       one process for both sites (bin/refresh.dart): searches -> fetch
                               -> import (with removal) -> enrich, then scores/alerts once
make refresh-olx|refresh-standvirtual   the same for one site
make push-test                 send a test notification to the admins' devices (Web Push)
make weekly-summary [ARGS=--dry-run]   make and send (or print) each account's weekly summary
make mutation PKG=collector|app FILES="lib/..."   mutation testing of those files
                               (needs `dart pub global activate mutation_test`)
```

The browser smoke uses the SDK's `integration_test`, the real `App` and
router, and in-memory repositories from
`app/integration_test/support/interface_fixture.dart` (also used by the
widget tests). It needs no Supabase credentials and does not test sign-in
or native pushes. CI runs it separately from `make check`. Collector HTML
parsing uses pure-Dart `html`; the fetcher's time comes from `clock`, with
`fake_async` for deterministic timing tests and no fetching-policy changes.

Local secrets live in `collector/.env` (gitignored, loaded by the Makefile):
`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `TELEGRAM_BOT_TOKEN`,
`TELEGRAM_CHAT_ID`. GitHub Actions uses repository secrets with the same
names, plus `SUPABASE_PUBLISHABLE_KEY`, `CLOUDFLARE_API_TOKEN` and
`CLOUDFLARE_ACCOUNT_ID` for the web deploy, `ANDROID_KEYSTORE_BASE64` and
`ANDROID_KEYSTORE_PASSWORD` for the Android app (PKCS12, alias `upload`;
the same key forever, or updates won't install), `SUPABASE_DB_URL` (Session
pooler connection string, `[YOUR-PASSWORD]` left in) and
`SUPABASE_DB_PASSWORD` for the migrations, `FIREBASE_ANDROID_CONFIG`
(the Firebase project's `google-services.json`, built into the APK) and
`FIREBASE_SERVICE_ACCOUNT` (its service account key, the collector's
sender) for the Android app's notifications, and `CLAUDE_CODE_OAUTH_TOKEN`
for the code-quality review. Supabase's Vault holds `github_dispatch_token`
(starts the scheduled workflows), `telegram_bot_token` /
`telegram_chat_id` (the watchdog's messages), `vapid_private_key` (Web
Push) and `service_url` / `service_role_key` (Auth's admin API, for
invites; written by the collector on each run).

## App conventions (Flutter)

- Localization: Mais › "Idioma" / More › "Language"; bundled
  `app/lib/l10n/app_pt.arb` and `app_en.arb`, generated by `flutter gen-l10n`
  (`l10n.yaml`; generated Dart is ignored). Widgets use `context.strings`
  and `context.language`; text helpers and formatters receive `AppLanguage`,
  never a mutable global Intl locale. `LanguageCubit` follows the account
  lifecycle: cached device choice at startup, that account's own choice
  on sign-in (Portuguese when unset), device choice retained on sign-out.
  Real accounts save to owner-only `account_languages`; anonymous choices
  stay local. Load/save errors are explicit, not Portuguese fallbacks.
  Locale changes preserve the router and relocalize errors from structured
  state. Seller content, user-entered names/notes, model/place names and raw
  technical diagnostics are never translated. The collector's separate
  pure-Dart catalog localizes each account's notifications and summary;
  stored weekly-summary JSON stays language-independent. No translation
  service or runtime AI.
- Start: `main.dart` runs `Startup` (`app/startup.dart`), which draws at
  once (Android keeps its splash until the first frame): a spinner while
  Supabase (20 s at most) and the session start, then the app, or the
  reason it failed with "Tentar novamente". The first listings are asked
  for during the sign-in, not after it (no session reads as an anonymous
  one). That screen is a bare
  `Theme` + `Material`, never a `MaterialApp` (on the web its navigator
  would overwrite a notification's `/#/deals/<id>` and its `Title` the
  `theme-color`).
- Clean architecture per feature: `domain/` (entities, repository interfaces),
  `data/` (models with `fromJson`, Supabase repositories), `presentation/`
  (cubits, pages, widgets). Features: `listings`, `collector_status`,
  `settings` (the "Mais" tab).
- Text built from data lives in pure functions (`*_text.dart`) with tests.
- State: flutter_bloc Cubits + Equatable states. DI: get_it. Shared cubits
  (`ListingsCubit`, `SavedSearchesCubit`, `AlertsCubit`, `CollectorStatusCubit`,
  `FavouritesCubit`, `ListingCardPreferencesCubit`, `LanguageCubit`, and `SessionCubit` for the signed-in state: widgets never
  read Supabase's auth directly) are lazy singletons, provided in routes with
  `BlocProvider.value`. The shell (`AppShell`) loads `AlertsCubit` at start
  and on app resume for the unread badge on Alertas, and `FavouritesCubit`
  at start for the stars on the cards. `ListingsCubit`, `SavedSearchesCubit`,
  `AlertsCubit` and `FavouritesCubit` inherit `AccountScopedCubit`
  (`core/auth/account_scoped_cubit.dart`): they follow `SessionCubit`'s
  account id themselves, clear and reload on account changes or sign-out,
  and ignore earlier in-flight loads and writes, including optimistic
  rollbacks and match counts. Auth widgets never reload them. The same
  account's token refresh and anonymous startup do not reset them;
  listing filters and sort survive account changes. DI closes these
  singletons and their session subscriptions.
  `ListingCardPreferencesCubit` loads on first use and follows
  `SessionCubit`'s user id itself: a different account or sign-out resets
  the cards at once, ignoring earlier in-flight loads and saves.
- Routing: go_router `StatefulShellRoute` (Ofertas / Pesquisas / Alertas /
  Mais). Account, "Modelos acompanhados" and collection status live in Mais.
  Switching tabs uses `context.go`; full pages outside the shell
  (`/models`, `/market`, `/favourites`, `/compare?ids=a,b,c`, `/summary`)
  and an ad (`/deals/<id>`, from anywhere) are pushed, so back returns
  where the person was; pushed pages show their own address
  (`GoRouter.optionURLReflectsImperativeAPIs`, set in `main.dart`). The
  ad and its photos (`/deals/<id>/photos`, `extra` = `PhotoViewerArgs`,
  JSON so the browser's history keeps it) open on the root navigator
  (`parentNavigatorKey`), above the tab bar. Android's back on a tab
  other than Ofertas goes to Ofertas (`AppShell`'s `PopScope`). Every
  in-app back arrow calls `goBack` (`core/widgets/page_back_button.dart`):
  in the browser `history.back()` while the entry before is the app's
  (`core/platform/browser_back.dart`), else pop or the fallback in place
  of the current entry (`Router.neglect`); a plain pop on the web would
  add an entry, and the back swipe would reopen the page.
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
  (`set_admin`, never themselves) and remove accounts (`remove_account`),
  and start `collect.yml` now from Mais › Recolha de dados
  (`start_workflow`: GitHub's dispatch API through `http` with the Vault
  token, at most once per 15 minutes, `workflow_starts`; the collector's
  caps still apply). Any signed-in account can also start `push-test.yml`
  (once per 30 seconds per account; Mais › "Notificações neste aparelho" ›
  "Enviar notificação de teste", which asks which: `start_workflow`'s
  `p_kind`, the workflow's input `kind`; `bin/push_test.dart` sends that
  account's devices an example of that notification, built by the real
  builders on one of its live listings and marked as a test) and
  `weekly-summary.yml` for itself ("Enviar o resumo da semana", there and
  on the summary page; the account goes as the workflow's input
  `account`, once per 2 minutes). The app's start calls share
  `start_workflow.dart`. Full pages outside the shell show
  `PageBackButton` (`core/widgets/`, `goBack`): pops, or, opened from a
  notification with nothing beneath, goes to Mais (Ofertas for Favoritos).
  Catalog
  changes go through RPCs that call `require_account()` (signed in, not
  anonymous). Models per account: lists read `listings.in_my_models` and
  `motorcycles.tracked_by_me` / `my_min_year` (computed fields: the
  caller's own list, or every collected model for an anonymous session; a
  new account follows nothing). Saved searches match only their owner's
  models (`owner_tracks`). Notifications reach each account's own devices
  (Web Push, see Alerts).
- Android app: the same code built as an APK by the deploy (`--dart-define`s
  in `core/platform/app_build.dart`: `APK_URL`, `APP_BUILD`, `WEB_URL`).
  Browser-only code sits behind conditional imports (`*_stub.dart` /
  `*_web.dart`); links to share use `webOrigin`, never `Uri.base`
  (a file in the app). Mais › "App Android" (`android_app_text.dart`,
  `android_app_tile.dart`) on Android only: in the browser it opens the
  APK; in the app it reads the release's `android.json`
  (`android_release.dart`), says whether a newer build is out, and a tap
  downloads it and opens Android's installer (no browser): the in-repo
  plugin `app/packages/apk_installer` (Java, channel
  `deal_tracker/apk_installer`, called by `core/platform/apk_installer.dart`;
  its manifest brings `REQUEST_INSTALL_PACKAGES` and the file provider).
  Android always asks to confirm the install. Notifications come through
  Firebase Cloud Messaging: the in-repo plugin `app/packages/android_push`
  (Java, channel `deal_tracker/android_push`, called by
  `core/platform/push_stub.dart`, the non-web side of `DevicePush`; its
  `DealTrackerMessagingService` shows each data message on the channel
  "Alertas" / "Alerts" (the message's language; stable channel ID `alerts`),
  also with the app closed, while switched on in Mais; a tap
  opens the message's url: `notification_link.dart`, then `appRouter.go`,
  or an ad's address outside the app). Firebase starts from resource
  strings `tool/firebase_values.py` writes at build time (secret
  `FIREBASE_ANDROID_CONFIG`; without it `PushState.nativeApp`, no
  notifications). The session is kept encrypted (`flutter_secure_storage`,
  Keystore key; `core/platform/session_storage.dart`, Supabase's
  `localStorage`; an earlier build's SharedPreferences copy is moved over
  once, `session_store.dart`), and the manifest says
  `android:allowBackup="false"` (`tool/android_manifest.py`).
- Photos: `Image.network` with `WebHtmlElementStrategy.prefer` (the photo
  CDNs don't send CORS headers, so an `<img>` element is the only way).
- Lists load `ListingModel.summaryColumns`, never `*` (descriptions are big);
  the deals list is paged (40 per page, more on scroll).
- Interface: shared wordmark (`core/widgets/app_brand.dart`) and editorial
  page heading (`page_intro.dart`); labelled filter, sort, save and comparison
  actions. Listing counts say "carregados" while more pages remain.
  `AppShell` uses bottom navigation below 840px, a compact rail above it,
  and an extended sidebar from 1180px (compact with enlarged text).
  Cards size naturally on phones and with enlarged text; otherwise up to
  three columns, with aligned location/comparison footers. The detail hero
  splits into photo and summary at 800px of content width; its four
  scrollable tabs keep opened sections alive, and the original-link action
  stays fixed below. `interface_test.dart` covers responsive layouts and
  interactions with the real bundled fonts; keep narrow and enlarged-text
  layouts free of overflow.
  Ofertas › "Cartões" and Mais › "Cartões dos anúncios" choose the card
  details for Ofertas and Favoritos (`listing_card_preferences`, one
  owner-only row per non-anonymous account). Defaults are the existing
  layout; Risk Score, seller type, colour, owners / first owner, service
  book, origin, warranties, stand name, status and publication, renewal
  and first-found dates are opt-in. A known owner count takes precedence
  over the existing `first_owner` risk signal; the signal is used only
  when the count is unknown. Dates stay distinct and absent facts are
  omitted. `ListingModel.summaryColumns` and the matching startup prefetch
  in `web/index.html` include these facts and only
  `score_breakdown->risk_reasons`, never descriptions or the full score breakdown.
  Photo, model, price, removal notices and actions stay visible. Cancel
  discards the draft; "Repor predefinições" still needs "Guardar".
  This is free for all accounts today; `docs/paid-plans.md` records it
  only as a possible future subscription benefit, not a paywall.
- Look: `app/theme/app_theme.dart` (hand-made colour schemes: cool greys,
  racing-orange primary, white cards with a hairline border, no shadows or
  tints) and `app_colors.dart` (`AppColors.of(context)`: positive/negative
  and Deal Score band colours, light and dark). Never hard-code colours in
  widgets. `theme_contrast_test.dart` checks the WCAG contrast of the
  colours (text 4.5:1, score badges 3:1): keep it green when changing them. Fonts are bundled (`assets/fonts`, Latin subset plus arrows,
  `tool/font_arrows.py`): Barlow for text, Barlow Semi Condensed
  (`AppTheme.displayFont`) for titles, prices and scores; prices use
  tabular figures. Barlow Regular is also the family "Roboto" (the web
  engine's default, else downloaded from Google). A character the fonts
  lack makes the web engine download a Google font: `make tool-check`
  (`tool/font_coverage.py`) fails on one; draw it in or reword. The
  web app downloads every font file before its first frame, so they are
  unhinted and only the weights in use (Barlow Semi Condensed: Bold
  only); `font_coverage.py` also fails on a hinted font or one the
  pubspec doesn't declare. The
  engine stays on Google's CDN: served from Pages, `skwasm.wasm` came
  1.5 MB instead of 1.2 MB (#172).
- Hosting: Cloudflare Pages (security headers in `web/_headers`: HSTS,
  nosniff, no framing, referrer and permissions policies; `index.html`
  preconnects to Google's CDN, the database (`tool/web_preconnect.sh`
  writes its address into the build) and the photos' CDN, and draws a
  spinner (`#splash`, the theme's primary, as `Startup`'s) until Flutter's
  first frame; without an account's session it also asks for the first
  page of listings and the model list and starts the first photos while
  the app downloads (`window.dealTrackerFirstPage`, taken by `Startup`
  through `core/platform/first_page.dart`; the script's queries must stay
  the repository's own, `test/first_page_test.dart`; the address and
  publishable key come from `<meta name="database">`, written by the same
  script), installed on the iPhone from Safari ("Adicionar
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
- Table privileges: anon and authenticated have only `select` on public's
  tables (also tables made later: default privileges); authenticated writes
  only saved_searches, listing_favourites, user_home, ownership_settings,
  inserts/updates its own listing_card_preferences and account_languages,
  deletes invites and push_subscriptions, and updates `alerts.read_at`
  (`20261024170000_tighten_api_grants.sql`, `api_grants_test.sql`). A new
  table the app writes needs its own `grant` (RLS still limits the rows);
  everything else goes through security definer functions.
- Every UPDATE and DELETE in a function has a WHERE (`where id` on the
  one-row tables, `where true` for all rows): Supabase's API loads
  pg-safeupdate, which refuses them otherwise, also inside functions the
  app or the collector calls (`make sql-lint`'s safeupdate check).
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
  `runCounts`; keep those log lines' wording). report_run.dart also sends a notification to the
  admins' devices (Web Push, `pushToUsers`; a tap opens "Estado da
  recolha") when a run's status differs from the previous run's (`run_health.dart`:
  the error lines of each site, or "voltou a funcionar"), never twice for
  the same problem. It also stores `problems` (`runProblems`, runs not
  ok), `sites` (each fetch state file's `report()`: requests today,
  paused until), `searches` (`searchesRead`: per search the pages it
  spans and the pages read, from `searches.json`'s `pages`, the ads found,
  how many are followed models, and whether it was read in full; from
  importBatch's "Search (<site>): ..." lines, keep their wording) and
  `run_url` (`githubRunUrl`), shown to admins in
  Mais › "Estado da recolha" (`collection_status_page.dart`, route
  `/collection-status`, pushed), with the database's size against the
  free plan's 500 MB and its 5 biggest tables (`database_usage`, admins;
  red from 80 %).
- Schedules live in Supabase, not in the workflows (GitHub's scheduler never
  started `collect.yml`): pg_cron jobs `collect-listings` (`0 * * * *`,
  `dispatch_collection()`: only at the Lisbon hours 0, 8, 12, 14, 16, 18
  and 20, `collection_due`, so summer time needs no change)
  and `weekly-summary` (`52 7 * * 1`) call `dispatch_workflow()`, which
  starts the workflow through GitHub's workflow_dispatch API with pg_net and
  the Vault secret `github_dispatch_token` (fine-grained, this repo only,
  Actions read/write; created by Rafael, see `docs/hosting.md`; admins can
  also start them from the app, `start_workflow`). Change a
  schedule with a migration calling `cron.schedule` with the same job name;
  the collection's hours: `docs/hosting.md`, "Changing the schedule"
  (database, app and tests together).
- GitHub token: pg_cron job `github-token-check` (`7 8 * * *`) runs
  `check_github_token()` (GET collect.yml with the Vault token through
  `http`; state in `github_token_check`, one row, no API access; the
  expiry from GitHub's `github-authentication-token-expiration` header);
  refused or ending within 14 days tells Telegram once a day. Admins see
  it in "Estado da recolha" (`github_token_status`, checks again).
- Watchdog: pg_cron job `collection-watchdog` (`20 * * * *`) runs
  `check_collection_runs()`: no run recorded for 9 h sends a Telegram
  message (`send_telegram()`, pg_net, Vault secrets `telegram_bot_token`
  and `telegram_chat_id`), repeated once a day; the next run sends the
  recovery. State in `collection_watchdog` (one row, no API access).
- Space: pg_cron job `prune-unfollowed-listings` (`37 3 * * *`) runs
  `prune_unfollowed_listings()`: only once the database reaches 400 MB
  (80 % of the free 500 MB), it deletes listings of models nobody follows
  that are gone (removed/sold) for 30+ days, from the sites, and not a
  favourite, alerted, or the earlier ad of a relist or duplicate; a
  deletion is told on Telegram. The file doesn't shrink (the space is
  reused), so it keeps pruning daily while above.
- Anonymous users: pg_cron job `prune-anonymous-users` (`43 3 * * *`)
  runs `prune_anonymous_users()`: deletes anonymous users made 30+ days
  ago with no session used in 30 days (`auth.sessions`; they own nothing,
  foreign keys cascade). Accounts are never touched; a pruned visitor
  just signs in anonymously again.
- The app's next-run time (`collection_text.dart`, `collectionHours` and
  the EU summer-time rule) mirrors `collection_due`: change both together.
- Watch out: `greatest`/`least` ignore nulls.

## Collection pipeline

`make refresh` runs `bin/refresh.dart`, one Dart process per run (Dart
starts once, the catalog is loaded once). For each site:
`planSearches` (tracked models) → `fetchSearches` saves the pages plus
`searches.json` (planned searches, search of each page) → `importBatch`:
save → markSeen → rematch → applyPriceChanges → setSearchKeys → applyPricesBeforeDrop
→ applyListingDates → saveSiteModels → (if `--full`) markRemoved; Standvirtual then reads the details of every
listing waiting for them (`enrichDetails`) with the same fetcher. Then once for all sites
(`finishRun`): markDuplicates → recalculateScores → generateAlerts →
notifications (Web Push). The single-step commands (`fetch.dart`,
`collector.dart`, `enrich.dart`, `searches.dart`) reuse the same library
functions for manual work.

- **Read failures**: `importBatch` keeps readable records and returns
  whether the input was clean. `refresh.dart` and `collector.dart` report
  a failed run for read issues (also dry runs and `--force`), without
  skipping final scores/alerts. `Read issue:` lines feed `runProblems`;
  ordinary rejections, unmatched models and mapper warnings are not read
  failures.
- **Searches** come from `motorcycles.olx_search` / `standvirtual_search` of
  the tracked models (`planSearches`). Models with the same address share one
  search, asking for the earliest `min_year` of those models (OLX
  `search[filter_float_year:from]`, Standvirtual
  `search[filter_float_first_registration_year:from]`). On OLX, whose model
  filter is a family ("R", "CB"), a search also asks for the engine-size
  band that holds all its models (`olxEngineBand`, the values of OLX's own
  filter list: up to 50, 51-125, 126-500, 501-1000, over 1000 cc), so other
  models' ads aren't read; word searches ("q-honda-forza-350") too. Every page of a
  search is read (OLX 40 listings each, Standvirtual 32, `?page=N`). Oldest models first, so when a site's run time
  (30 min) runs out the newest models' searches wait.
- **Removal is per search** (`removalPlan`): each listing stores the search
  that found it (`listings.search_key`); a run removes only listings of the
  searches it read in full. A search with a problem (unreadable page,
  missing or repeated pages, stale page, rejected record without an id) or not fetched
  keeps its listings. Listings with no search key, or one no planned
  search has any more (the address changed), are covered only when every
  planned search was read in full; the latter only for a tracked model and
  within its years (`in_removal_scope`). Without a manifest (hand-saved
  pages, manual JSON) the whole input must be clean. The database refuses
  to remove more than 50% at once unless forced.
- **Standvirtual** search pages hold everything except the description
  (including `createdAt` -> `published_at` and the bump date ->
  `site_refreshed_at`; `apply_listing_dates` keeps the earliest publication
  and latest renewal) and only one thumbnail. Listing pages are read only
  for matched, non-duplicate listings without details (`details_checked_at
  is null`), newest first, for the details and every photo (up to 30,
  `maxImages`); then for listings read before the photos were kept
  (`photos_read_at is null`); a page that failed (gone, unreadable, refused, another ad) is marked
  `details_failed_at` (`mark_details_failed`) and waits behind the
  listings never tried. HTTP 404/410 are gone-page skips; transport failures
  and other HTTP errors stop enrichment and fail the run after storing the
  details already read. The page's colour field is stored as
  `site_colour`. A search counts as read in full when every page
  it spans was saved, or its distinct page offsets hold the site's count
  (promoted ads never count); duplicate offsets make it incomplete. The search
  result's `priceDrop` is stored as `price_before_drop` (highest seen, never
  creates alerts).
- **OLX** search results (`__PRERENDERED_STATE__`, 40 per page, `page=N`)
  hold the full description; no listing pages. Ads with
  `partner.code = 'standvirtual'` are copies of Standvirtual ads and are
  skipped. Ads without a price are rejected but count as live. `createdTime`
  is stored as `published_at`, `lastRefreshTime` (the date OLX shows) as
  `site_refreshed_at`. A matched ad's title (after the brand, phone-shaped
  numbers removed) is stored as `variant`, as Standvirtual's version, for
  the A2 and extras rules.
- **Model matching** (`ModelResolver`, shared by all sources) reads its rules
  from the catalog: model name and `aliases` spelled within the first three
  words (also without closing letters: "CBR 650" = CBR650R), Honda code
  suffixes (A, AC), per-model `excluded_words` ("tracer" for the MT-07,
  "650f", "125f"), on OLX the title read after the brand (also after sale words: "Vendo mota Honda ..."), `engine_cc_min/max` as tiebreaker and guard (a model
  without limits is never picked by engine size alone; "350cc" reads as
  "350"). Ambiguous stays unmatched; Standvirtual's exact-name fallback
  cannot override an engine-size rejection. Every import re-checks the model of
  the ads it read (`rematch_listings`), so a better rule also fixes
  listings already stored. When the last account stops following a model
  its listings are unmatched at once; when one follows it again they are
  matched by their stored brand and model (a matched listing stores the
  catalog names), removed ones included.
- An empty mileage field is read from the description (trigger
  `listings_mileage_from_text`, `mileage_in_text`: "com 12.000 km",
  "Quilometragem: 12000"; tyres, services, work done ("troquei a corrente com"), purchase and km/h numbers don't count,
  two different values leave it empty) and marked `mileage_from_text`
  (the app's "(lido na descrição)"); the ad's own field always wins.
- Dealer boilerplate sentences are stripped from descriptions (they caused
  false duplicates). Duplicates are detected across sources too; a removed
  listing keeps its mark (only live listings are worked out again).
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
  robots.txt read once a day: kept in the site's fetch state up to 24 h
  (`FetchPolicy.robotsMaxAge`, RFC 9309's limit; Rafael, 2026-10-22),
  forgotten on a block, so the run after the pause reads it again.
- 6-10 s between requests (counted from the end of the previous request,
  so work done in between counts), **never parallel**, no retries; stop on
  403/429/503 or a non-normal page, then pause 24 h (state: requests
  today, the last block and robots.txt, in
  `collector/.fetch_state.json` and `.fetch_state.olx.json`, cached
  between Actions runs; written whole through a temporary file; a damaged
  one starts afresh, and a site still refusing pauses again at once).
  Blocking statuses are handled from the headers, before reading the body.
  A timeout cancels the active request/response before the next request.
- No request caps since 2026-10-22 (Rafael: remove them, show the amounts,
  adjust later): a run reads every page of the searches and every
  Standvirtual listing page still waiting, at most 30 minutes per site
  (`FetchPolicy.maxRunTime`, from robots.txt; Standvirtual's searches and
  listing pages share one fetcher). `FetchPolicy` still takes
  `maxRequestsPerRun` / `maxRequestsPerDay` (null = none) to bring caps
  back. Requests are counted per run (`collector_runs.requests`) and per
  site and day (the state file's `report()`), and shown in Mais (per run
  and month) and "Estado da recolha" (per day).
  Reaching the run time (or a cap) is not a failure: what was saved is
  imported. A request that fails (a timeout), a page our rules refuse or
  a block after some pages were saved also imports them, but the run still
  counts as failed; a search with a page missing is not read in full, so
  it removes nothing. The single-step commands take an optional cap
  (`fetch.dart --max`, `enrich.dart --max`, 10 by default).
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
  (inverted), seller 10 (`dealer_score`: dealers with 5+ bikes only, 100
  minus 100 x (relisted + sharp changes + repeated + half the ads without
  mileage) / bikes; private sellers and smaller dealers skip it; the
  app's `sellerLine`); then + 1 point per extra worth money
  (`valued_extras`: quickshifter, exhaust, luggage, heated grips, upgraded
  suspension, cruise control, steering damper, new tyres), at most + 3, so
  extras only break ties (never more than about a year newer), never above
  100 (all extras are still read, shown and filterable; `listing_extras`: keywords in variant/description for quickshifter,
  exhaust, luggage, heated grips, protection (also "cogumelos"), new tyres,
  short plate holder, tinted or sport screen, adjustable levers, bar-end
  mirrors, phone mount/USB, alarm/tracker, steering damper, centre stand,
  cruise control, upgraded suspension, LED indicators, passenger grab
  handles, original parts included (so it can go back to stock); codes
  never change, the app's `extraLabels` and the saved-search check list the
  same). Extras are a bonus, not a slice: as a slice they lowered good
  scores. Without the price slice the score is at most 70
  (`capped_without_price`); with an accident or a repair in the text
  (`possible_accident`, `needs_repair`) at most 50 (`damage_cap`,
  `capped_for_damage`: the estimate is of bikes without damage). Missing
  slices are skipped.
- Risk signals: price far below market, possible accident (text,
  `mentions_accident`: also falls and knocks, "caiu", "foi ao chão", "teve
  um toque"; "nunca teve acidentes", "livre de sinistros", "macia ao
  toque", "o preço caiu" and insurance wording don't count), repairs or
  missing/broken parts (`needs_repair` 20: "precisa do suporte", "falta o
  pisca", "para peças"; not "não precisa de nada", "precisa de carta",
  "partida elétrica"), scratches (`cosmetic_damage` 5), missing
  mileage/year/location, thin description (only private sellers with details
  read, or on OLX, whose results hold the whole description), 3+ owners, no service book, imported, implausible mileage (under
  100 km on a bike 3+ years old, or over 25 000 km a year), relisted (5;
  `relisted_often` 10: twice, or on sale for over 90 days counting the
  earlier ads), the text contradicting the ad's fields
  (`text_contradictions`: year 2+ apart (not a year still to come or after
  "até"), more km, imported, no service
  book; 10 each), an A2 (35 kW) version (`power_version` on variant and
  description: `a2_limited` 15, still held back; `a2_unlocked` 10; "pode
  ser limitada", "kit A2 incluído" count nothing); reassuring: first owner
  (the field, or `single_owner_in_text` when it is empty: "primeiro /
  único dono", "1ª mão", "first owner"; denials don't count), service
  book, factory warranty (negative points, floor 0).
- Market behaviour per model (`model_market_behaviour`): time until leaving
  the market, share and size of price drops (measured from the higher of the
  first price seen and `price_before_drop`), depreciation rates. Show "ainda
  poucos dados" below 5 data points.
- Price to offer (`offer_text.dart`, app only; none for asking prices under
  300 €, placeholders): ceiling = asking price or
  the estimated value when asking is > 2 % above it; opening 6 % (private) /
  3 % (dealer) below it, more for long on sale (+3/5/7 % past 1x/2x/3x the
  model's typical time), relisted (+2 %), a model whose sellers often
  drop, high risk; less after a drop and less by however far the asking
  price is already below the estimate; 1-10 %, and never under 90 % of the
  estimated value; a bike whose text tells of an accident or a repair
  (`damageReasons`) gets +5 %, up to 15 %, its price below the estimate
  takes nothing off and the estimate sets no floor (it is of bikes
  without damage); scratches +2 %; rounded down to 50 €. The plan: the opening, one offer
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
  bikes on the same site, price dropped. Scored as the Deal Score's seller
  slice (`dealer_score`, see Scoring model).
- Cost of ownership (`ownership_cost.dart`, app only): per year =
  average depreciation over the years kept (model's curve at the owner's
  km/year) + IUC (category E table by the model's engine size, nothing
  under 10 €; **check `iucBands` every January**) + the owner's insurance
  (left out until entered) + tyres, services and chain kit by engine size.
  The owner's figures live in `ownership_settings` (one row per account).
- Favourite colours: `listings.colour` (a code: `colour_code()` of
  Standvirtual's `site_colour`, else `colour_in_text()`: a colour word in
  the variant before "com", or after "cor" in the description; trigger
  `listings_colour`), `user_models.colours` (per account and model, set in
  "Modelos acompanhados" through `set_model_colours`, read as
  `motorcycles.my_colours`; the codes = the app's `colourLabels`) and the
  computed field `listings.my_colour` (`likes_colour`: the listing's colour
  is one of the caller's for its model; select it explicitly). A plus shown
  on the card, the facts and the explanation, the Ofertas filter "Só nas
  suas cores" (`ListingFilters.onlyMyColours`), saved searches'
  `only_my_colours`, and alerts' "na sua cor" (`pending_notifications.
  my_colour`); never part of any score.
- New-bike comparison: `motorcycles.new_price_reference` (+ checked date),
  shown on the detail page; hidden when the model has no reference price.

## Alerts

Pesquisas and Alertas use native `SwipeActions` (`core/widgets/`): right
edits, left confirms deletion, with options menus kept as an accessible
alternative. An alert edits its source saved search (`ListingAlert.searchId`)
through the shared `editSavedSearch` action; favourites and deleted source
searches have no edit action. The editor opens on the root navigator, above
the shell and its snack bars.

Deleting an alert hides it, never removes its event history:
`dismiss_alert` requires a real account and its own alert, sets
`dismissed_at`, `read_at` and `notified_at` only where absent, and leaves
deduplication intact. The app loads only `dismissed_at is null`; direct
alert deletion and writes beyond `read_at` remain forbidden. The collector's
pending query already excludes handled notifications. Alert refreshes and
failed read writes must not bring dismissed rows back.

Types: `target_price_reached` (a favourite's `target_price`, set from
"Quanto oferecer": the listing is live at that price or less, at a price
seen after `target_set_at` (stamped by a trigger); old_price = the target,
one alert per target), `new_listing`, `price_reduction` (>= 1% drop, one per price-history
row), `excellent_opportunity` (score >= 80, risk < 50, one per user/listing,
`excellent_since`), `listing_removed` (only for listings the user was already
alerted about; one per removal: a listing that comes back and goes again
alerts again), `back_on_market` (a relist of an ad the person followed:
favourite or alerted by an active saved search; once per person and new
ad; relists first seen in the last 14 days). Only events after the saved search was created
and in the last day (a listing first seen, a drop or a removal older than
that, e.g. of a model just followed, never alerts). Saved
searches can also require a minimum Deal Score / maximum Risk Score,
several models (`motorcycle_ids`, empty: any; as Ofertas'
`ListingFilters.motorcycleIds`), a maximum distance from the owner's home, equipment (`extras`, all
required; `listing_extras` codes) and only the owner's colours of each
model (`only_my_colours`); all in `saved_search_matches`.
`notified_at` marks alerts already sent (only real accounts; up to 200
a run, oldest first; kept for the next run when the push keys can't be
read, and while no device took a push that failed, for 24 h; older ones
are marked without a push): to the account's devices by Web Push, or FCM
for the Android app (`push_subscriptions`, saved from Mais ›
"Notificações neste aparelho", saved again on each visit, removed on
sign-out; on the iPhone only in the home-screen app;
no longer to Telegram since 2026-10-21, `pending_notifications.to_telegram`
is unused). The collector sends them itself
(`notify/web_push.dart`: RFC 8291 encryption and RFC 8292 VAPID with
pointycastle, no third party; every push is Declarative Web Push,
`declarativePush`: `{web_push: 8030, notification: {title, body, navigate,
tag}}`, which iOS 18.4+ shows and opens itself, also moving an app that is
already open; other browsers pass it to `push_sw.js`); its key pair is made on the first run
(`store_push_keys`: public key in `push_config`, private in Vault
`vapid_private_key`). The app's `web/push.js` (subscribe, state) and
`web/push_sw.js` (shows the notification elsewhere; a tap opens `/#/deals/<id>`: an
open app is focused and sent the address, also left in Cache Storage for
`push.js` to read when the app is shown, which puts it in the hash,
since the worker can't navigate a page it doesn't control;
registered in its own scope `/push/`: Flutter's worker at `/` unregisters
itself on each start and would take the subscription with it) are plain JS called from `core/platform/push.dart`; gone devices (404/410)
are deleted. The Android app's device is a row with endpoint
`fcm:<registration token>` and empty keys (`save_push_subscription`);
`WebPushSender` hands those to `notify/fcm.dart` (FCM HTTP v1: a JWT
signed RS256 with the service account's key from env
`FIREBASE_SERVICE_ACCOUNT`, exchanged for one access token per run; the
same {title, body, url, tag} as a data message; UNREGISTERED is gone;
without the secret they fail and the alert waits as for any failed push).
Weekly summary (Mondays, `weekly_summary.dart`, pure logic in
`notify/weekly_summary.dart` and `send_weekly_summaries.dart`): per account
(`user_models`, its own models from its first year, as `in_my_models`),
kept in `weekly_summaries` (one row per account, the latest; owner-only
RLS; `weeklySummaryJson`) for the app's "Resumo da semana" (`/summary`,
pushed; `weekly_summary_text.dart`) and pushed to the account's devices
(`weeklySummaryPush`, a tap opens it); non-duplicates; new = first
seen in the last 7 days, gone = removed with `last_checked_at` in them,
drop = last price this week >= 1% below the price the week started with
(live listings), best deals = live, risk < 50, by Deal Score.
Favourites (`listing_favourites`: user, listing, private note; owner-only
RLS) alert their owner without a saved search (`saved_search_id` null):
`generate_favourite_alerts()` gives every `price_reduction` (>= 1%) and the
`listing_removed` after the listing became a favourite; a unique index
keeps one alert per price change, and a removal already alerted to the
person since the listing was last seen isn't alerted again, when a saved
search also covers it. A favourite also holds the viewing checklist's marks
(`checklist jsonb`, `{"tyres": {"mark": "ok"|"issue", "note": ...}}`); the
items live in the app (`viewing_checklist.dart`), keys never change.
Reimporting everything after a reset: create saved searches AFTER the import,
or every listing counts as new.
