# Code-quality backlog

Worked through by `.github/workflows/code-quality.yml` (or "Run workflow").
Each run does one of two things: while "To do" has items, every 5 merged
PRs, it does up to 3 of them (all if fewer are left) and does not look for
new ones; when "To do" is empty, after 10 merged PRs, it only reviews the
code and adds up to 10 new items (most valuable first), changing no code.
It looks at how the code is written (duplication, dead code, structure,
theme, efficiency, names); unused code and files in the app are already
failed by `make dead-code`, copy-paste by `make duplication`; bugs and tests belong to
[`test-hardening.md`](test-hardening.md). Rafael can
add, remove or reorder items by hand at any time.

Items change how the code is written, never what the app or the collector
does. Anything touching the fetching rules, the scoring or alert rules,
the database schema, secrets or workflows goes to "Needs Rafael".

## To do


## Needs Rafael

## Done

- 2026-10-27: Counts and their nouns are ICU plurals (`{count, plural, =0{0 anúncios} =1{1 anúncio} other{{count} anúncios}}`): the 16 strings with a `{…Word}` placeholder, the pairs of one/many messages (`text1Listing` / `listingsDataQualityText`, `text1DayLeft` / `daysLeft`, `thereIsAnother…` / `thereAreCheaper…`, "Problema" / "Problemas") and the counts built in code (a run's counts, the weekly summary's, data quality's) now take an `int` and pick the word in the resource; 46 keys of bare words or halves went. Each plural has an explicit `=0`: Intl's rule for `pt` counts 0 as "one". It also fixes the listing page's "1 meses" of seller warranty (tested).
- 2026-10-27: The ARB resources have names by purpose (148 keys: the 73 named after a 40+ character English sentence, e.g. `githubTokenIsMissingFromSupabaseVaultCollections` → `githubTokenMissing`, and the 77 with `{value}` placeholders, e.g. `at` → `runLine`, `now` → `priceNowChanged`) and placeholders by what they hold (`{ago}`, `{duration}`, `{asked}`, `{listingsWord}`; no `{value}` left). Both ARB files and every caller were renamed by one script that matches the call's own parentheses, then checked: every call's named arguments equal its string's placeholders.
- 2026-10-27: `prefer_const_constructors` and `prefer_const_literals_to_create_immutables` are on again (`app/analysis_options.yaml`): the 36 widgets and test values #202 left without `const` got it back.
- 2026-10-27: The listing and settings sections' `FutureBuilder`s stay in their widgets: each loads one read once and shows a placeholder, the data or nothing, which is Flutter's own tested state handling; a cubit per section would add about 40 lines each with no new behaviour (the compare page already retries). Where there was logic, it moved out: who is looked up as a dealer is `dealerLookupName` (`dealer_text.dart`, tested: private or unknown sellers and blank names are never looked up).
- 2026-10-27: Text styles are defined once in `AppTheme`: `tabularFigures` (the six price and score texts), `eyebrow` (the page intro's line and the listing's site; the site's 1.5 letter spacing became the intro's 1.6), `groupLabel` (the alerts' days, the account kinds), `figureLabel` (the price history's and the price strip's small figures) and `onPhotoLabel` (the card's photo pill, the badge's "Deal Score" at 10 px); `price_change_tag` no longer repeats `labelMedium`'s w600. Bold that marks a state stays in its widget (the comparison's best value, an unread alert's title), as do the wordmark's and the score digits' own sizes.
- 2026-10-27: `DateTime.now()` in the collection and data-quality widgets' `build` stays: their texts are relative ("há 3 h"), so reading the clock on each rebuild keeps them current where a time read once in a loader would go stale, and the `*_text.dart` functions they call already take `now` and are tested with fixed times.
- 2026-10-27: The listing page's model figures are read once: `SupabaseMarketBehaviourRepository.getForModel` keeps each model's answer (or the read in progress) for 10 minutes (`reuseFor`) and forgets a failed one, so the offer, seller message, ownership cost and market sections share one pair of queries (were four), with no per-page cubit to wire; tested in `supabase_market_behaviour_repository_test.dart`.
- 2026-10-27: The offer and seller-message cards copied a message through two identical `_copy` methods; now one `copyMessage(context, text)` in `core/widgets/show_message.dart`.
- 2026-10-27: `pushToUsers` reads the accounts' languages and the push devices once for a whole batch; the weekly summary (which read the devices again for every account) uses it with a message per account, as the test push and the run-health notice do.
- 2026-10-27: `enrich_steps.dart` keeps its stop reason as an `Exception` (was `Object`, an `only_throw_errors` finding of the analyzer).
- 2026-10-27: Shared listing, saved-search, alert and favourite cubits inherit `AccountScopedCubit`: session identity owns cache resets and reloads, rather than duplicate callbacks in auth screens. Account generations guard delayed reads, writes and optimistic rollbacks; latest-load/count generations and disposal guards prevent stale results. Filters, sort and anonymous prefetch are preserved (roadmap N.20).
- 2026-10-20: `injection.dart` takes the client from `getIt<SupabaseClient>()` everywhere (seven direct `Supabase.instance.client` reads) and is one registration chain.
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
