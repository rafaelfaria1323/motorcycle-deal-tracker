# Motorcycle Deal Tracker — Small Interaction Roadmap (status 2026-10-19)

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
*Price 35, year/mileage 20, risk 10 are live. Version/equipment 15, seller/confidence 10 and market behaviour 10 are not scored yet; the score renormalizes over the slices that have data.*
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
➕ 9.6 Scheduled collection on GitHub Actions, every 4 hours, 120 requests per day per site, with run log ✅
➕ 9.6b Collection status banner on the dashboard ✅
## 9.7 OLX adapter ✅
*Search result pages only (they hold the full description), every page of each search, 2023+ year filter. Standvirtual copies skipped. Fixes in 9.7b (multi-page searches, ads without a price, R7 titles) and 9.7c ("CBR 650" = CBR650R).*
➕ 9.8 Choose the tracked models in the app; matching rules moved into the catalog; 9 more models added (off by default) ✅. Fix: switching a model back on left its old listings unmatched (the collector never rematches stored listings); now switching on gives them back by the catalog brand and model names they were stored with, removed ones included, and the migration restored the listings of models already back on.
➕ 9.9 Searches built from the tracked models; removal per search; first year editable and new models added from the app; request budget shown with a warning ✅
➕ 9.7d OLX publication and renewal dates: `createdTime` is stored as `published_at` (it was missing, so the app fell back to the day we first saw the ad) and `lastRefreshTime` as `site_refreshed_at`; the listing page shows "Publicado" with the date and "Renovado no site" when the seller renewed the ad later (OLX shows the renewal date) ✅
➕ 9.10 Collector performance: one Dart process per run (`bin/refresh.dart`) instead of seven; Standvirtual searches and listing pages share one fetcher (robots.txt read once, one 20-request budget); the pause between requests counts the time already spent since the previous one; duplicates, scores, alerts and notifications run once per run instead of three times ✅

# Sprint 10 — Market Intelligence 🟡

## 10.1 Market price distribution ⬜
## 10.2 Model comparison ⬜
## 10.3 Price trends ⬜
*Needs a few weeks of price history first.*
## 10.4 Time-to-sale estimation 🟡
*"Mercado deste modelo" on the detail page: typical time until a listing leaves the market, share and size of price drops, depreciation rates, and how long this listing has been up (from the site's publication date; without one it says "Visto pela primeira vez há…", counted from the day the collector first saw it, never "publicado"). Shows "ainda poucos dados" until enough history exists.*
## 10.5 Deal ranking ✅
*The dashboard sorted by Deal Score is the ranking.*

➕ Fair value per listing adjusted for age and mileage ✅ (see 4.1, 4.3)

# Sprint 11 — Quality 🟡

## 11.1 Unit tests 🟡
*App: alerts, saved searches, score explainer, risk reasons, market behaviour, collector status, new-price text, catalog and tracked-models text. Collector (132 tests): adapters, mappers, model resolver (real OLX titles), search plan, removal plan, normalizers, store, fetcher, robots.txt, run status. SQL is verified on a local Postgres with all migrations, not with automated tests.*
## 11.2 Integration tests ⬜
## 11.3 Logging 🟡
*Every scheduled run is recorded in `collector_runs` with a log tail; Actions keeps the full log for 7 days.*
## 11.4 Error handling 🟡
*Fetcher stops and pauses on blocks; incomplete searches never trigger removals; the dashboard shows when the last run failed, was blocked or is too old.*
## 11.5 Data-quality monitoring 🟡
*Collector failures and blocks are tracked; requests used per site and run, run duration and monthly runs are shown in Mais. "Qualidade dos dados" in Mais (view `source_data_quality`): per site, live listings, how many are tracked models, unmatched or duplicates, the share of scored listings missing year, mileage or location, and Standvirtual listing pages still to read. Unexpected price changes and source availability are not shown yet.*

➕ **Notifications on the phone via Telegram** ✅ (11.1; replaces Web/PWA push). 11.1b: "Test Telegram" workflow / `make notify-test` sends a test message. Confirmed on Rafael's phone (2026-10-19) after `TELEGRAM_CHAT_ID` was corrected (it held the bot's own id).
➕ **Weekly Telegram summary** ✅ (11.1c): every Monday (`weekly-summary.yml`, 07:52 UTC, or "Run workflow") one message about the tracked models' last 7 days: new listings per model, price drops of 1 % or more (biggest 3 shown), listings gone, live count, and the 5 best live deals with risk below 50, each with its link. Reads the database only; `make weekly-summary ARGS=--dry-run` prints it.
➕ **Housekeeping** 🟡: saved pages and fetch state are no longer tracked ✅; **the repo should be made private** (old saved pages with phone numbers remain in git history) ⬜.

➕ **Compare listings** ✅ (13.7): long press a card in Ofertas (or "Comparar" on a listing's page) to pick up to 3; "Comparar (n)" opens them side by side (`/compare?ids=…`, so a reload keeps them): photo and title per column, then price, Deal Score, Risk Score, difference to the market value, year, km, price drop, owners, service book, location, seller, source and first seen, the best value of each row highlighted. Table logic in `compare_text.dart`, tested.

➕ **Scheduled collection never started** 🟡 (9.6c): GitHub never ran `collect.yml` on its schedule (no scheduled run at all since 2026-10-19 morning; the five runs were all manual), though the workflow is on `main`, active, valid and the repo public. Test: the cron is temporarily every hour (`40 * * * *`, app's next-run text in step) and the file re-registered by this change; back to every 4 hours once a scheduled run appears. If none does, the fallback is Supabase `pg_cron` calling GitHub's workflow_dispatch API with a repo-only token.

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
*`.github/workflows/code-quality.yml`: after every 5 merged PRs (or "Run workflow"), Claude Code reviews the code on GitHub Actions, with Flutter installed so `make check` really runs, and opens at most one small PR labelled `code-quality` (none if nothing is worth changing). It works from a backlog, `docs/code-quality.md`: up to 3 items per run; when the list is empty it reviews the code, writes up to 10 new items and does the first 3. The PR is pushed with the job's own token (the Claude step revokes its token when it ends; the first run failed on that). The tag `code-quality-reviewed` marks the last review; no review starts while one is open. Runs on Rafael's Claude plan through the `CLAUDE_CODE_OAUTH_TOKEN` secret.*

# Next

1. Deal Score: add the market-behaviour slice (time on market, price drops) once there is enough history.
2. Price trends per model (10.3): median asking price per model by week, once a few weeks of history exist.
3. Saved ads from other sites: update the price or mark sold from their page (after #43).

**Open items for Rafael:** read the Standvirtual/OLX terms and record the clauses in `docs/sources.md`; check the new-bike reference prices; make the repo private.

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
