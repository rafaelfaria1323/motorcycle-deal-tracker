# Code-quality backlog

Worked through by `.github/workflows/code-quality.yml` after every 5 merged
PRs: it does up to 3 items from "To do"; when "To do" is empty it reviews
the code, adds up to 10 new items (most valuable first) and does the first
3. Rafael can add, remove or reorder items by hand at any time.

Items change how the code is written, never what the app or the collector
does. Anything touching the fetching rules, the scoring or alert rules,
the database schema, secrets or workflows goes to "Needs Rafael".

## To do

- Test `ListingAlertModel` / `SavedSearchModel` enum fallbacks (unknown type, null seller) and share the seller-type mapping with `ListingModel` (`app/lib/features/listings/data/models/`).
- Move the filter-field parsing in `FiltersSheet._build` (`filters_sheet.dart`) to a pure function in a `*_text.dart` file and test it (comma decimals, blanks).
- Move `TrackedModelsPage._errorText` and `AccountCubit._friendly` error mapping into testable pure functions.
- Use one date-parsing helper for `DateTime.parse(...)` of nullable columns in `ListingAlertModel`, `SavedSearchModel` and the repositories.

## Needs Rafael

## Done

- 2026-10-19: Tests for `ListingModel.fromJson`; its seen-at dates now use the same `_date` helper as the other dates.
- 2026-10-19: `_capitalize` of the status banner became `capitalize` in `collection_text.dart`, with a test.
- 2026-10-19: Removed a needless `?.` in `more_page.dart` (the analyzer warning made `make check` fail).
