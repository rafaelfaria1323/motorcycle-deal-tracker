# Code-quality backlog

Worked through by `.github/workflows/code-quality.yml` (or "Run workflow").
Each run does one of two things: while "To do" has items, every 5 merged
PRs, it does up to 3 of them (all if fewer are left) and does not look for
new ones; when "To do" is empty, after 10 merged PRs, it only reviews the
code and adds up to 10 new items (most valuable first), changing no code.
It looks at how the code is written (duplication, dead code, structure,
theme, efficiency, names); bugs and tests belong to
[`test-hardening.md`](test-hardening.md). Rafael can
add, remove or reorder items by hand at any time.

Items change how the code is written, never what the app or the collector
does. Anything touching the fetching rules, the scoring or alert rules,
the database schema, secrets or workflows goes to "Needs Rafael".

## To do

- Four detail-page widgets each fetch the same model figures: `offer_card.dart:21-31`, `seller_message_card.dart:29-47`, `ownership_cost_card.dart:30-45` and `market_behaviour_section.dart:30-45` all call `MarketBehaviourRepository.getForModel` (two queries each) for one listing, so opening a listing runs the same queries four times; load it once (a small per-page loader/cubit created by the listing page, with the "ignore errors" fallback in one place) and pass the result down.
- Data loading and error fallbacks live inside widgets instead of cubits: `FutureBuilder`s calling `getIt<...Repository>()` in `price_history_section.dart:24`, `also_listed_section.dart:20`, `dealer_card.dart:31`, `data_quality_details.dart:20`, `collection_details.dart:38`, `home_place_tile.dart:25-44` and `compare_page.dart:30`; move them into small cubits like `ListingDetailCubit` (the layering CLAUDE.md describes) so the load/fallback logic can be tested.
- `app/lib/app/di/injection.dart:71-96` reads `Supabase.instance.client` seven times although `SupabaseClient` is already registered at line 39 and used by the first block; use `getIt<SupabaseClient>()` everywhere and merge the two registration blocks.
- Text styles set by hand in widgets: `deal_score_badge.dart:44-47` (weight, size 28/18), `listing_card.dart:187-189`, `price_change_tag.dart:32`, `compare_page.dart:151`, `alerts_page.dart:168`, `listing_detail_page.dart:152` (bold/w600/w700 chosen per widget); add the few needed styles to `AppTheme` (next to `displayFont`) so weights and sizes are defined once.
- `DateTime.now()` read inside widgets' `build` (`data_quality_details.dart:27`, `collection_details.dart:36,50`, `collector_status_banner.dart:43`) ties the text to the clock where it is built; read it once in the cubit/loader and pass it to the `*_text.dart` functions (which already take `now`).

## Needs Rafael

## Done

- 2026-10-20: The OLX and Standvirtual search adapters' `read()` loops became one `readSavedSearchPages` in `saved_pages.dart` (files, manifest, records, models, problems, stale and unreadable files); each site passes only its per-page bookkeeping and its end-of-run check (OLX's missing pages, Standvirtual's pages not saved). Messages unchanged; the existing adapter tests cover it.
- 2026-10-20: The two error-coloured texts (account sheet, saved search criteria) use `AppTheme.errorText(context)`; the other two spots are an icon colour and a button background, not text, so they stay.
- 2026-10-20: The Mais page and the collector status banner no longer use `Supabase.instance.client.auth`; a new lazy-singleton `SessionCubit` (`core/auth/session_cubit.dart`, tested) holds the signed-in state and email, and the widgets read it (the banner reloads when it changes).
- 2026-10-20: The three file-reading adapters share `listHtmlFiles` (exists check, `.html` filter, sort) and `staleIssue` ("saved N h ago") from `adapters/saved_pages.dart`, tested; messages unchanged. (The per-file decode stayed in the adapters: one line each, with different parsers.)
- 2026-10-20: `save` and `rematch` look up a listing's motorcycle id through `motorcycleIdFor` (`listing_store.dart`, tested); `save` keeps its own error for a catalog entry without an id.
- 2026-10-20: The OLX and Standvirtual search adapters and the Standvirtual listing-page adapter read their embedded JSON through one `extractJsonBlob` (`adapters/json_blob.dart`, with the shared `nextDataBlock` pattern), tested for a missing block, a damaged one and OLX's JSON-in-a-string; error messages are unchanged.
- 2026-10-20: Plain-text snack bars of the saved searches, listing, dashboard and tracked models pages use one `showMessage(messenger, text)` (`core/widgets/show_message.dart`); the one with an action keeps its own `SnackBar`.
- 2026-10-20: `ListingStore` reads the RPC row count through one `_count` helper (12 copies of `(result as num).toInt()`) and builds the catalog id map in one `_idBySlug` (copied in `save` and `rematch`).

- 2026-10-20: Collector tests share `test/helpers.dart` (the MT-07 and R7 catalog entries, copied 3 times, and a minimal `testListing`, copied in 2 more files); the fetcher's pause test has wide margins (it allowed only 150 ms of slack, so a busy CI machine could fail it).
- 2026-10-20: The row-to-`Catalog` mapping of `loadCatalog` became `catalogFromRows` (`catalog_loader.dart`), with tests (order, null list columns, empty).
- 2026-10-20: The `iosBottomInset` decision (Safari strip, home bar by screen size) became the pure `bottomInsetFor` (`ios_bottom_inset.dart`), tested; the web file only reads the browser values.

- 2026-10-20: The command-line scripts share `withServiceClient` / `describeFailure` (`collector/lib/src/cli/command.dart`, tested) instead of each building its client and catching the same errors; exit codes no longer drift (`searches.dart` used 69 for a database error, the others 70). `fetch.dart` (no database) and `refresh.dart`'s per-site handling keep their own messages.
- 2026-10-20: The OLX and Standvirtual mappers no longer copy every `NormalizedListing` field by hand (`fromSite` keeps all fields and sets the site's own, tested), so a new field can't be dropped by one mapper; `cleanDescription` compiles its patterns once instead of per ad and per line; `bin/collector.dart` creates its store once.
- 2026-10-20: UI text review: percentages written one way (`Formatters.percent`, "5,3 %"; some showed "5.3%"), "anúncio" for a listing everywhere ("Nova oferta" → "Novo anúncio", as in Telegram), "duplicado" instead of "repetido", the comparison's row names as on the listing page, imperative validation messages ("Indique…"), and a few awkward sentences.
- 2026-10-19: Text built inside widgets moved to tested functions: the alert title, details and origin lines (`alertTitle`, `alertDetailsLine`, `alertOriginLine` in `alerts_text.dart`) and the price history's "Visto pela primeira vez" line (`seenLine` in `price_history_text.dart`).
- 2026-10-19: Removed the unused `Formatters.formatDate`; `Formatters` got tests (dashes, price, mileage, date, `daysAgo`).
- 2026-10-19: `SearchManifest` got tests (round trip, missing file, invalid JSON, wrong shape).
- 2026-10-19: The listing page's "A mota" and "O anúncio" rows became `bikeFacts` / `adFacts` in `listing_detail_text.dart` (tested), drawn by a shared `FactsCard` widget; the page lost ~110 lines.
- 2026-10-19: `enrichDetails` (skips a gone or unreadable page; running out of requests or a block still stores what was read, a block is rethrown) and `notifyPending` (a failed send stops and marks only what went out) got tests with fakes.
- 2026-10-19: `importBatch` got tests with a fake store (step order, no removal without `--full`, a damaged input removes nothing unless forced, rejected bikes count as seen); `json_values.dart` got tests.
- 2026-10-19: Photo and score-badge overlay colours (`Colors.black54/black45/white`, `Color(0x33000000)`) became static constants of `AppColors` (same values, same look).
- 2026-10-19: `CollectorStatusCubit` got tests (latest run, no run, swallowed failure).
- 2026-10-19: Edge-case tests for `uniqueBySourceId` (same id on two sites, empty input) and `logTail` (empty log, fewer lines than the limit, character cut).
- 2026-10-19: `ListingDetailCubit` got tests (known listing, malformed id is not found without a query, unknown id, failure).
- 2026-10-19: The test reading the uncommitted saved Standvirtual search page (`standvirtual_search_test.dart`) is skipped when the file is missing, so `make check` passes on a clean checkout.
- 2026-10-19: `_map`, `_int` and `_time` were copied in the OLX and Standvirtual search/page adapters; now `asMap`, `asInt`, `asTime` in `collector/lib/src/adapters/json_values.dart`.

- 2026-10-19: `ListingAlertModel.read_at` (the only nullable date left) uses `ListingModel.dateOf`; the other `DateTime.parse` calls read non-null columns and stay.
- 2026-10-19: Error-message mapping of `TrackedModelsPage` and `AccountCubit` became `catalogSaveErrorText` and `authErrorText`, with tests.
- 2026-10-19: Filter-field parsing of `FiltersSheet` became pure functions in `filter_fields_text.dart`, with tests.
- 2026-10-19: Tests for `ListingAlertModel` / `SavedSearchModel` enum fallbacks; `SavedSearchModel` reuses `ListingModel.sellerTypeOf`.
- 2026-10-19: Tests for `ListingModel.fromJson`; its seen-at dates now use the same `_date` helper as the other dates.
- 2026-10-19: `_capitalize` of the status banner became `capitalize` in `collection_text.dart`, with a test.
- 2026-10-19: Removed a needless `?.` in `more_page.dart` (the analyzer warning made `make check` fail).
