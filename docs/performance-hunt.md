# Performance and memory hunt (2026-11-16)

Rafael asked to look for memory leaks and performance issues. Everything
was measured, not guessed: the database on a local copy of every migration
seeded with 20 000 listings (15 000 live, 13 models, years and mileages
spread as on the sites), about 8 times today's live ads, so what is slow
there will be slow when the market grows; the collector and the app read
for resources that are opened and never closed.

Ranked by how often the cost is paid and how large it is. Steps PF.1-PF.5
are done in this PR; PF.6-PF.7 are noted, not worth their code today.
PF.8-PF.9 came with N.117-N.118, PF.10-PF.11 with N.134 (PF.12 noted).

## Findings

| # | Where | What | Measured (15 000 live) |
|---|-------|------|------------------------|
| PF.1 | `listing_fair_prices` (`supabase/migrations/20261115120000_value_coverage.sql:220`) | Each listing's comparables were found by joining the model's live ads to it three times (generation, near years, all) and counting each tier in a correlated subquery; every pair also paid `age_mileage_factor` (a SQL function with its own search_path, never inlined) and numeric `exp()`. Quadratic per model, with a function call per pair. | 55 s → 18 s |
| PF.2 | `recalculate_deal_scores` (`20261112090000_new_price_from_ads.sql:129`) and `listing_risk_scores` (`20261113150000_stock_photos.sql:288`) | The run read the fair prices twice (once directly, once inside the risk view, which joins them again), then rewrote **every** live listing's score, breakdown and `scored_at`, 9 runs a day, with their triggers, although the age-based slices change once a day at most. | 124 s → 38 s; a second run writes 0 rows |
| PF.3 | `mark_duplicates` (`20261114090000_duplicate_marks_changed_only.sql:12`), `duplicate_similarity` (`20261018104432_add_duplicate_detection.sql:13`) | Every same-model, same-year pair computed the trigram similarity of two long descriptions (the costly part), even when the other facts (mileage, price, place, seller) already made the threshold unreachable; and `duplicate_similarity` computed it twice. | 82 s → 13.5 s |
| PF.4 | `in_my_models` (`20261023140000_models_per_account.sql:133`), `distance_km` (`20261022150000_listing_distance.sql:91`), `my_colour` (`20261025010000_bike_colours.sql:166`) | Ofertas filters every page and count on `in_my_models`: a chain of three SQL functions (`caller_tracks` → `collected`/`user_tracks`), each with its own search_path, so none is inlined and every row pays three calls. The same for the distance (two) and the colour (two). | filter 1.8 s → 0.26 s; distance 2.4 s → 1.0 s |
| PF.5 | `collector/lib/src/notify/web_push.dart:274` | A new `HttpClient` (new connection, new TLS handshake) for every push; a burst of alerts to the same push service paid it each time. | one connection per push service per run |
| PF.6 | `description_signals` (`20261106120000_not_legalised.sql:136`) | About 60 regular expressions per description; Postgres caches 32 compiled ones per session, so each listing recompiles some (about 6 ms a listing). Paid only when a description changes (the stored `text_signals`), so a few seconds a run. | not changed |
| PF.8 | `collect.yml`, `photos.yml` (2026-11-17, N.117) | Each collection installed Dart and the dependencies twice (about 10 s each) and started three programs with `dart run`, which compiles from source every time (about 8-10 s each on the runner). | start 7.1 s → 14 ms locally; about 35-45 s a collection |
| PF.9 | the collection (2026-11-17, N.118) | Which step a real run spends its time on was only guessed from the log's timestamps (about 20 s of SQL in a 230 s run; the 6-10 s waits between requests take the rest). | each step's time kept per run (`collector_runs.steps_ms`), "Onde vai o tempo" in "Estado da recolha" |
| PF.10 | `dealer_reliability` (2026-11-28, N.134) | The view numbered and sorted the whole price history (a window over every row) for every query, also the dealer card's, which asks for one dealer. | every dealer 155 → 58 ms; one dealer about 3 ms |
| PF.11 | `saveSiteModels` (2026-11-28, N.134) | The sites' brand and model lists were upserted whole every run: Standvirtual's took 5.1 s in run 46133048230, the slowest SQL step. | one call, `store_site_models`, writes only new, renamed or day-old rows: 3 000 rows about 30 ms, 0 written on a repeat |
| PF.12 | `risk_from_signals` (2026-11-28) | About 0.5 ms a listing of executor overhead (not the regexes or plan caching), about 18 s of the 43 s scoring on 20 000 ads. The real run's scores take 2.0 s for 430 ads. | not changed |
| PF.7 | `place_key` (in `distance_km`, `district`) | Three regular expressions per row to find the ad's place; the rest of the distance sort's 1.0 s. A stored place key per listing would remove it; the sort is opt-in and 1 s on 8x today's ads. | not changed |

## What was done

- **PF.1** (`20261116090000_faster_scoring_runs.sql`): each model's live ads
  are packed once into arrays; each listing unnests its model's arrays,
  counts the generation and near-year tiers in one pass and takes the
  median of the chosen tier with the depreciation factor written inline in
  floating point. Same rules, same results: every listing's comparable
  count and fair price compared equal with the old view on the 15 000.
- **PF.2**: the risk rules move into `listing_risk(listing, fair_price)`,
  used by the view and by the run, which reads the fair prices once
  (materialised) and updates only the listings whose score, risk or
  breakdown differ (or are unscored). It still returns the number of
  listings scored. `scored_at` now says when the score last changed.
  Scores, risk and breakdowns compared equal with the old function's.
- **PF.3**: a pair is first scored on its facts without the descriptions;
  when even a perfect text match (30 points) can't reach the threshold,
  that score stands and the trigrams are never computed. Otherwise the
  full score, with the similarity computed once.
- **PF.4**: `in_my_models`, `distance_km` and `my_colour` each written out
  in one function (the others stay for their other callers).
- **PF.5**: `WebPushSender` keeps one `HttpClient` for the run (idle
  connections close after 5 s, so a command without `exit` still ends);
  `sendWebPush` without a client still opens and closes its own.

Tests: `scoring_changed_only_test.sql` (a second run rewrites nothing, a
change is written, the view and the run agree, a gone ad loses its score),
the existing scoring, duplicate, relist, model, colour and distance tests
unchanged; `web_push_test.dart` (a burst shares one connection).

## Memory

No leak found:

- **Collector**: each command is one short process. Saved pages are read
  one file at a time (`adapters/saved_pages.dart`); the fetcher closes
  every response, also on timeouts; the photo step keeps 3 photos of one
  listing at a time and the CLIP helper is one process per run, closed in
  `finally`. The FCM client (`notify/fcm.dart`) was already one per run.
- **PF.8** (N.117): `make collector-exe` compiles refresh, report_run and
  photos ahead of time; the shared action caches them until the collector's
  code changes and then skips installing Dart.
- **PF.9** (N.118): each run keeps how long each step took (`timeStep`,
  `RunReport.steps`), so the next slow step shows in "Estado da recolha"
  with real runs' figures instead of a guess.
- **App**: every cubit's stream subscriptions are cancelled in `close`
  (`AccountScopedCubit`, `ListingCardPreferencesCubit`, the shell's
  lifecycle observer); DI closes the singletons; controllers and focus
  nodes are disposed by their states; the lists page 40 at a time and
  photos are asked at the card's size (N.82). Pages pushed and popped
  leave nothing behind.
- **Database**: the scoring run's temporary data lives in one statement;
  the stored `text_signals` keep the costly text rules off the hot path.
