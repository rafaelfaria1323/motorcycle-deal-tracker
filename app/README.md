# App (Flutter Web/PWA)

The Motorcycle Deal Tracker app, in Portuguese (pt-PT). Published to
Cloudflare Pages on every merge that touches `app/`
(`.github/workflows/deploy-web.yml`: `flutter test`, then
`flutter build web`).

## Screens

- **Ofertas:** listings of the tracked models, sorted by Deal Score (or
  newest, cheapest, most expensive, nearest), with filters shown as chips
  (including "Distância máxima" from your home and equipment: quickshifter,
  escape, malas, punhos aquecidos, proteções, pneus novos) and paged 40 at
  a time.
  Each card shows the place and its distance from your home.
- **Favoritos:** the listings you starred (star on a listing's page; star
  in the Ofertas app bar or Mais opens the list), newest first, each with
  your private note and the problems found on the viewing checklist;
  removed ones stay, marked. A favourite always alerts
  you about price drops and its removal.
- **Comparar:** up to 3 listings side by side (long press a card in Ofertas,
  or "Comparar" on a listing's page), the best value of each row marked.
- **Listing page:** photo gallery, price, your note and the viewing
  checklist when it is a favourite ("As suas notas", "Para a visita": 12
  points to check when seeing the bike, each "Está bem" or "Problema" with
  a note), score with the reasons behind it, "Quanto oferecer"
  (where to start and the most to pay, with the reasons), risks, the same bike on the other site, the comparison with a new one,
  "Mensagem para o vendedor" (a first message with the questions the ad
  leaves open, optionally with the suggested offer; one tap copies it),
  "O stand" for dealers (what we have seen of its ads on both sites:
  relists, sharp price changes, missing mileage, repeated ads, price drops),
  "Custo de ter esta mota" (yearly cost: depreciation, IUC, your insurance,
  tyres, services, chain; "Alterar" sets your insurance, km per year and
  years to keep, saved to your account),
  market behaviour for the model (with where the asking price sits among
  the model's live listings) and the price history.
- **Pesquisas:** saved searches, each with its "N ofertas" and alert
  preferences; "Nova pesquisa" creates one (Ofertas can also save its
  current filters).
- **Alertas:** new listings, price drops, excellent opportunities and
  removed listings, grouped by day; the tab shows the unread count.
- **Mais:** account, "A sua localidade" (your home town: every listing
  shows its distance from it), "Modelos acompanhados" (switch models on/off, first
  year, new-bike price, add models: brand and model picked from the sites'
  lists, optional engine size, searches built automatically; or typed by
  hand), "Comparar modelos" (the tracked models side by side: typical asking
  price and its spread, the typical bike, time until leaving the market,
  price drops, depreciation; cheapest first), the collection status (last run, what it found, requests, next run) and data quality
  per site (live listings, unmatched, duplicates, missing year/km/location,
  when listings were last seen, sudden price changes).

## Running it

```sh
cp env/dev.example.json env/dev.json   # SUPABASE_URL + SUPABASE_PUBLISHABLE_KEY
make app-run                           # from the repo root: Chrome
make app-check                         # analyze and test
make app-serve                         # release build on http://localhost:8080
```

Visitors get an anonymous session; the owner signs in with email and
password (created by hand in Supabase) to change the catalog.

## Code layout

```text
lib/app/        App widget, theme, router (go_router, one shell with 4 tabs), DI (get_it)
lib/core/       Formatting, shared widgets
lib/features/   listings, collector_status, settings
  <feature>/domain/        entities, repository interfaces
  <feature>/data/          models (fromJson), Supabase repositories
  <feature>/presentation/  cubits, pages, widgets, *_text.dart (text built from data)
test/           unit tests, mostly for the cubits and *_text.dart functions
```

The look lives in `lib/app/theme/`: `AppTheme` (light and dark colour
schemes, component styles) and `AppColors` (good/bad and Deal Score
colours). Fonts are bundled in `assets/fonts`: Barlow for text and Barlow
Semi Condensed for titles, prices and scores (SIL Open Font License).

State uses Cubits (flutter_bloc) with Equatable states. Photos use
`Image.network` with `WebHtmlElementStrategy.prefer`, because the photo
sites send no CORS headers.
