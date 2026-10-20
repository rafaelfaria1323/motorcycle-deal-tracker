# Test-hardening backlog

Worked through by `.github/workflows/test-hardening.yml` (Claude, with the
surviving mutants of `mutation.yml`, a mutation-testing tool like Stryker).
Each run does one of two things (by hand with "Run workflow" at any time):

- **"To do" is empty → find run** (after 10 merged PRs): it only looks, and changes no code. It
  hunts for bugs with hostile inputs (proven by a failing throwaway test),
  takes the surviving mutants of the latest `mutation.yml` run (the
  `mutation_test` tool, no AI: changes to the code no test noticed),
  drops the equivalent ones, tries its own changes on files that run
  doesn't cover, and spots redundant tests. It
  writes up to 10 items, most valuable first.
- **"To do" has items → fix run** (every 5 merged PRs): it does up to 3 of them (all if fewer
  are left): a bug gets its failing test first, then the fix; a surviving
  mutant gets the test that catches it; a redundant test is dropped once
  the other one is checked to cover the same. It does not look for new
  items.

Fixes may only make the code do what CLAUDE.md, the comments or the
function's name say; anything changing the fetching, scoring or alert
rules, the database schema, secrets or workflows goes to "Needs Rafael".
SQL is left out (CI has no database). Rafael can add, remove or reorder
items by hand at any time.

## To do

- Bug (low): `euros` puts the space after the minus sign for negative values with 3 digits — `collector/lib/src/notify/pending_alert.dart:49-55`: `euros(-123)` -> `'- 123 €'` (expected `'-123 €'`); `euros(-1234)` happens to work. Format the absolute value and prepend the sign.
- Bug (low): `agoText` shows negative minutes when the time is slightly in the future (clock skew between phone and server) — `collection_text.dart:51-52`: `agoText(now + 3 min, now: now)` -> `'há -3 min'`. Clamp to 0 (`'há 0 min'`).

## Needs Rafael

## Done

- 2026-10-20: `agoText` (exactly 48 h), `renewalToShow` (exactly 24 h) and `relistText` (1 € shown, 0.99 € not) boundary cases added to `collection_text_test.dart` and `listing_dates_text_test.dart`. Flutter is not in the sandbox, so they were checked by reading against each mutation, not run.
- 2026-10-20: `normalizers.dart` mutants: four cases in `normalizers_test.dart` (a `//` path loses both slashes — the item's `/a/` could not tell the `> 2` mutant apart, so `//` is tested too; `ref` is tracking; `&quot;`; `<li></li>` gives null). Each mutation fails them. Removed the dead `&#39;` replacement (`_charCode` already handles it; `it&#39;s` stays tested).
- 2026-10-20: `buildWeeklySummary` mutants: three cases in `weekly_summary_test.dart` (exactly 1 % drop counts, drop starts from the latest price before the week, risk 50 left out / 49 kept). Each mutation fails its test.
- 2026-10-20: `ModelResolver` mutants: five boundary tests in `model_resolver_test.dart` (engine exactly at/outside the limits, model in the 4th word, model over four words, two family models fitting the engine, two models named). Each of the six mutations fails them.
- 2026-10-20: `cleanDescription` keeps numeric entities that are not a valid code point (above 0x10FFFF or too big for an int) as text instead of throwing; both inputs tested in `normalizers_test.dart`.
- 2026-10-20: `asInt` returns null for Infinity/NaN instead of throwing; tested in `json_values_test.dart`.
- 2026-10-20: `removalPlan` mutants: added two `source_batch_test.dart` cases (a fully read search with zero records is skipped; a problem in a search outside `planned` keeps `includeUnkeyed` false). Both fail with the mutation applied.
