# Code-quality backlog

Worked through by `.github/workflows/code-quality.yml` after every 5 merged
PRs: it does up to 3 items from "To do"; when "To do" is empty it reviews
the code, adds up to 10 new items (most valuable first) and does the first
3. Rafael can add, remove or reorder items by hand at any time.

Items change how the code is written, never what the app or the collector
does. Anything touching the fetching rules, the scoring or alert rules,
the database schema, secrets or workflows goes to "Needs Rafael".

## To do

## Needs Rafael

## Done

- 2026-10-20: UI text review: percentages written one way (`Formatters.percent`, "5,3 %"; some showed "5.3%"), "anúncio" for a listing everywhere ("Nova oferta" → "Novo anúncio", as in Telegram), "duplicado" instead of "repetido", the comparison's row names as on the listing page, imperative validation messages ("Indique…"), and a few awkward sentences.
- 2026-10-19: Text built inside widgets moved to tested functions: the alert title, details and origin lines (`alertTitle`, `alertDetailsLine`, `alertOriginLine` in `alerts_text.dart`) and the price history's "Visto pela primeira vez" line (`seenLine` in `price_history_text.dart`).
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
