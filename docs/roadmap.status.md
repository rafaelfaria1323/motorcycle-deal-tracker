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
➕ 9.8 Choose the tracked models in the app; matching rules moved into the catalog; 9 more models added (off by default) ✅
➕ 9.9 Searches built from the tracked models; removal per search; first year editable and new models added from the app; request budget shown with a warning ✅
➕ 9.10 Collector performance: one Dart process per run (`bin/refresh.dart`) instead of seven; Standvirtual searches and listing pages share one fetcher (robots.txt read once, one 20-request budget); the pause between requests counts the time already spent since the previous one; duplicates, scores, alerts and notifications run once per run instead of three times ✅

# Sprint 10 — Market Intelligence 🟡

## 10.1 Market price distribution ⬜
## 10.2 Model comparison ⬜
## 10.3 Price trends ⬜
*Needs a few weeks of price history first.*
## 10.4 Time-to-sale estimation 🟡
*"Mercado deste modelo" on the detail page: typical time until a listing leaves the market, share and size of price drops, depreciation rates, and how long this listing has been up. Shows "ainda poucos dados" until enough history exists.*
## 10.5 Deal ranking ✅
*The dashboard sorted by Deal Score is the ranking.*

➕ Fair value per listing adjusted for age and mileage ✅ (see 4.1, 4.3)

# Sprint 11 — Quality 🟡

## 11.1 Unit tests 🟡
*App: alerts, saved searches, score explainer, risk reasons, market behaviour, collector status, new-price text, catalog and tracked-models text. Collector (121 tests): adapters, mappers, model resolver (real OLX titles), search plan, removal plan, normalizers, store, fetcher, robots.txt, run status. SQL is verified on a local Postgres with all migrations, not with automated tests.*
## 11.2 Integration tests ⬜
## 11.3 Logging 🟡
*Every scheduled run is recorded in `collector_runs` with a log tail; Actions keeps the full log for 7 days.*
## 11.4 Error handling 🟡
*Fetcher stops and pauses on blocks; incomplete searches never trigger removals; the dashboard shows when the last run failed, was blocked or is too old.*
## 11.5 Data-quality monitoring 🟡
*Collector failures and blocks are tracked. Requests used per run, missing fields, duplicate rates, unexpected price changes and source availability are not shown yet.*

➕ **Notifications on the phone via Telegram** ✅ (11.1; replaces Web/PWA push). 11.1b: "Test Telegram" workflow / `make notify-test` sends a test message. Confirmed on Rafael's phone (2026-10-19) after `TELEGRAM_CHAT_ID` was corrected (it held the bot's own id).
➕ **Housekeeping** 🟡: saved pages and fetch state are no longer tracked ✅; **the repo should be made private** (old saved pages with phone numbers remain in git history) ⬜.

# Sprint 13 — UI/UX redesign ⬜

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
## 13.2 A "Mais"/settings tab 🟡
*Fourth tab "Mais" with the account (sign in/out), Modelos acompanhados and the collection status; the profile icon left Pesquisas and the models link left the account sheet. Still to add: Telegram status and the requests used per run.*
## 13.3 Ofertas ⬜
*Only tracked models by default; visible sort selector; active filters as chips that can be removed one by one.*
## 13.4 Listing page ⬜
*Photo gallery; sections ordered by what matters for a decision (price and score first, then risk, market, history).*
## 13.5 Pesquisas and Alertas ⬜
*Create a search from Pesquisas; unread badge on Alertas; alerts grouped by day.*
## 13.6 One voice and polish ⬜
*One form of address in all pt-PT text; consistent empty/loading/error states; light/dark and iPhone safe-area check.*

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

# Next

1. UI/UX redesign (Sprint 13), starting with the audit (13.1).
2. Show the requests used by the last run per site (and searches cut short) in the app, so the budget warning is based on real numbers (fits in 13.2).
3. Deal Score: add the market-behaviour slice (time on market, price drops) once there is enough history.
4. Price history chart on the detail page.
5. Weekly Telegram summary (best deals, new drops, listings gone).

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
