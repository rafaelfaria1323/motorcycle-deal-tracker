# App (Flutter Web/PWA)

The Motorcycle Deal Tracker app, in Portuguese (pt-PT). Published to
Cloudflare Pages on every merge that touches `app/`
(`.github/workflows/deploy-web.yml`: `flutter test`, then
`flutter build web`). The same deploy builds the Android app (`app/android`
is made there, not committed) and publishes it on the GitHub release
`android`; Mais › "App Android" offers it on Android phones, and in the
Android app says when a newer version is out and installs it (the in-repo
plugin `packages/apk_installer`; `docs/hosting.md`). The Android app gets
its notifications through Firebase Cloud Messaging (the in-repo plugin
`packages/android_push`); a tap opens the page in the app.

## Screens

- **Ofertas:** listings of your models (from your years), sorted by Deal Score (or
  newest, cheapest, most expensive, nearest), with filters shown as chips
  (including "Distância máxima" from your home and equipment: 19 kinds,
  e.g. quickshifter, escape, malas, proteções, suporte de matrícula curto,
  bolha) and paged 40 at a time.
  Each card shows the place and its distance from your home.
- **Favoritos:** the listings you starred (star on a listing's page; star
  in the Ofertas app bar or Mais opens the list), newest first, each with
  your private note and the problems found on the viewing checklist;
  removed ones stay, marked. A favourite always alerts
  you about price drops and its removal.
- **Comparar:** up to 3 listings side by side (long press a card in Ofertas,
  or "Comparar" on a listing's page), the best value of each row marked.
- **Listing page:** photo gallery; model, price and facts with the Deal
  Score and its verdict beside them; removed / duplicate / relisted notices;
  your note when it is a favourite. Below, four parts picked at the top
  (the last one picked stays open for the next listing):
  - **Avaliação:** why this score (the reasons and the risk), the same bike
    on the other site, "O stand" for dealers (what we have seen of its ads
    on both sites: relists, sharp price changes, missing mileage, repeated
    ads, price drops; from 5 bikes it also counts in the Deal Score, and
    the reasons say how the dealer scored).
  - **Negociar:** "Quanto oferecer" (where to start, a second offer if
    refused, the most to pay, each with a message to copy; "Argumentos" to
    quote to the seller; "O vendedor pediu": type the seller's counter-offer
    and it says whether to accept or what to propose, with the message to
    send; problems marked at the visit come off the offer; how keen the
    seller seems ("Pressa do vendedor"); for a dealer, what to ask for
    besides the price, with a message; for a
    favourite, "O seu preço": an alert when the ad drops to it), "Mensagem para o vendedor" (a first message with the
    questions the ad leaves open, optionally with the suggested offer; one
    tap copies it), "Para a visita" for favourites (12 points to check when
    seeing the bike, each "Está bem" or "Problema" with a note).
  - **Mercado:** market behaviour for the model (with where the asking
    price sits among the model's live listings), the price history, the
    comparison with a new one, "Custo de ter esta mota" (yearly cost:
    depreciation, IUC, your insurance, tyres, services, chain; "Alterar"
    sets your insurance, km per year and years to keep, saved to your
    account).
  - **Detalhes:** the bike's facts, the seller's description, the ad's
    facts.
- **Pesquisas:** saved searches, each with its "N ofertas" and alert
  preferences; "Nova pesquisa" creates one (Ofertas can also save its
  current filters).
- **Alertas:** new listings, price drops, excellent opportunities, bikes
  you followed back on the market in a new ad ("Voltou ao mercado") and
  removed listings, grouped by day; the tab shows the unread count.
- **Mais:** account, sharing (the app's link; admins: "Contas e convites"), "Notificações neste aparelho" (with "Enviar notificação de teste", an example of any alert or collection message, and "Enviar o resumo da semana"), "Resumo da semana" (your models' last 7 days, made every Monday and sent as a notification that opens it: counts, new listings per model, the best deals and the biggest drops, each opening its listing), "A sua localidade" (your home town: every listing
  shows its distance from it), "Modelos acompanhados" (your own models: switch on/off, first
  year, new-bike price, add models: brand and model picked from the sites'
  lists, optional engine size, searches built automatically; or typed by
  hand), "Comparar modelos" (your models side by side: typical asking
  price and its spread, the typical bike, time until leaving the market,
  price drops, depreciation; cheapest first), the collection status (last run, what it found, requests, next run; admins: "Estado da recolha" with the last runs and their errors, each site's requests today and pause, the GitHub token's expiry and the database's size against the free plan's 500 MB, "Recolher agora") and data quality
  per site (live listings, unmatched, duplicates, missing year/km/location,
  when listings were last seen, sudden price changes).

## Running it

```sh
cp env/dev.example.json env/dev.json   # SUPABASE_URL + SUPABASE_PUBLISHABLE_KEY
make app-run                           # from the repo root: Chrome
make app-check                         # analyze and test
make app-serve                         # release build on http://localhost:8080
```

Visitors get an anonymous session. Accounts come from invites: an admin
(Mais › Partilhar › "Contas e convites") creates a link and shares it, and
whoever opens it (`/#/join?code=…`) chooses an email and password; the
account is made at once (Supabase Auth's admin API, called by the
database). Admins also see the accounts, make other admins and remove
accounts. "Partilhar a app" sends the app's link to anyone.

## Code layout

```text
lib/app/        App widget, theme, router (go_router, one shell with 4 tabs; ads and their
                photos above it, pushed), DI (get_it)
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
