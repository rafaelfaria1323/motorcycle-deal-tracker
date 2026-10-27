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

- Surviving mutants from the report, not yet checked by hand: `collector/lib/src/pipeline/source_batch.dart:182,199,220` (`liveId: raw.status == 'ACTIVE'` / `'active'` flipped; test that only active records get a live id) and `:141` (`complete.isEmpty || seen.isEmpty` → `&&`).
- Surviving mutants in `collector/lib/src/adapters/olx/olx_mapper.dart:86,101` (brand lookup `key == category || words.contains(key)` and the `at < 0 || at > 1` title check): add mapper tests where only the category matches and where only the title word matches.
- Surviving mutants in `collector/lib/src/catalog/catalog.dart:103` (`brand == b && model startsWith` → `||` or negations): test the lookup with the right brand and another model, and with the right model prefix under another brand.
- Surviving mutants in `collector/lib/src/adapters/site_model.dart:35,63` (make/model key separator; `filter_enum_make && value != null` → `||`): test two models with colliding ids across makes and a make filter with a null value.
- Surviving mutants in the app, not yet checked by hand (line numbers from before #202; now `newPriceLines`' `fresh <= 0`, `parseNewPrice`'s `value <= 0` and `qualityMissingLine`'s `> 0` checks): `new_price_text.dart`, `tracked_models_text.dart` (both under `features/listings/presentation/`) and `features/collector_status/presentation/data_quality_text.dart` (`<= 0` → `== 0`): add negative-input cases (fresh price -1, engine size -5, whole -3) expecting the same result as 0.


## Needs Rafael

## Done

- 2026-10-27: An app language code the build doesn't know in the device cache (written by a newer build, or damaged) made every start fail, and "Tentar novamente" could not clear it (`AppLanguage.fromCode` threw in `Startup` and `LanguageCubit`); the cache now reads it as no choice (`AppLanguage.tryFromCode`, `SupabaseLanguageRepository.cachedIn`), while the account's stored language still reports an unknown code. Tested in `supabase_language_repository_test.dart` and `language_test.dart`; the cache test failed before the fix.
- 2026-10-27: Mutants killed, each checked by applying it: `manual_mapper.dart` `price <= 0` → `== 0` (a -5 € price is rejected); `weekly_summary.dart` `isGone` (a sold listing is gone, a live one checked this week is not); `fetch_searches.dart`'s two "N of M search(es) not read in full" counts (`- started + 1` → `- 1` or `+ started`: the budget test now runs out in the second of two searches, the block test reads its log).
- 2026-10-20: `agoText` clamps a time in the future to `'há 0 min'` (was `'há -3 min'`); tested in `collection_text_test.dart`, failed before the fix.
- 2026-10-20: `euros` formats the absolute value and prepends the sign (`euros(-123)` was `'- 123 €'`); `-123` and `-1234` tested in `notify_test.dart`, the first failed before the fix.
- 2026-10-20: `agoText` (exactly 48 h), `renewalToShow` (exactly 24 h) and `relistText` (1 € shown, 0.99 € not) boundary cases added to `collection_text_test.dart` and `listing_dates_text_test.dart`. Each mutation fails them (checked by reading); they pass on the real code.
- 2026-10-20: `normalizers.dart` mutants: four cases in `normalizers_test.dart` (a `//` path loses both slashes — the item's `/a/` could not tell the `> 2` mutant apart, so `//` is tested too; `ref` is tracking; `&quot;`; `<li></li>` gives null). Each mutation fails them. Removed the dead `&#39;` replacement (`_charCode` already handles it; `it&#39;s` stays tested).
- 2026-10-20: `buildWeeklySummary` mutants: three cases in `weekly_summary_test.dart` (exactly 1 % drop counts, drop starts from the latest price before the week, risk 50 left out / 49 kept). Each mutation fails its test.
- 2026-10-20: `ModelResolver` mutants: five boundary tests in `model_resolver_test.dart` (engine exactly at/outside the limits, model in the 4th word, model over four words, two family models fitting the engine, two models named). Each of the six mutations fails them.
- 2026-10-20: `cleanDescription` keeps numeric entities that are not a valid code point (above 0x10FFFF or too big for an int) as text instead of throwing; both inputs tested in `normalizers_test.dart`.
- 2026-10-20: `asInt` returns null for Infinity/NaN instead of throwing; tested in `json_values_test.dart`.
- 2026-10-20: `removalPlan` mutants: added two `source_batch_test.dart` cases (a fully read search with zero records is skipped; a problem in a search outside `planned` keeps `includeUnkeyed` false). Both fail with the mutation applied.
