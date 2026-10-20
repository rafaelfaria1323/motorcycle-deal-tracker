# Motorcycle Deal Tracker — Small Interaction Roadmap (status 2026-10-22)

**Legend:** ✅ done · 🟡 partly done / in progress · ⬜ not started · ➕ added along the way (not in the original plan)

Notes in *italics* say how a step was actually done when it differed from the plan.
Keep this file up to date in the same PR as the work.

## Development Rule

One interaction = one small, functional, verifiable change.

```text
Implement → Test → Fix → Commit → Next interaction
```

Do not implement several unrelated features at once.

# Sprint 0 — Setup ✅

## 0.1 Create Git repository ✅
## 0.2 Create project structure ✅
*`app/`, `collector/`, `supabase/`, `docs/`, `Makefile`, `README.md`, `.gitignore`.*
## 0.3 Create Flutter Web project ✅
## 0.4 Create Supabase project ✅
## 0.5 Connect Flutter to Supabase ✅
*Credentials via `--dart-define-from-file=env/dev.json` (gitignored).*

# Sprint 1 — Database ✅

## 1.1 Motorcycles table ✅
*➕ Since 9.8/9.9 it also holds each model's matching rules (aliases, excluded words, engine size) and its OLX/Standvirtual search.*
## 1.2 Listings table ✅
*Later extended with tracking, scoring, duplicate and detail columns (owners, service book, origin, warranty, publication date), `price_before_drop` and `search_key`.*
## 1.3 Listing price history ✅
## 1.4 Saved searches ✅
## 1.5 Alerts ✅
## 1.6 Database indexes ✅
## 1.7 Seed mock data ✅
*Mock data has since been removed: the database holds real Standvirtual and OLX listings.*

# Sprint 2 — Backend ✅

## 2.1 List listings ✅
## 2.2 Listing detail ✅
## 2.3 Filter by model ✅
## 2.4 Sort by price ✅
## 2.5 Sort by Deal Score ✅

# Sprint 3 — Flutter Web/PWA ✅ (tag `sprint-3-web-mvp`)

## 3.1 App shell ✅
*Tabs: Ofertas · Pesquisas · Alertas (go_router StatefulShellRoute).*
## 3.2 Dashboard ✅
## 3.3 Listing card ✅
*Also shows price-change tag, "Removido" chip and source label.*
## 3.4 Filters ✅
*Model, max price, max mileage, min year, location, seller type, active only.*
➕ 3.4b Filter and save searches by minimum Deal Score / maximum Risk Score ✅
## 3.5 Listing detail page ✅
## 3.6 Loading/error/empty states ✅
## 3.7 PWA metadata ✅
*Hosted on Cloudflare Pages (➕ 3.8) and installed on the iPhone Home Screen.*
➕ 3.8 Hosting: Cloudflare Pages, deployed by GitHub Actions on every merge touching `app/` (tests must pass) ✅
➕ 3.9 Listing photos load despite missing CORS headers (`<img>` fallback) ✅
➕ 3.10 iPhone status bar matches the app background in light and dark mode ✅
➕ 3.11 Performance: lists load only the columns they show (no descriptions), the deals list is paged (40 at a time, more on scroll), first load and market card queries run in parallel, photos go straight to `<img>` ✅

# Sprint 4 — Deal Engine ✅

## 4.1 Market average ✅
*Replaced in 10.1 (➕) by a fair value per listing: median of comparable listings adjusted for age and mileage.*
## 4.2 Difference vs new ✅
*4.2b: "Comparação com uma nova" card on the detail page (new price, difference, hint under 10%, warning when not cheaper, outdated after 180 days). 4.2c: the new-bike price is set from the app (tap a model in "Modelos acompanhados"), dated the day it is saved. Prices for the 9 newer models are not set yet, and the original 4 still need checking.*
## 4.3 Price score ✅
➕ 4.3 Per-model depreciation fitted from the model's own listings (from 30 listings, blended with the general 4 %/year, 0.2 %/1000 km), shown in "Mercado deste modelo" ✅
## 4.4 Mileage score ✅
## 4.5 Year score ✅
## 4.6 Risk score ✅
*Extended in 9.5 with owners, service book, origin and warranty.*
## 4.7 Combined Deal Score 🟡
*Price 35, year/mileage 20, risk 10 and equipment 15 are live. Seller/confidence 10 and market behaviour 10 are not scored yet; the score renormalizes over the slices that have data.* ➕ 4.7b Equipment slice: extras named in the ad (quickshifter, sports exhaust, luggage, heated grips, protection, new tyres; "sem …" ignored) score 70 for one and +10 for each more; an ad that names none skips the slice instead of losing points. Shown as "Extras indicados" in the explanation and as a row of the comparison ✅
## 4.8 Score explanation ✅
*Includes estimated value for the bike's age and mileage, and reassuring facts (first owner, service book, warranty) as positives.*

# Sprint 5 — First Collector ✅

## 5.1 Choose first source ✅
*First a manual JSON import (`source = 'manual'`); Standvirtual followed in Sprint 9, OLX in 9.7.*
## 5.2 Confirm permitted data access 🟡
*API options checked, robots.txt of both sites checked and respected (read every run). **Terms of use of Standvirtual and OLX still to be read and quoted in `docs/sources.md`.** Decision recorded: low-volume personal fetcher.*
## 5.3 Create parser/adapter ✅
## 5.4 Map source fields ✅
## 5.5 Store listings ✅
## 5.6 Deduplicate ✅
*Similarity score (mileage, price, location, description, seller), threshold 70, across sources too; duplicates are excluded from market prices and scores. OLX copies of Standvirtual ads are skipped at import.*
## 5.7 Test real listings ✅

# Sprint 6 — Listing Tracking ✅

## 6.1 First seen ✅
## 6.2 Last seen ✅
## 6.3 Price changes ✅
➕ 6.3b Standvirtual's price-drop note stored as `price_before_drop`, so cuts made before tracking count ✅
## 6.4 Price history ✅
*The listing page's chart: a step line over real time from the first price to today (each price holds until the next), a dot per recorded price, the highest and lowest prices labelled on hairlines, the first date and "Hoje" underneath, and Standvirtual's earlier price (from before tracking) as a dashed "Antes" line. Geometry in `price_chart.dart`, tested.*
## 6.5 Removed detection ✅
*Only with `--full`; refuses to remove more than 50% at once; a listing seen again comes back. Rejected bikes still on the site count as seen. Since 9.9 removal is per search: only searches read in full remove their missing listings.*
## 6.6 History UI ✅

# Sprint 7 — Saved Searches ✅

## 7.1 Create saved search ✅
## 7.2 Edit saved search ✅
## 7.3 Delete saved search ✅
## 7.4 Match listings ✅
*Pesquisas shows "N ofertas" per search; tapping applies it to Ofertas.*

➕ **Accounts:** anonymous session on first visit; owner signs in with email + password (no SMTP needed).

# Sprint 8 — Alerts ✅

## 8.1 New listing alert ✅
## 8.2 Price reduction alert ✅
## 8.3 Excellent opportunity alert ✅
*Deal Score ≥ 80 and risk < 50; at most once per person per listing.*
## 8.4 Removed listing alert ✅
*Only for listings you were already alerted about.*

# Sprint 9 — Second Source ✅

➕ 9.1 Standvirtual listing-page adapter ✅
➕ 9.1b Model matching (family + version, Honda codes, engine size) ✅
➕ 9.2 Polite capped fetcher (robots.txt, 6–10 s, 20/run, 24 h pause on block) ✅
➕ 9.3 Search-page adapter (one request per model) ✅
➕ 9.4 Listing details: full description, owners, service book, origin, warranty ✅
➕ 9.4b Details read only for matched, non-duplicate listings ✅
➕ 9.5 Details used in Risk Score and shown on the detail page ✅
➕ 9.5b Risk signal for implausible mileage: under 100 km on a bike three or more years old (a placeholder like "0" or "1"), or more than 25 000 km a year; 10 points, explained on the listing page ✅
➕ 9.6 Scheduled collection on GitHub Actions, every 4 hours, 120 requests per day per site, with run log ✅
➕ 9.6b Collection status banner on the dashboard ✅
## 9.7 OLX adapter ✅
*Search result pages only (they hold the full description), every page of each search, 2023+ year filter. Standvirtual copies skipped. Fixes in 9.7b (multi-page searches, ads without a price, R7 titles) and 9.7c ("CBR 650" = CBR650R).*
➕ 9.8 Choose the tracked models in the app; matching rules moved into the catalog; 9 more models added (off by default) ✅. Fix: switching a model back on left its old listings unmatched (the collector never rematches stored listings); now switching on gives them back by the catalog brand and model names they were stored with, removed ones included, and the migration restored the listings of models already back on.
➕ 9.9 Searches built from the tracked models; removal per search; first year editable and new models added from the app; request budget shown with a warning ✅
➕ 9.7d OLX publication and renewal dates: `createdTime` is stored as `published_at` (it was missing, so the app fell back to the day we first saw the ad) and `lastRefreshTime` as `site_refreshed_at`; the listing page shows "Publicado" with the date and "Renovado no site" when the seller renewed the ad later (OLX shows the renewal date) ✅. 9.7e Standvirtual too: its search results carry `createdAt` and the bump date for every listing, so all Standvirtual listings get "Publicado" (before, only the 10 listing pages read per run gave it); the database keeps the earliest publication and the latest renewal seen, so the dates never move back and forth ✅
➕ 9.10 Collector performance: one Dart process per run (`bin/refresh.dart`) instead of seven; Standvirtual searches and listing pages share one fetcher (robots.txt read once, one 20-request budget); the pause between requests counts the time already spent since the previous one; duplicates, scores, alerts and notifications run once per run instead of three times ✅

# Sprint 10 — Market Intelligence 🟡

## 10.1 Market price distribution ✅
*"Mercado deste modelo" on the listing page opens with where the asking price sits among the model's other live listings (duplicates, the listing itself and the one it repeats left out): how many are cheaper, the same and dearer, with the median, or "o preço mais baixo/alto dos N"; below 5 others "ainda poucos dados". A strip shows every live asking price from lowest to highest with this listing's dot highlighted, labelled as asking prices not adjusted for year and km (the estimated value does that). Pure logic in `price_position_text.dart` (tested, all 42 mutations caught); prices read straight from `listings`, no migration.*
## 10.2 Model comparison ✅
*Mais → "Comparar modelos" (`/market`): one card per tracked model, cheapest typical asking price first: the median asking price with the middle half and the range, the typical bike (median year and mileage), then the same market lines as the listing page (live listings, time until leaving the market, price drops, depreciation). Below 5 listings "ainda poucos dados". New view `model_price_summary` (live, non-duplicate listings with a price; quartiles with `percentile_cont`), checked on a local Postgres. Pure logic in `model_market_text.dart` (tested, all 17 mutations caught).*
## 10.3 Price trends ⬜
*Needs a few weeks of price history first.*
## 10.4 Time-to-sale estimation 🟡
*"Mercado deste modelo" on the detail page: typical time until a listing leaves the market, share and size of price drops, depreciation rates, and how long this listing has been up (from the site's publication date; without one it says "Visto pela primeira vez há…", counted from the day the collector first saw it, never "publicado"). Shows "ainda poucos dados" until enough history exists.*
## 10.5 Deal ranking ✅
*The dashboard sorted by Deal Score is the ranking.*

➕ Fair value per listing adjusted for age and mileage ✅ (see 4.1, 4.3)

# Sprint 11 — Quality 🟡

## 11.1 Unit tests 🟡
*App: alerts, saved searches, score explainer, risk reasons, market behaviour, collector status, new-price text, catalog, tracked-models, model-picker, price-position and model-market text. Collector (186 tests): import, enrich and notify steps (with fakes), JSON readers, adapters, mappers, model resolver (real OLX titles), search plan, removal plan, normalizers, store, fetcher, robots.txt, run status. SQL has its own tests since 11.2.*
## 11.2 Integration tests ✅
*`make db-test` (and every pull request, in `check.yml` with a Postgres service): all migrations applied to an empty Postgres, with stand-ins for what only Supabase has (API roles and its default grants, `auth`, pg_cron, pg_net, Vault), then the SQL tests in `supabase/tests/`, each in a transaction rolled back at the end: price tracking (first price, history, `price_changed`), alerts (only events after the saved search, drops from 1 %, never twice), duplicates across sites (left out of market prices), scoring (equipment slice, extras, a cheaper bike ranks higher), access (anonymous and signed-out users can't read runs or change the catalog, the collector's functions aren't callable from the app), data quality, the watchdog, removal (only the searches read in full, unkeyed listings only when asked, never the other site's, more than half refused unless forced, an empty import refused) the import steps (`rematch_listings` changes only listings whose model changed, `set_search_keys`, `apply_listing_dates` keeps the earliest publication and latest renewal, `apply_prices_before_drop` keeps the highest, switching a model off and on unmatches and rematches its listings, removed ones too, never the other site's; `mark_listings_seen` brings a removed listing back, `apply_listing_details` never erases what a page left out), the pure scoring functions with literal values (price, year and mileage scores, the deal-score combiner and its breakdown, the age/mileage factor and its limits, duplicate similarity, every risk signal and the 0-100 limits), the catalog RPCs (a new model is trimmed, tracked and never added twice; bad years, prices, engine ranges and other sites' addresses are refused; anonymous sessions can't), Telegram notifications (only real accounts' alerts, oldest first, each marked sent once), the schedules (the pg_cron jobs' times and workflows; `dispatch_workflow` posts to the workflow's dispatch address with the Vault token, sends nothing without it, starts no other workflow and can't be called from the app) and relists (old ad, first date on sale through a chain, old price; not after 90 days, not a dealer's identical new bikes). A deliberately wrong assertion fails the run.*
## 11.3 Logging ✅
*Every scheduled run is recorded in `collector_runs` with a log tail; Actions keeps the full log for 7 days. Each run also stores what it did (`counts`: new listings, price changes, removed listings and alerts created, summed over both sites, read from the log by `runCounts` in `report_run.dart`; `20261020220000_run_counts.sql`), shown in Mais under the last run ("3 anúncios novos, 2 preços alterados, 4 alertas", or "Sem anúncios novos nem alterações"; `runCountsText`, tested). Older runs show nothing there.*
## 11.4 Error handling ✅
*Fetcher stops and pauses on blocks; incomplete searches never trigger removals; the dashboard shows when the last run failed, was blocked or is too old. A run whose status differs from the previous run's (ok, blocked, failed) sends one Telegram message: the error lines with the site each happened on (`run_health.dart`, tested, every mutation caught), or that the collection works again; the same problem is never repeated every 4 hours, and a failed message never fails the run. A run that never starts (expired GitHub token, the `collect-listings` job gone, a job dying before it records itself) is caught in Postgres: the hourly pg_cron job `collection-watchdog` (`check_collection_runs()`, `20261020210000_collection_watchdog.sql`) sends a Telegram message through pg_net after 9 hours without a run, once a day while it lasts, and the recovery after the next run (needs the Vault secrets `telegram_bot_token` and `telegram_chat_id`, see `docs/hosting.md`); tested in `watchdog_test.sql`, including that the app can neither call it nor read its state.*
## 11.5 Data-quality monitoring ✅
*Collector failures and blocks are tracked; requests used per site and run, run duration and monthly runs are shown in Mais. "Qualidade dos dados" in Mais (view `source_data_quality`): per site, live listings, how many are tracked models, unmatched or duplicates, the share of scored listings missing year, mileage or location, and Standvirtual listing pages still to read. Each site also shows when its listings were last seen on the site, with "verifique a recolha" after 24 hours (a site that stops answering keeps its listings live, so this is what goes stale), and how many live listings had their price halved or raised by half or more in one step in the last 30 days (likely misreads). Both added to the view in `20261020200000_data_quality_freshness.sql`, checked on a local Postgres; text in `data_quality_text.dart`, tested (every mutation of the new lines caught).*

➕ **Notifications on the phone via Telegram** ✅ (11.1; replaces Web/PWA push). 11.1b: "Test Telegram" workflow / `make notify-test` sends a test message. Confirmed on Rafael's phone (2026-10-19) after `TELEGRAM_CHAT_ID` was corrected (it held the bot's own id).
➕ **Weekly Telegram summary** ✅ (11.1c): every Monday (`weekly-summary.yml`, 07:52 UTC via Supabase pg_cron, or "Run workflow") one message about the tracked models' last 7 days: new listings per model, price drops of 1 % or more (biggest 3 shown), listings gone, live count, and the 5 best live deals with risk below 50, each with its link. Reads the database only; `make weekly-summary ARGS=--dry-run` prints it. Its queries read every page of results (the server returns at most 1 000 rows per request, so a busy week could silently miss price drops).
➕ **Housekeeping** 🟡: saved pages and fetch state are no longer tracked ✅; **the repo should be made private** (old saved pages with phone numbers remain in git history) ⬜.

➕ **Compare listings** ✅ (13.7): long press a card in Ofertas (or "Comparar" on a listing's page) to pick up to 3; "Comparar (n)" opens them side by side (`/compare?ids=…`, so a reload keeps them): photo and title per column, then price, Deal Score, Risk Score, difference to the market value, year, km, price drop, owners, service book, location, seller, source and first seen, the best value of each row highlighted. Table logic in `compare_text.dart`, tested.

➕ **Mileage counts more** ✅ (4.4c): on the real MT-07 market (72 listings) asking prices fall only ~0.25 % per 1000 km, so a 2023 bike with 25 000 km was valued like its low-mileage peers (6 785 €). The fair value's mileage rate is now at least 0.5 % per 1000 km (6 466 € for that bike; low-mileage bikes barely change), comparables without year or mileage are left out, and the explanation says the estimate comes from asking prices.

➕ **Model re-check** ✅ (9.8b): a Forza 125 was stored as the Forza 350 (a model added in the app has no engine limits, so when the site's model field said only "Forza" the engine-size fallback accepted any size). The fallback now skips models without limits, and every import re-checks the model of the ads it read (`rematch_listings`), since `save` never updates a stored listing: wrong matches already stored are corrected on the next run.

➕ **Brand and model picker** ✅ (9.9b): "Adicionar modelo" no longer needs addresses copied from the browser. The collector stores the brand and model lists in the filters of the search pages it already reads (`site_models`: Standvirtual lists every brand's models with ad counts, OLX only the searched brand's; no extra requests). The form picks the brand (most ads first) and the model, with an optional engine size: empty = every size; 350 names the model "Forza 350", searches Standvirtual for "350" and matches only bikes of 315-385 cc (`add_catalog_model` takes `engine_cc_min/max`). The OLX search is added only when OLX's own list has the model (by id or name; OLX's ids differ for some, and it has no list for brands never searched); otherwise only Standvirtual, or "Escrever à mão" for the old form.

➕ **Relisted ads** ✅ (20.2): when a bike is taken down and listed again as a new ad (same model and year, same similarity rule as duplicates, gone at most 90 days before the new ad appeared), the new listing links to the earlier one. The listing page shows "Anúncio publicado de novo: esteve à venda noutro anúncio desde … (há N dias), a última vez por … (agora menos …)" with "Ver anterior". Marked by `mark_relists` at the end of `mark_duplicates`, so the collector is unchanged.

➕ **Fewer missed ads** ✅ (9.10b): checked against the run of 2026-10-20 16:40. Standvirtual: only the first page (32 listings) of a search was read; now every page (`?page=N`), with the first tracked year as a filter so old bikes don't use up pages (the address changes, so listings are tied to the new one as runs find them). Models named with a size but added without one ("Forza 350", "ADV 350") had no engine limits, so 14 Standvirtual ads named only "Forza"/"ADV" stayed unmatched; the name's size now gives the range (migration and `add_catalog_model`, `engine_range_from_name`). "350cc" in a title reads as "350" (an OLX "Honda modelo ADV 350cc", 2025, was missed). Listings under an address no search uses any more were never removed; a run that read every search in full now covers them (tracked model, within its years). SQL tests in `removal_test.sql`, `catalog_test.sql`, `engine_from_name_test.sql`.

➕ **Scheduled collection never started** ✅ (9.6c): GitHub never ran `collect.yml` on its schedule (no scheduled run at all since 2026-10-19 morning, not even with an hourly cron; every run was manual), though the workflow was on `main`, active, valid and the repo public. Now Supabase starts it: pg_cron jobs `collect-listings` (every 4 hours, minute 40 UTC) and `weekly-summary` (Mondays 07:52 UTC) call `dispatch_workflow()`, which asks GitHub's workflow_dispatch API through pg_net with a repo-only token from the Vault. The workflows no longer have a `schedule`; the app's next-run text is back to every 4 hours.

# Sprint 13 — UI/UX redesign ✅

*Goal: the app has grown screen by screen; make it coherent on the iPhone. Each step is a small PR Rafael checks on the phone.*

## 13.1 UX audit and navigation plan ✅
*Walk every screen, list what doesn't make sense, agree the structure before changing it. Known issues so far:*
- *The account (profile icon) lives only in the Pesquisas app bar, and "Modelos acompanhados" is hidden inside the account sheet.*
- *Ofertas has no way to change the sort order (the code supports newest, price and Deal Score).*
- *Ofertas still shows listings of switched-off models and unmatched listings.*
- *Saved searches can only be created from the bookmark icon in Ofertas, not from Pesquisas.*
- *The Alertas tab shows no unread badge.*
- *The listing page shows only the first photo.*
- *The text mixes "tu" and "você" ("Escolhe os modelos…" vs "Verifique a ligação…").*
## 13.2 A "Mais"/settings tab ✅
*Fourth tab "Mais" with the account (sign in/out), Modelos acompanhados and the collection: when the last run ended and how long it took, requests used per site (of 20), when the next run is due, and this month's runs with an estimate of GitHub Actions minutes. The profile icon left Pesquisas and the models link left the account sheet. The status card shows only when something is wrong (failed, blocked, no recent run) and lives only in Mais; the "Atualizado há…" line left Ofertas.*
## 13.3 Ofertas ✅
*Only listings of tracked models (switched-off models' listings and unmatched ones are left out); a sort menu (Melhor pontuação, Mais recentes, Preço mais baixo/alto); applied filters as chips under the status line, each removable on its own, plus "Limpar tudo".*
## 13.4 Listing page ✅
*Photo gallery (swipe or arrows, "3 / 12" counter, tap for full screen). Sections ordered for a decision: photos, model, price and a line with year · km · location · seller type; then the score with its risks, "also listed as", the new-bike comparison, "A mota" (year, km, owners, service book, origin, warranties), the description (folded after 8 lines), the market, the price history and "O anúncio" (seller, source, dates, status). The button to the ad ("Ver no OLX"/"Ver no Standvirtual") stays fixed at the bottom.*
## 13.4b Look and feel ✅
*The app stops looking like the Material default: hand-made light and dark colours (cool greys, one racing-orange accent, white cards with a hairline border instead of shadows and pink tints), bundled Barlow fonts (Semi Condensed for titles, prices and scores, tabular figures for prices), semantic colours for good/bad and score bands (`AppColors`), a square score badge, the score card led by the score and its label with a coloured risk bar, listing cards with a bigger photo and icon facts, a hairline above the tab bar, grouped cards in Mais, and empty states with a round icon.*
## 13.5 Pesquisas and Alertas ✅
*"Nova pesquisa" in Pesquisas (name, criteria and alert choices in one sheet; also the empty screen's button). The Alertas tab shows the unread count, loaded when the app opens and again when it comes back to the screen. Alerts are grouped under "Hoje", "Ontem", the weekday, then the date, each with its time and a coloured icon by type.*
## 13.6 One voice and polish ✅
*All pt-PT text speaks to the user as "você" ("Indique", "a sua conta", "Toque…"); the few "tu" forms and bare infinitive instructions were changed, and `test/voice_test.dart` fails the build if a "tu" form comes back. Ofertas shows card-shaped placeholders while loading instead of a spinner; every page uses the same empty/error screen (`StateMessage`); the unused placeholder page was removed. Light/dark and safe areas were covered by 13.4b (themed colours, bottom bar and sheets inside the safe area). Fix after it: the status bar stayed dark in light mode on the iPhone (it ignored the light/dark `theme-color` tags and used the last one); now one tag, set by a script from the current mode. That was not enough: the real cause was every AppBar telling Flutter a transparent-black status bar colour, which Flutter writes into theme-color and Safari shows as black; the AppBar theme now gives the page background. Still black on iOS 26: Safari 26 ignores theme-color and samples a solid fixed element at the page's top/bottom edge (Flutter's page gave it black), so `index.html` now has two thin iOS-only strips, the top one following theme-color (so the photo viewer turns it black), the bottom one the tab bar colour. That fixed it; in the home-screen app the bottom strip then covered the tab labels and the labels sat under the home bar, so the strip is hidden there and the app adds a 24px bottom safe area on iPhones with a home bar. In a Safari tab the strip then covered the labels too, so there the app leaves 12px (the strip's height) under the tab bar.*

# Sprint 15 — Deciding and buying 🟡

*Goal: from "which listings are good" to "which bike do I buy, for how much". Proposed 2026-10-20 after the original concept was mostly built; each step is a small PR. Order: what works with today's data first, then the score, then what needs history or outside sources.*

## 15.1 Favourites and notes ✅
*A star on the listing page (app bar) adds the listing to the favourites; while it is one, "As suas notas" under the price holds a private note (what the seller said, what to check, what to offer; up to 2000 characters). Cards in Ofertas show a star on the photo. "Favoritos" (star in the Ofertas app bar, and in Mais) lists them newest first with the note and "Adicionado aos favoritos há N dias"; removed listings stay, marked "Removido", so the shortlist shows what sold. Taking out a favourite with a note asks first (the note goes too).*
*Data: table `listing_favourites (user_id, listing_id, note, created_at, updated_at)`, owner-only RLS like saved searches (anonymous sessions too, but they lose them on sign-out; the account sheet reloads them on sign-in). Alerts: `generate_favourite_alerts()` (part of `generate_alerts()`) gives the owner every price drop of 1 % or more and the removal of a favourite, after it became one, with no saved search needed (`saved_search_id` null); the alerts' unique indexes keep one alert per price change and one removal, so a favourite also in a saved search alerts once. Telegram picks them up like any alert. App: `FavouritesCubit` (lazy singleton, loaded by the shell; changes show at once and are undone if saving fails), `favourites_text.dart`. Tests: `supabase/tests/favourites_test.sql`, `app/test/favourites_test.dart`.*
## 15.2 Price to offer ✅
*"Quanto oferecer" on the listing page, under the score: "Comece por X e não passe de Y", with the reasons in words and "Estimativa a partir dos preços pedidos, não de vendas". The ceiling is the asking price, or the estimated value (`score_breakdown.market_price`) when the asking price is more than 2 % above it. The opening starts 6 % below the ceiling for a private seller and 3 % for a dealer (a rule of thumb, said as such), plus 3 % when the bike has been on sale longer than the model's typical time to leave the market (45 days without 5 gone listings; 5 % past twice that), plus half the model's typical drop (at most 4 %) when a third or more of its sellers drop and this one has not, minus 2 % when it already dropped, plus 3 % for a high risk (>= 50); between 1 % and 15 %, rounded down to 50 €. Days on sale count from the first relist, else the site's publication, else the first sighting. Hidden for removed listings, duplicates and listings without an estimated value. ➕ 15.2b: the longer on sale, the more room (a seller who has waited may take a lower offer): 3 % past the typical time, 5 % past twice it, 7 % past three times it ("mais do triplo do típico deste modelo: o vendedor pode aceitar uma proposta mais baixa"), plus 2 % for a relisted bike (its earlier ad went without a sale). Pure logic in `offer_text.dart` (`suggestOffer`, `daysOnSale`, tested, mutation target), card in `widgets/offer_card.dart` (loads the model's market behaviour; works without it).*
## 15.3 Viewing checklist ✅
*"Para a visita" on the listing page, under "As suas notas", while the listing is a favourite: "N pontos para ver na visita", then "3 de 12 vistos · 1 problema" or "Tudo visto, sem problemas". It opens a sheet with 12 points in three groups, each with what to look for: Documentos (Documento Único: VIN and plate against the bike, the seller is the owner; certidão de registo automóvel for liens and finance; revisões; chaves), Estado da mota (sinais de queda, pneus with the DOT date, corrente e cremalheira, travões e discos, suspensões), A trabalhar (arranque a frio, luzes e elétrica, experimentar a andar). Each point is marked "Está bem" or "Problema" (tap again to clear) and can carry a short note (up to 300 characters, "DOT 2017"). Favoritos shows the problems ("Problemas: Pneus, Travões e discos") or the progress under each favourite.*
*Data: `listing_favourites.checklist jsonb` (`{"tyres": {"mark": "issue", "note": "DOT 2017"}}`, an object of at most 32 kB; existing favourites get `{}`), same owner-only RLS. The list lives in the app (`viewing_checklist.dart`: stable keys, summary and problem texts); keys of items taken out later are ignored, so the list can change without a migration. Model-specific items and using the problems in "Quanto oferecer" can come later. Tests: `supabase/tests/favourite_checklist_test.sql`, `app/test/viewing_checklist_test.dart`, `app/test/favourites_test.dart`.*
## 15.4 Cost of ownership ✅
*"Custo de ter esta mota" on the listing page (live listings with a price): "Custa cerca de X € por ano" and the total for the years the owner plans to keep it, with one line per part. Depreciation: the average yearly loss over those years on the model's own curve (`model_depreciation`, the same exp(-rate) as the fair price; the general rates without a matched model) at the owner's km per year. IUC: category E, registered after 1996, by the engine size of the model (middle of its catalog range, now loaded with the listing), nothing under 10 €. Insurance: the owner's own quote, left out (and said so) until entered. Tyres (one set per 6 000-12 000 km by size, at least one every 5 years), services (every 6 000-10 000 km, at least once a year) and chain kit (every 20 000 km), workshop prices by engine size (up to 400 cc, up to 800, larger). "Alterar" edits the owner's figures (insurance, km per year, default 5 000, years to keep, default 3), stored per account in `ownership_settings` (owner-only RLS). Tables and logic in `ownership_cost.dart` (pure, tested in `app/test/ownership_cost_test.dart`); SQL test `ownership_settings_test.sql`. **The IUC table (`iucBands`, 2024 values kept in 2025 and 2026) needs checking every January.**
## 15.5 Relisted as a risk signal ✅
*Two risk reasons from the relist links of 20.2 (`mark_relists`): `relisted` (5 points) for a bike put up again after its ad went, `relisted_often` (10) when that happened twice (this ad's previous ad was itself a relist) or the bike has been on sale for over 90 days counting the earlier ads (`relisted_since`). A long time on sale without a relist is not a signal. `risk_assessment` takes two new parameters (`p_relists`, `p_on_sale_since`), so the function and `listing_risk_scores` are created again. The app explains them ("Já esteve à venda noutro anúncio e não foi vendida", "Posta à venda várias vezes ou há mais de 90 dias sem ser vendida"). Tests: `scoring_functions_test.sql` (thresholds), `relists_test.sql` (through the view), `app/test/risk_reasons_test.dart`.*
## 15.6 Consistency checks in the text ✅
*`text_contradictions(description, year, mileage, origin, service_book)` (pure, immutable, tested with literals) finds clear contradictions between the description and the ad's own fields, each a risk reason of 10 points: `text_year_mismatch` ("ano 2018", "matrícula de 2018" 2 or more years from the year field; one year off is normal, built one year and registered the next; other years in the text such as a service date are not read), `text_mileage_mismatch` ("tem 30 mil km", "com 30.000 km" over 20 % and 2 000 km above the field; fewer km in the text are usually the tyres or a service and don't count), `text_origin_mismatch` ("importada", "matrícula estrangeira/espanhola…" on an ad that says national; "não é importada" doesn't count), `text_service_book_mismatch` ("sem livro" while the ad says service book). Called from `risk_assessment` (same signature). The app explains each one. Tests: `scoring_functions_test.sql`, `app/test/risk_reasons_test.dart`.*
## 15.7 Seller / dealer reliability 🟡
*Fills the empty 10 % "Seller / confidence" slice of the Deal Score (4.7). Per dealer (name kept only for dealers, never private sellers): how often their ads are relisted, sharp price changes, missing mileage, share of duplicates; a private seller gets the neutral value. Needs a few weeks of data per dealer; start by showing the figures, then score them.*

*Done: the figures. View `dealer_reliability` (readable by everyone, like the listings): one row per dealer name (trimmed, case-folded, both sites), over every ad seen of it, live or gone: bikes (ads that are not a repeat), live, relisted, sharp price changes (a step of 50 % or more), missing mileage, repeated (a used bike, 1 000 km or more, posted twice on the same site; identical new bikes in stock don't count), price dropped, first seen. Shown on dealer listings as "O stand" (`dealer_card.dart`, text in `dealer_text.dart`): warning signs out of the bikes seen, how often it lowered prices, "ainda poucos dados" under 5 bikes. Tests: `dealer_reliability_test.sql`, `app/test/dealer_text_test.dart`. **Still to do:** score it in the Deal Score once dealers have a few weeks of data.*
## 15.8 Price trends and market slice ⬜
*The same as 10.3 and the market slice of 4.7, listed here so the sprint shows everything planned: median asking price per model per week, and time on market / price drops in the Deal Score, once a few weeks of history exist.*
## 15.9 More sources ⬜
*Dealer websites (big Portuguese dealers that publish their stock), or one European site for imports (with the import costs: ISV, transport, legalisation). Each needs Rafael's check of its terms first (as 5.2) and follows the fetching rules; Facebook Marketplace and CustoJusto stay manual.*
## 15.10 Web push ⬜
*Alerts on the iPhone without Telegram: web push works for a web app added to the home screen (iOS 16.4+). Needs a service worker message handler, VAPID keys (secrets created by Rafael), a `push_subscriptions` table and a sender after each run. Low priority: Telegram already works.*
## 15.11 Distance from home ✅
*Each listing shows how far it is from the owner's home ("Matosinhos, a 8 km") on the cards, the listing page and the comparison, with a "Distância máxima" filter (25-300 km, also in saved searches and their alerts) and a "Mais perto" sort. The home is a town picked in Mais ("A sua localidade", search accent- and case-insensitive), stored per account in `user_home`. `places`: about 930 Portuguese towns, the 308 municipalities and the district names with coordinates (GeoNames, CC BY 4.0, via the npm package `cities.json` 1.1.65; towns over 1 000 people; a municipality is its seat or the middle of its towns; 6 small seats added by hand; names shared by places over 25 km apart left out; Lisboa, Madeira and Açores spellings added). `place_key()` matches the sites' place text (lower case, no accents, no "(parish)", nothing after a comma; `placeKey` in the app is the same); `listings.distance_km` is a PostgREST computed field (straight line from the caller's home, null when either place is unknown), so it can be selected, filtered and ordered; `saved_search_matches` uses the search owner's home. Tests: `listing_distance_test.sql`, `app/test/distance_test.dart`. Places the list doesn't know show no distance (and fall outside a distance filter).*
## 15.12 Message to the seller ✅
*"Mensagem para o vendedor" on the listing page (live listings): a polite first message in pt-PT naming the bike and the site, asking only what the ad leaves open (mileage, owners, service book, origin when missing; always whether it is still available, falls or accidents, where and when to see it; whether the registration is in the seller's name for private sellers), with an optional "Incluir proposta de X €" (the opening price of "Quanto oferecer"). "Copiar mensagem" puts it on the clipboard for the site's chat or WhatsApp. Text in `seller_message_text.dart` (tests: `app/test/seller_message_text_test.dart`).*
## 15.13 Equipment filter ✅
*Ofertas can filter by equipment the ad mentions (quickshifter, escape desportivo, malas, punhos aquecidos, proteções, pneus novos: the `listing_extras` codes already stored in `score_breakdown.extras`), all required, one chip each. Saved searches keep it (`saved_searches.extras`, checked against the known codes) and their alerts follow it (`saved_search_matches`). Tests: `saved_search_extras_test.sql`, `app/test/equipment_filter_test.dart`.*
## 15.14 "Voltou ao mercado" alert ✅
*A new alert type, `back_on_market`: when a gone ad comes back as a new one (a relist, found by `mark_relists` before the alerts run), the people who followed the earlier ad (a favourite, or an active saved search that alerted them about it) get "Voltou ao mercado" for the new ad, once per person, with the new price and the earlier ad's last price ("6 800 € (antes 7 200 €)"); the favourite's alert wins when both apply. Only relists first seen in the last 14 days, so the first run doesn't bring up old ones. In the app (Alertas, its own icon) and on Telegram ("🔁 Voltou ao mercado"). Two migrations, because a new enum value can't be used in the transaction that adds it; `make db-test` now applies each migration in one transaction, as the merge does, so that mistake shows in tests. Tests: `back_on_market_test.sql`, `collector/test/notify_test.dart`, `app/test/alerts_text_test.dart`.*
## 15.15 Scoring review: equipment, mileage for the age, offer ✅
*Rafael, 2026-10-20. **Equipment:** 13 new kinds read from the ads (short plate holder / fender eliminator, tinted or sport screen, adjustable levers (also misspelt, "manteres curtas"), bar-end mirrors, phone mount or USB, alarm or tracker such as Mapit, steering damper, centre stand, cruise control, upgraded suspension such as Öhlins, LED indicators, passenger grab handles, original parts included so it can go back to stock) and more words for the old ones ("cogumelos", crash bars, radiator guard, tank bag, exhaust brands such as GPR, "escape after market", up/down shifter, tyres "mudados"); 19 filter chips. An ad Rafael found (7 extras, only the quickshifter seen) is a test case. **Mileage:** judged against the bike's age instead of a flat 0-20 000 km line: 5 000 km a year is normal for a motorcycle (cars 10-12 000), from mid-year registration, at least one year's; 100 up to half the normal, 75 at it, 50 at 1.5 times, 0 from 2.5 times (`mileage_use_score`, `expected_mileage`). The listing page says "Poucos km para o ano", "Km normais para o ano", "Km acima do normal" or "Muitos km para o ano", with the normal. **Offer:** a fair bike long on sale was told to start 15 % below (about 1 000 € on an 8 000 € bike); now how far the asking price already is below the estimate comes off the room, everything is capped at 10 %, and the opening never goes under 90 % of the estimated value (that case: 350 € below; Rafael's CB650R, 8 500 € asked, 7 950 € instead of 7 350 €). **Negotiation plan:** "Quanto oferecer" lists the offers in turn (first, "Se recusar" halfway, the last = the most to pay), and "O vendedor pediu" answers the seller's counter-offer: accept up to the second offer, propose halfway up to the most to pay, above it make the last offer and walk away (`steps`, `replyTo`, `parseCounterOffer` in `offer_text.dart`). Tests: `scores_test.sql` (Rafael's phrases among them), `app/test/offer_text_test.dart`, `app/test/score_explainer_test.dart`, `app/test/equipment_filter_test.dart`.*
## 15.16 Close button on the filters sheet ✅
*Rafael, 2026-10-20: the filters sheet fills the iPhone's screen, leaving no backdrop to tap and no way out except Aplicar or Limpar. Its title row now has a close button ("Fechar") that keeps the current filters (also in the saved-search editor, which uses the same sheet).*

# Sprint 14 — More than one person ⬜

*Only needed if someone else will use the app. Today the tracked models are one shared list (`motorcycles.is_active`): any signed-in account changes it for everyone, and everyone sees the same listings.*

## 14.1 Per-person model selection ⬜
*`user_models (user_id, motorcycle_id)`; "Modelos acompanhados" edits your own list; Ofertas, filters and saved searches show your models only.*
## 14.2 Collector follows the union ⬜
*A model is searched while at least one person tracks it; `is_active` becomes "someone tracks it". Scores and market data stay shared (the market is the same for everyone).*
## 14.3 Accounts ⬜
*Today accounts are created by hand in Supabase; a second person needs an invite or sign-up path, and Telegram per person (own chat id).*

# Sprint 12 — Flutter iOS ⬜

*Decision: stay with the home-screen web app. A native build needs a paid Apple Developer account (TestFlight); with a free account apps expire after 7 days.*

## 12.1 Create native Flutter app target ⬜
## 12.2 Reuse backend ⬜
## 12.3 Native notifications ⬜
## 12.4 Mobile-specific UX ⬜

# Tooling

## T.1 Automatic code-quality review ✅
*`.github/workflows/code-quality.yml`: after every 5 merged PRs (or "Run workflow"), Claude Code reviews the code on GitHub Actions, with Flutter installed so `make check` really runs, and opens at most one small PR labelled `code-quality` (none if nothing is worth changing). It works from a backlog, `docs/code-quality.md`. T.1b: each run does one thing: while the list has items it does up to 3 (all if fewer are left) and finds nothing; when the list is empty it only reviews the code and writes up to 10 new items, changing no code (before, the run that refilled the list also did 3 of them). The PR is pushed with the job's own token (the Claude step revokes its token when it ends; the first run failed on that). The tag `code-quality-reviewed` marks the last review; no review starts while one is open. Runs on Rafael's Claude plan through the `CLAUDE_CODE_OAUTH_TOKEN` secret.*

## T.2 Checks on pull requests ✅
*`.github/workflows/check.yml` runs `make check` with Flutter installed (app analyze and tests, collector format, analyze and tests) on every pull request to main, so app changes made where Flutter isn't installed are compiled and tested before merging, not only by the deploy afterwards.*

## T.3 Automatic test hardening ✅
*`.github/workflows/test-hardening.yml`, mutation testing in the spirit of Stryker, done by Claude: the same find-then-fix cycle on `docs/test-hardening.md`. A find run tries hostile inputs on the pure logic (a bug counts only when a throwaway test fails), makes about 30 small temporary changes to the code to find what the tests don't notice, and spots redundant tests; fix runs add the failing test then the fix, add the missing tests, and drop redundant ones. Both passes share `backlog-pass.yml` and run one at a time; their own PRs don't count towards the 5 merges. T.3b: the first run committed nothing after 7 permission denials (Claude couldn't write the PR title to /tmp or use read-only shell commands); it now may, and the log shows Claude's full transcript.*

## T.4 Mutation testing without AI ✅
*`.github/workflows/mutation.yml` with the `mutation_test` Dart tool (driven by `tool/mutation.py`, also `make mutation`): the pure logic listed in `collector/mutation_targets.txt` (21 files, about 730 mutations; each runs the whole collector suite, ~5 s) and `app/mutation_targets.txt` (15 `*_text.dart`/formatter files, each with its own test) gets small changes one at a time. After a merge only the changed targets run; "Run workflow" runs all in 4+4 parallel jobs. Report only: the run's page shows the score per file and every surviving mutant, the HTML reports are artifacts, and test hardening's find runs start from the latest summary. T.4b (cost): the two Claude passes no longer overlap (code quality looks only at how the code is written; bugs and tests are test hardening's), find runs wait for 10 merges (fix runs stay at 5), and hardening's own hand-made mutations (about 15) cover only files the tool doesn't. Bot PRs got no checks (GitHub doesn't start `pull_request` workflows for PRs opened with `GITHUB_TOKEN`); the passes now start `check.yml` by `workflow_dispatch` on the new PR's branch, and its result shows on the PR. First local results: model resolver 84 % (engine limits not tested at the exact boundary), search plan 100 %, site models 87 %. First full run (2026-10-20, 8 jobs, longest 14 min): 82 % overall (847 of 1 029; collector 80 %, app 88 %); weakest `fetch_searches` 38 %, `enrich_steps` 44 %, `catalog` 55 %, `collection_text` 59 %, `import_steps` 66 %, `polite_fetcher` 67 % (30 survivors). Find runs take the latest *full* run's summary (`--event workflow_dispatch`): a merge's run tests only the changed files.*

## T.5 Migrations applied on merge ✅
*No more `make db-push` by hand. `deploy-web.yml` now starts with a `migrate` job; the app is built and published only after it succeeds, so the app never reaches a database without the columns it reads. The job finds the migrations the merge adds (`tool/check_migrations.sh BEFORE AFTER`); with none, every step is skipped. With some, it runs `make db-test` again on the merged code (every migration on an empty Postgres plus every SQL test), then `supabase db push --dry-run` (the log lists what will run) and `supabase db push` with the `SUPABASE_DB_URL` secret (Session pooler connection string). A failed test or migration stops the app deploy. The workflow also starts on merges that only add migrations, and runs one at a time without cancelling (stopping a migration halfway is worse than waiting). "Run workflow" by hand always tests and applies whatever is missing. The same script runs in `check.yml` on every pull request, so problems show before merging: a change, rename or deletion of a migration already on main (it may be live, and db push never runs a file again: add a new migration instead), a new migration not named `<14 digits>_<name>.sql`, or one not sorting after main's latest. Tried on 8 cases (none, one new, edited, deleted, renamed, older version, bad name, only a test changed). T.5b: the first run stopped safely at "failed to parse connection string" (nothing applied, the app not deployed): a password with `! * ?` must be URL-encoded inside the URL. Now `SUPABASE_DB_URL` is the pooler string as Supabase shows it (`[YOUR-PASSWORD]` left in) plus `SUPABASE_DB_PASSWORD` as typed; `tool/db_url.py` encodes the password, drops pasted quotes and spaces, and names the problem without printing the secret (tests: `tool/test_db_url.py`, `make tool-check`, part of `make check`). The second run read the URL but it was the Direct connection (`db.<project>.supabase.co`, IPv6 only, which GitHub's runners can't reach); `db_url.py` now refuses it and says to copy the Session pooler string instead. Even with the pooler string, the next runs still dialled `db.<project>.supabase.co` as `postgres`: the Supabase CLI rewrites a pooler URL to the direct host. So the job no longer uses `supabase db push`: `tool/apply_migrations.sh` applies the missing migrations with psql on the URL as given, through the pooler, over TLS (`sslmode=require`), each in one transaction together with its row in the CLI's history table (`supabase_migrations.schema_migrations`, so `make db-push` and `supabase migration list` still agree), lists them first (`--dry-run`), and refuses to run when the database has a version the repository doesn't. Tried on a local Postgres: up to date, three pending applied and recorded, a second run does nothing, a failing migration leaves no trace and stops the rest, an unknown version is refused. First automatic apply on a merge: #101 (`ownership_settings`), then the app deployed.*
## T.6 Preview of every pull request ✅
*`preview-web.yml`: every PR touching `app/` is built and published to its own Cloudflare Pages address (`pr-<number>.motorcycle-deal-tracker.pages.dev`, the branch alias, so the link stays the same on every push) and linked in one comment on the PR, edited on each push. Production is untouched (only `main` is production). The preview reads the real database; migrations in the PR are applied only on merge. Fork PRs get no secrets and no preview. Each push deletes the PR's older builds (each had its own address) and closing or merging the PR deletes its preview and says so in the comment (`tool/pages_previews.py`, which only ever touches preview deployments of a `pr-<number>` branch; tests: `tool/test_pages_previews.py`). Free: Cloudflare Pages has no limit on previews, requests or bandwidth, and its 500 builds a month only count builds Cloudflare runs (ours are uploaded); GitHub Actions minutes are free while the repository is public (2 000 a month if private, about 1.5 per preview).*
## T.7 Cloud session setup ✅
*`.claude/hooks/session-start.sh` (registered in `.claude/settings.json`, runs only in Claude Code cloud sessions): installs the latest stable Dart SDK in `~/.cache/dart-sdk` (on PATH), the collector's dependencies from the lockfile (never changing it), and starts the local Postgres with a superuser for the session's user (`PGHOST` set), so `make collector-check`, `make tool-check` and `make db-test` work as they are. Flutter is deliberately not installed: the app is checked by CI.*
## T.8 Automatic merge of backlog PRs ✅
*Rafael's go-ahead, 2026-10-20. After `backlog-pass.yml` opens a code-quality or test-hardening PR and starts its check, it waits for that check run (the one for the PR's exact commit) and merges the PR when it passes (`gh pr merge --match-head-commit`, so never a commit the check didn't see). It leaves the PR for a manual merge when the check fails or can't be found, when the PR touches migrations or anything under `supabase/`, workflows, `tool/` or the Makefile, or when the repository variable `AUTO_MERGE_BACKLOG` is `false` (the off switch). A merge made with the workflow's token starts no push workflows, so it starts "Deploy web app" itself when the PR changed `app/`; mutation testing of the changed files waits for the next ordinary merge.*

# Checks without AI (N)

*Rafael, 2026-10-20: AI is fine where it is free, but a fixed, free tool is preferred whenever it can do the same job. The app and the collector use no AI at all (every score, estimate and alert is rules and statistics in Dart and SQL). The only AI is the two Claude backlog passes (on Rafael's subscription), which now leave to the tools below what they catch.*

## N.1 Stricter analyzer rules ✅
*Both packages: strict casts, inference and raw types, plus rules for async mistakes (unawaited futures, async void), type safety (dynamic calls, return types, throwing non-errors), dead code and immutability (`*/analysis_options.yaml`). The collector also forbids catch-alls and redundant arguments; the app doesn't (screens catch every failure on purpose; `DateTime(2027, 3, 1)` reads better than the default left out). All findings fixed.*
## N.2 Copy-paste check ✅
*`make duplication` (jscpd via npx, also in `check.yml`): exact clones of 70+ tokens in app/lib and the collector; over 1 % of lines fails. Today 0.22 % (4 small clones).*
## N.3 Coverage floors ✅
*`make coverage` (also in `check.yml`, summary on the run page): line coverage of the collector (floor 70 %, today 74 %) and of the app's logic (texts, entities, models, cubits; floor 90 %, today 94.7 %), by `tool/lcov_summary.py` (tests: `tool/test_lcov_summary.py`). Raise a floor as tests are added; lower one only with a reason.*
## N.4 Mutation score floor ⬜
*Mutation testing already runs without AI after merges (`mutation.yml`); a minimum score comes once the next full run gives the current one.*
## N.5 Dependabot ✅
*`.github/dependabot.yml`: weekly PRs for the app's and the collector's packages and the GitHub Actions (minor and patch grouped), each checked like any PR (no preview: Dependabot's PRs get no secrets). Replaces deprecated action versions too.*
## N.6 SonarQube Cloud (maybe later) ⬜
*One dashboard for coverage, duplication and code smells. Not now: the checks above already run free in `check.yml`, and Rafael found no free plan that fits; revisit if that changes.*

# Security and privacy (later) ⬜

*Not urgent while the app has one user, but to do before anyone else uses it or the data grows: make the repository private (old saved pages with phone numbers are in its git history); review what each table exposes to anonymous visitors (listings, places and dealer figures are public today; notes, checklists, homes, settings and searches are owner-only); encrypt the most personal data at rest (favourite notes, the viewing checklist, the home place) or keep it out of the database; rotate the secrets and the GitHub dispatch token on a schedule; consider Cloudflare Access in front of the site (see `docs/hosting.md`).*

# Next

1. Deal Score: the seller slice from the dealer figures (15.7) and the market-behaviour slice (time on market, price drops) once there is enough history; price trends per model (10.3, 15.8).
2. Saved ads from other sites: update the price or mark sold from their page (after #43).

**Open items for Rafael:** read the Standvirtual/OLX terms and record the clauses in `docs/sources.md`; check the new-bike reference prices; check the IUC table each January (`ownership_cost.dart`) and enter your insurance quote in "Custo de ter esta mota" → Alterar; make the repo private.

# Definition of Done

An interaction is finished only when:
- Code is implemented.
- The application compiles.
- The change has been tested.
- There are no known blockers.
- The change is isolated.
- The code is committed.
- The next interaction is clearly defined.

# First Milestone ✅

```text
Open Web App → Choose R7 2026 → See listings → Sort by Deal Score → Open listing → Understand why it is a good/bad deal
```

# Second Milestone ✅

```text
New listing → Collector → Database → Deal Score → Saved-search match → Alert
```

*Running on real Standvirtual and OLX data every 4 hours.*

# Third Milestone ✅

```text
Price changes → Price history → Deal Score recalculated → Dashboard updated → Alert if relevant
```

# Development Philosophy

```text
Small change → Working software → Verify → Commit → Next small change
```
