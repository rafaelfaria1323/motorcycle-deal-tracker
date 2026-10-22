# Motorcycle Deal Tracker — Concept & Architecture (status 2026-10-22)

**Legend:** ✅ done · 🟡 partly done · ⬜ not started · ➕ added along the way

Notes in *italics* describe what was actually built. Keep this file up to
date in the same PR as the work.

## 1. Concept ✅

A Web App/PWA that monitors the Portuguese used and semi-new motorcycle market, normalizes listings from different sources, tracks price/status history, and calculates an explainable Deal Score.

> “Is this motorcycle actually a good deal right now?”

*Answered for Standvirtual and OLX, with real data refreshed 7 times a day (every 2 hours in the afternoon).*

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
- ✅ Send alerts. *In the app and as notifications on each account's phone (Web Push; FCM in the Android app), plus each account's weekly summary on Mondays (a notification that opens "Resumo da semana" in the app). An alert whose push fails is tried again on the next runs (for a day); signing out stops a device's notifications. Only events of the last day alert (following a model doesn't bring old news), and a listing that goes, comes back and goes again alerts each time.*
- ✅ Compare motorcycles. *Up to 3 listings side by side (long press in Ofertas or "Comparar" on a listing), best value per row highlighted.*
- 🟡 Show market trends. *Time on market, price drops, depreciation and the spread of live asking prices per model, and the tracked models compared side by side ("Comparar modelos"); price trends need more history.*

## 4. Motorcycle Models ✅

- Tracked: Yamaha MT-07, Yamaha R7, Honda CB650R, Honda CBR650R.
- ➕ Available in the app, off by default: Tracer 7, R1, R3, R9, CB125R, CB300R, CBR500R, CB750 Hornet, CBR600RR.

*Each account switches its own models on or off, changes each model's first year, and adds new models, all in the app ("Modelos acompanhados"); the collection searches every model any account follows, so all accounts share the listings. New models are picked from the brands and models the sites list (with Standvirtual's ad counts), with an optional engine size ("Forza" + 350 = only the Forza 350); the searches are built automatically, or typed by hand. The collector searches only the models someone follows.*

## 5. Sources 🟡

- ✅ Standvirtual (every page of each search, from the first tracked year, + listing pages for details, low-volume personal fetcher).
- ✅ OLX (search result pages, which hold the full description; Standvirtual copies skipped; each search asks for the engine-size band of its models, so other models' ads aren't read).
- ⬜ Future: CustoJusto, dealerships, European marketplaces, imports.

*robots.txt checked, read once a day and kept up to 24 h (roadmap R.4); same polite rules per site (6-10 s apart, one at a time, 24 h pause on a refusal); no request caps since 2026-10-22, at most 30 min per site and run, the requests shown per run, day and month. Fewer requests planned (roadmap R): pages per search recorded first, then light runs that read each search newest first and stop at ads already seen, with full runs a few times a day. **Terms of use still to be read and recorded** in `docs/sources.md`.*

## 6. Platform

- Phase 1 — Flutter Web/PWA ✅ *Hosted on Cloudflare Pages, installed on the iPhone Home Screen; deployed on every merge, with the migrations the database is missing applied first (Security S.3). UI/UX redesign done (roadmap Sprint 13: Mais tab, Ofertas, listing page, Pesquisas/Alertas, its own look and fonts, one voice in pt-PT); models per account (Sprint 14); accounts from invite links made in the app (14.3), Telegram only for admins' alerts; admins can start a collection from Mais (14.5), any account its own weekly summary (14.4d) and see each run's errors, the sites' requests and pauses and the GitHub token's expiry in "Estado da recolha" (14.6; checked from the app since 14.6b, with the database's size too). Start speed: each PR's preview is measured by Lighthouse, which now shows what the download is made of (roadmap N.13); the first load no longer fetches fonts from Google (N.14), and asks for the first listings while it signs in, with its connections opened early (N.15); a loading screen shows while the app downloads (N.16), and the first listings and photos are asked for during the download (N.17); the fonts are smaller (N.18).*
- Phase 2 — Flutter iOS/Android 🟡 *Android ✅: every deploy builds a signed APK and replaces it on the GitHub release `android`; Mais offers it on Android phones, and the app updates itself from there (it says when a newer build is out, downloads it and opens Android's installer; roadmap 12.5). Notifications too, through Firebase Cloud Messaging (roadmap 12.6), a tap opening the page in the app. Android's back gesture and the browser's back/forward follow the screens the person went through (roadmap 12.7). iPhone: not needed, a native build requires a paid Apple Developer account.*

## 7. Stack

- Frontend: Flutter Web, Dart ✅
- Backend: Supabase, PostgreSQL ✅, Supabase Auth ✅ *(anonymous + owner email/password)*; scheduled jobs ➕ *on GitHub Actions instead of Edge Functions (a Dart CLI collector, one process per run, 7 times a day at fixed Lisbon hours), started by Supabase pg_cron (GitHub's own scheduler never started them).*
- Hosting: Cloudflare Pages ✅
- Repository: GitHub ✅ *(stays public, Rafael 2026-10-21: free Actions minutes for the whole pipeline)*; ➕ automatic code-quality review by Claude after every 5 merged PRs
- Notifications: Web push ✅ *(each account's alerts on its devices (in the Android app through Firebase Cloud Messaging), the admins' when the collection breaks or recovers, sent by the collector itself; a tap opens the listing in the app; "Enviar notificação de teste" in Mais checks a device with an example of any notification; stays on after the app is closed; the weekly summary on Mondays, kept in the app's "Resumo da semana")*; ➕ Telegram bot ✅ (alerts until 2026-10-21, the weekly summary until 14.4d; now only the database's warnings when no run starts or the GitHub token is ending)

## 8. Architecture ✅

```text
Tracked models (catalog) → searches → Collectors / Adapters → Normalization → PostgreSQL / Supabase
   → Deal Engine · Price History · Status Tracking → Flutter Web/PWA → Alerts (app + Web Push / FCM)
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
| Price vs market | 35% | ✅ fair value adjusted for age and mileage (per-model rates, comparables within 3 years when enough), from 3 comparables; without it the score is at most 70 (15.18) |
| Year / mileage | 20% | ✅ |
| Version / equipment | 15% | 🔄 a bonus instead (15.18): +2 points per extra named in the ad, at most +10 (as a weighted slice it lowered good scores); the version itself is not scored |
| Seller / confidence | 10% | ✅ dealers with 5+ bikes, from their ads' warning signs (15.7); private sellers and small dealers skip the slice |
| Market / listing behaviour | 10% | ⬜ data being collected |
| Risk indicators | 10% | ✅ |

Labels (Excelente / Muito bom / Interessante / Normal / Fraco) ✅. Weights are parameters of one SQL function ✅.

## 13. Explainable Score ✅

*Each score lists: % and € versus the estimated value for that age and mileage, the estimated value itself, mileage, model year, risk signals, and reassuring facts (first owner, service book, factory warranty).*

## 14. Risk Score 🟡

- ✅ Price significantly below market.
- ✅ Suspicious mileage. *Under 100 km on a bike three or more years old (a placeholder), or more than 25 000 km a year.*
- ➕ ✅ The text contradicts the ad (15.6). *The year, mileage, origin or service book written in the description against the ad's fields; only clear cases (two or more years apart, more km in the text, "importada" on a national ad, "sem livro" with a service book).*
- 🟡 Inconsistent description. *Only "possible accident" keywords; contradictions between text and fields planned (15.6).*
- ✅ Missing information.
- ✅ Possible accident.
- 🟡 Duplicate listing. *Detected (across sources too) and excluded from scoring, not a risk signal.*
- ✅ Suspicious seller behaviour. *Relisted ads are detected (the same bike taken down and listed again), shown with the first date on sale and the earlier price, and count as risk (15.5): 5 points, 10 when relisted twice or on sale for over 90 days counting the earlier ads. Each dealer's figures (relisted, sharp price changes, missing mileage, repeated ads, price drops) are shown on its listings (15.7) and score the Deal Score's seller slice.*
- ✅ Unclear ownership/history. *3+ owners, no service book, imported.*
- ⬜ Excessively edited or reused images.

➕ Reassuring facts lower risk: first owner, service book, factory warranty.

## 15. Saved Searches ✅

All criteria (➕ plus minimum Deal Score and maximum Risk Score) and all four notification preferences, with edit, delete and "N ofertas". Created from Ofertas (current filters) or from Pesquisas ("Nova pesquisa").

## 16. Alerts ✅

All four types, each at most once per event, only for events after the search was created. ➕ Favourites alert their owner about price drops and removal without a saved search (once per event, also when a search covers the listing). ➕ "Chegou ao seu preço": a favourite's target price reached (15.19). Pushed to Telegram ✅ (confirmed on the phone). In the app: grouped by day, unread count on the Alertas tab.

## 17. Dashboard ✅

✅ Best deals sorted by Deal Score (or newest, cheapest, most expensive); only tracked models; filters for model, price, mileage, year, location, seller type, Deal Score, Risk Score, active only, shown as removable chips. ➕ Distance from the owner's home on every listing, a maximum-distance filter (also for saved searches) and a nearest-first sort (15.11). ➕ Equipment filter (quickshifter, exhaust, luggage, heated grips, protection, new tyres and, since 15.15, short plate holder, screen, levers, mirrors, phone mount, alarm, steering damper, centre stand, cruise control, suspension, LED indicators, passenger grab handles, original parts included), also for saved searches (15.13). ➕ Collection status (last run, duration, what it found, requests, next run; a warning card when a run failed or was blocked) in Mais. ➕ Favourites: a star on cards of starred listings; "Favoritos" (Ofertas app bar or Mais) lists them with the owner's notes.

## 18. Listing Detail Page ✅

✅ Photos (gallery, full screen; every photo of the ad, up to 30, 14.4h), price, year, mileage (read from the description when the ad's field is empty, 14.4i), location, seller, seller type, source, original link, Deal Score, Risk Score, explanation, estimated value, price history, first/last seen, status, new-motorcycle comparison. ➕ Owners, service book, origin, warranty, publication date, full description, market behaviour card (with depreciation and where the asking price sits among the model's live listings), "also listed as" duplicates. *The Deal Score and its verdict sit beside the price; below, four parts picked at the top (Avaliação, Negociar, Mercado, Detalhes, 15.17) instead of one long list of cards; the button to the ad stays at the bottom of the screen.*

## 19. New Motorcycle Comparison 🟡

Shown on the detail page. Reference prices are edited in the app; set for the original 4 models (need checking), not set for the newer models.

## 20. Deduplication 🟡

✅ Within and across sources: mileage, price, location, description, seller. Original links preserved. OLX copies of Standvirtual ads skipped.
⬜ Images.

## 21. Data Quality 🟡

✅ Collection runs and blocks are tracked. ✅ Requests used per run, run duration, next run and monthly usage shown in the app (Mais). ✅ Per site in Mais: live listings, tracked/unmatched/duplicate shares, missing year, mileage and location, Standvirtual pages still to read, when listings were last seen on each site (warns after 24 h) and sudden price changes of 50 % or more in the last 30 days (view `source_data_quality`). ⬜ Per-field confidence. ✅ Each run's log says, per search, how many of the ads it read are a followed model (9.10c), so searches that spend requests on other bikes show up; unmatched ads are logged with their brand and model. ✅ Near the free plan's limit (400 of 500 MB), old gone listings of models nobody follows are deleted (9.10d).

## 22. Privacy 🟡

Private sellers' names and all phone numbers are never stored; saved pages and fetch state are no longer committed. The repo stays public (Rafael, 2026-10-21: the free pipeline is worth more); old saved pages with phone numbers remain in its git history. The API roles may write only where the app does, and the site sends security headers (roadmap S.1); anonymous users idle for 30 days are deleted (S.2); personal data is owner-only by row level security and encrypted at rest by Supabase. How to replace each secret, and when, is written down in `docs/hosting.md` (roadmap S.4). The Android app keeps its session encrypted with a Keystore key and its data out of backups (S.5).

## 23. Future Features ⬜

Comparison ✅ (listings side by side), buying assistant, checklists, cost calculators, price prediction, weekly ranking ✅ (the weekly summary's best deals, 14.4d), smart alerts, model price history, imports, dealer integration. ➕ Depreciation tracking ✅ (per-model rates fitted from data).

Planned in roadmap Sprint 15 ("Deciding and buying"): ➕ favourites with private notes ✅ (15.1; a favourite always alerts on price drops and removal), price to offer (buying assistant, 15.2) ✅, ➕ negotiation arguments, visit repairs off the offer, messages per step and a target price alert (15.19) ✅, ➕ "back on the market" alert for followed bikes (15.14) ✅, ➕ message to the seller (15.12) ✅, viewing checklist (15.3) ✅, cost of ownership (cost calculator, 15.4) ✅, relists as a risk signal (15.5) ✅, text contradictions as risk signals (15.6) ✅, dealer reliability (15.7) ✅ (figures shown and scored), price trends (model price history, 15.8) ⬜, more sources and imports (15.9) ⬜, web push (15.10) ✅.

➕ Paid plans ⬜: planned in roadmap Sprint 16 and `docs/paid-plans.md`. The plan covers free and paid features, a purchase pass, one-ad reports, seller valuation, an import calculator, affiliate links and a stand plan. On hold: Rafael decided (2026-10-22) to charge only if the sites give us their data through an API or a licence (the collection is personal and non-commercial today); until then the app stays free for invited accounts. The business, legal pages and infrastructure decisions come only then.

## 24. Product Philosophy ✅

Simple, explainable, incremental, testable (Dart unit tests, mutation testing, and SQL tests on a real Postgres in CI), data-driven. The core idea is validated on real data from two sources.

## 25. Final Vision

> “What is the best motorcycle opportunity in the Portuguese market right now, considering my budget and criteria?”

*Answered for Standvirtual and OLX, for the models the owner chooses.*
