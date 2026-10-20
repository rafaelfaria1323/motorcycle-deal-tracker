# Motorcycle Deal Tracker — Concept & Architecture (status 2026-10-20)

**Legend:** ✅ done · 🟡 partly done · ⬜ not started · ➕ added along the way

Notes in *italics* describe what was actually built. Keep this file up to
date in the same PR as the work.

## 1. Concept ✅

A Web App/PWA that monitors the Portuguese used and semi-new motorcycle market, normalizes listings from different sources, tracks price/status history, and calculates an explainable Deal Score.

> “Is this motorcycle actually a good deal right now?”

*Answered for Standvirtual and OLX, with real data refreshed every 4 hours.*

## 2. Problem

Unchanged.

## 3. Objectives

- ✅ Monitor motorcycle listings.
- ✅ Detect new listings.
- ✅ Detect price reductions/increases. *Including cuts made before tracking (Standvirtual's price-drop note).*
- ✅ Detect listings that disappear. *Per search: only searches read in full remove listings.*
- ✅ Keep listing history.
- ✅ Estimate current market price. *Fair value per listing, adjusted with each model's own depreciation.*
- ✅ Compare used prices with new-bike prices. *Shown on the detail page; reference prices need setting for the newer models.*
- ✅ Calculate an explainable Deal Score.
- ✅ Calculate a separate Risk Score.
- ✅ Create saved searches. *Also by minimum Deal Score / maximum Risk Score.*
- ✅ Send alerts. *In the app and on the phone via Telegram, plus a weekly summary on Mondays.*
- ✅ Compare motorcycles. *Up to 3 listings side by side (long press in Ofertas or "Comparar" on a listing), best value per row highlighted.*
- 🟡 Show market trends. *Time on market, price drops, depreciation and the spread of live asking prices per model, and the tracked models compared side by side ("Comparar modelos"); price trends need more history.*

## 4. Motorcycle Models ✅

- Tracked: Yamaha MT-07, Yamaha R7, Honda CB650R, Honda CBR650R.
- ➕ Available in the app, off by default: Tracer 7, R1, R3, R9, CB125R, CB300R, CBR500R, CB750 Hornet, CBR600RR.

*The owner switches models on or off, changes each model's first year, and adds new models, all in the app ("Modelos acompanhados"). New models are picked from the brands and models the sites list (with Standvirtual's ad counts), with an optional engine size ("Forza" + 350 = only the Forza 350); the searches are built automatically, or typed by hand. The collector searches only the tracked models.*

## 5. Sources 🟡

- ✅ Standvirtual (search pages + listing pages for details, low-volume personal fetcher).
- ✅ OLX (search result pages, which hold the full description; Standvirtual copies skipped).
- ⬜ Future: CustoJusto, dealerships, European marketplaces, imports.

*robots.txt checked and read every run; same polite limits per site (20 requests per run, 120 per day). **Terms of use still to be read and recorded** in `docs/sources.md`.*

## 6. Platform

- Phase 1 — Flutter Web/PWA ✅ *Hosted on Cloudflare Pages, installed on the iPhone Home Screen; deployed on every merge. UI/UX redesign done (roadmap Sprint 13: Mais tab, Ofertas, listing page, Pesquisas/Alertas, its own look and fonts, one voice in pt-PT); single-user for now (Sprint 14 if someone else joins).*
- Phase 2 — Flutter iOS/Android ⬜ *Not needed for now: a native iPhone build requires a paid Apple Developer account.*

## 7. Stack

- Frontend: Flutter Web, Dart ✅
- Backend: Supabase, PostgreSQL ✅, Supabase Auth ✅ *(anonymous + owner email/password)*; scheduled jobs ➕ *on GitHub Actions instead of Edge Functions (a Dart CLI collector, one process per run, every 4 hours), started by Supabase pg_cron (GitHub's own scheduler never started them).*
- Hosting: Cloudflare Pages ✅
- Repository: GitHub ✅ *(should become private)*; ➕ automatic code-quality review by Claude after every 5 merged PRs
- Notifications: ➕ Telegram bot ✅ (alerts after each run, a message when the collection breaks, stops starting or recovers, weekly summary on Mondays); Web push / FCM ⬜

## 8. Architecture ✅

```text
Tracked models (catalog) → searches → Collectors / Adapters → Normalization → PostgreSQL / Supabase
   → Deal Engine · Price History · Status Tracking → Flutter Web/PWA → Alerts (app + Telegram)
```

*Each source has its own adapter + mapper (`manual`, `standvirtual`, `standvirtual-search`, `olx-search`); model matching (`ModelResolver`) and everything after normalization are shared.*

## 9. Listing Data Model ✅

All fields exist. ➕ Added: `initial_price`, `price_before_drop`, `duplicate_of`/`duplicate_score`, `score_breakdown`, `excellent_since`, `registrations`, `service_book`, `origin`, `warranty_until`, `dealer_warranty_months`, `published_at`, `details_checked_at`, `search_key`.

## 10. Listing Status ✅

`active`, `price_changed`, `removed` used; `sold` exists but can't be told apart from a withdrawal, so departures count as "left the market". Last check vs last confirmed sighting are tracked separately, and removal needs the listing's search to be read in full.

## 11. Price History ✅

Initial price, current price, every change with date, percentage, and time online are tracked and shown; the listing page charts the price over real time, with the site's earlier price when it reported one.

## 12. Deal Score 🟡

| Factor | Weight | Status |
|---|---:|---|
| Price vs market | 35% | ✅ fair value adjusted for age and mileage (per-model rates) |
| Year / mileage | 20% | ✅ |
| Version / equipment | 15% | ✅ extras named in the ad (no penalty when none); the version itself is not scored |
| Seller / confidence | 10% | ⬜ |
| Market / listing behaviour | 10% | ⬜ data being collected |
| Risk indicators | 10% | ✅ |

Labels (Excelente / Muito bom / Interessante / Normal / Fraco) ✅. Weights are parameters of one SQL function ✅.

## 13. Explainable Score ✅

*Each score lists: % and € versus the estimated value for that age and mileage, the estimated value itself, mileage, model year, risk signals, and reassuring facts (first owner, service book, factory warranty).*

## 14. Risk Score 🟡

- ✅ Price significantly below market.
- ✅ Suspicious mileage. *Under 100 km on a bike three or more years old (a placeholder), or more than 25 000 km a year.*
- 🟡 Inconsistent description. *Only "possible accident" keywords.*
- ✅ Missing information.
- ✅ Possible accident.
- 🟡 Duplicate listing. *Detected (across sources too) and excluded from scoring, not a risk signal.*
- 🟡 Suspicious seller behaviour. *Relisted ads are detected (the same bike taken down and listed again) and shown with the first date on sale and the earlier price; not a risk signal.*
- ✅ Unclear ownership/history. *3+ owners, no service book, imported.*
- ⬜ Excessively edited or reused images.

➕ Reassuring facts lower risk: first owner, service book, factory warranty.

## 15. Saved Searches ✅

All criteria (➕ plus minimum Deal Score and maximum Risk Score) and all four notification preferences, with edit, delete and "N ofertas". Created from Ofertas (current filters) or from Pesquisas ("Nova pesquisa").

## 16. Alerts ✅

All four types, each at most once per event, only for events after the search was created. Pushed to Telegram ✅ (confirmed on the phone). In the app: grouped by day, unread count on the Alertas tab.

## 17. Dashboard ✅

✅ Best deals sorted by Deal Score (or newest, cheapest, most expensive); only tracked models; filters for model, price, mileage, year, location, seller type, Deal Score, Risk Score, active only, shown as removable chips. ➕ Collection status (last run, duration, what it found, requests, next run; a warning card when a run failed or was blocked) in Mais.

## 18. Listing Detail Page ✅

✅ Photos (gallery, full screen), price, year, mileage, location, seller, seller type, source, original link, Deal Score, Risk Score, explanation, estimated value, price history, first/last seen, status, new-motorcycle comparison. ➕ Owners, service book, origin, warranty, publication date, full description, market behaviour card (with depreciation and where the asking price sits among the model's live listings), "also listed as" duplicates. *Sections ordered for a decision (score and risks first, history last); the button to the ad stays at the bottom of the screen.*

## 19. New Motorcycle Comparison 🟡

Shown on the detail page. Reference prices are edited in the app; set for the original 4 models (need checking), not set for the newer models.

## 20. Deduplication 🟡

✅ Within and across sources: mileage, price, location, description, seller. Original links preserved. OLX copies of Standvirtual ads skipped.
⬜ Images.

## 21. Data Quality 🟡

✅ Collection runs and blocks are tracked. ✅ Requests used per run, run duration, next run and monthly usage shown in the app (Mais). ✅ Per site in Mais: live listings, tracked/unmatched/duplicate shares, missing year, mileage and location, Standvirtual pages still to read, when listings were last seen on each site (warns after 24 h) and sudden price changes of 50 % or more in the last 30 days (view `source_data_quality`). ⬜ Per-field confidence.

## 22. Privacy 🟡

Private sellers' names and all phone numbers are never stored; saved pages and fetch state are no longer committed. ⬜ The repo is public and old saved pages with phone numbers remain in its git history: make it private.

## 23. Future Features ⬜

Comparison ✅ (listings side by side), buying assistant, checklists, cost calculators, price prediction, weekly ranking, smart alerts, model price history, imports, dealer integration. ➕ Depreciation tracking ✅ (per-model rates fitted from data).

## 24. Product Philosophy ✅

Simple, explainable, incremental, testable (Dart unit tests, mutation testing, and SQL tests on a real Postgres in CI), data-driven. The core idea is validated on real data from two sources.

## 25. Final Vision

> “What is the best motorcycle opportunity in the Portuguese market right now, considering my budget and criteria?”

*Answered for Standvirtual and OLX, for the models the owner chooses.*
