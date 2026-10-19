# Code-quality backlog

Worked through by `.github/workflows/code-quality.yml` after every 5 merged
PRs: it does up to 3 items from "To do"; when "To do" is empty it reviews
the code, adds up to 10 new items (most valuable first) and does the first
3. Rafael can add, remove or reorder items by hand at any time.

Items change how the code is written, never what the app or the collector
does. Anything touching the fetching rules, the scoring or alert rules,
the database schema, secrets or workflows goes to "Needs Rafael".

## To do

- Photo overlays bypass the theme: `Colors.black54/black45/white` in `app/lib/features/listings/presentation/widgets/photo_gallery.dart`, `Colors.black.withValues` + `Colors.white` in `listing_card.dart`, `Colors.white` + `Color(0x33000000)` in `deal_score_badge.dart`; move them into `AppColors`.
- `CollectorStatusCubit` (`app/lib/features/collector_status/presentation/collector_status_cubit.dart`) has no test for its swallow-errors behaviour.

## Needs Rafael

## Done

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
