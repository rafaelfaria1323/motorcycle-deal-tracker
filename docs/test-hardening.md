# Test-hardening backlog

Worked through by `.github/workflows/test-hardening.yml` (Claude, like a
mutation-testing tool such as Stryker) after every 5 merged PRs or by
"Run workflow". Each run does one of two things:

- **"To do" is empty → find run:** it only looks, and changes no code. It
  hunts for bugs with hostile inputs (proven by a failing throwaway test),
  makes small temporary changes to the code to find code whose tests don't
  notice a change ("surviving mutants"), and spots redundant tests. It
  writes up to 10 items, most valuable first.
- **"To do" has items → fix run:** it does up to 3 of them (all if fewer
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

- Bug: `cleanDescription` throws on a numeric entity outside Unicode or too big for an int — `collector/lib/src/normalized/normalizers.dart:101` (`String.fromCharCode(int.parse(m[1]!))`). Input `'a &#99999999; b'` -> RangeError, `'&#99999999999999999999;'` -> FormatException; one odd OLX/Standvirtual description would abort the import. Fix: leave the entity as text when it does not parse or is above 0x10FFFF; add both inputs to `normalizers_test.dart`.
- Bug: `asInt` throws on Infinity/NaN — `collector/lib/src/adapters/json_values.dart:7` (`o.toInt()`). `asInt(double.infinity)` -> UnsupportedError (Dart's `jsonDecode('1e999')` gives Infinity), so a bad counter/price field crashes instead of becoming null. Return null when `!o.isFinite`; test in `json_values_test.dart`.
- Surviving mutant: `removalPlan` still removes when the searches read in full returned no listing at all — `collector/lib/src/pipeline/source_batch.dart:141`, dropping `|| seen.isEmpty` passes all tests. Add a `source_batch_test.dart` case: a manifest with one fully read search, zero records, no issues -> `skipReason` 'no search was read in full'.
- Surviving mutant: `includeUnkeyed` ignores `incomplete` — `source_batch.dart:148`, changing `incomplete.isEmpty && manifest.planned.every(complete.contains)` to just the `every` part passes. Test: a manifest where the only incomplete search (an issue or an id-less rejected record) is not listed in `planned` must give `includeUnkeyed == false`.
- Surviving mutants in `ModelResolver` (`collector/lib/src/catalog/model_resolver.dart`), none noticed by `model_resolver_test.dart`: `_fits` bounds `cc >= min` -> `cc > min` (line 62) and `cc <= max` -> `cc < max` (test engine exactly at `engineCcMin`/`engineCcMax`, e.g. CB650R 640 and 660 match, 639 and 661 don't); `start <= 2` -> `start <= 3` (the model in the 4th word must not match); `end < start + 4` -> `+ 3` (a model spread over 4 words, e.g. "C B 650 R", must match); `byEngine.length == 1` -> `isNotEmpty` (two family models fitting the engine must stay unmatched); `named.length > 1` -> `> 5` (text naming two catalog models, "CB650R CBR650R", must be unmatched).
- Surviving mutants in `buildWeeklySummary` (`collector/lib/src/notify/weekly_summary.dart`): `end.price <= start.price * (1 - _minDrop)` -> `<` (a drop of exactly 1 % must count), `riskScore < _maxRisk` -> `<=` (risk exactly 50 must be left out, 49 kept), and `before.last` -> `before.first` (with two price points before the week, the drop starts from the latest one). Add the three cases to `weekly_summary_test.dart`.
- Surviving mutants in `collector/lib/src/normalized/normalizers.dart`: trailing-slash loop `path.length > 1` -> `> 2` (line ~12, `/a/` and `/ab/` must both lose the slash), dropping `'ref'` from the tracking parameters (line ~28; `?ref=x` must not change the id), dropping `&& l != '-'` (line ~114; `<li></li>` alone must give null), and removing `.replaceAll('&quot;', '"')` (line ~105). Add the four cases to `normalizers_test.dart`. Also `.replaceAll('&#39;', "'")` (line ~106) is dead code, since `_charCode` already turned `&#39;` into `'` — remove it.
- Surviving mutants in the app: `agoText` `diff.inHours < 48` -> `<= 48` (`app/lib/features/collector_status/presentation/collection_text.dart:52`, exactly 48 h must read "há 2 dias"), `renewalToShow` `< Duration(days: 1)` -> `<=` (`listing_dates_text.dart:16`, renewal exactly 24 h after publication is shown), `relistText` `change.abs() < 1` -> `<= 1` (`listing_dates_text.dart:34`, a 1 € change is shown, 0.99 € is not). Add boundary cases to the matching `*_text` tests.
- Bug (low): `euros` puts the space after the minus sign for negative values with 3 digits — `collector/lib/src/notify/pending_alert.dart:49-55`: `euros(-123)` -> `'- 123 €'` (expected `'-123 €'`); `euros(-1234)` happens to work. Format the absolute value and prepend the sign.
- Bug (low): `agoText` shows negative minutes when the time is slightly in the future (clock skew between phone and server) — `collection_text.dart:51-52`: `agoText(now + 3 min, now: now)` -> `'há -3 min'`. Clamp to 0 (`'há 0 min'`).

## Needs Rafael

## Done
