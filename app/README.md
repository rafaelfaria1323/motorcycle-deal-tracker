# App (Flutter Web/PWA)

The Motorcycle Deal Tracker app, in Portuguese (pt-PT) and English (en-GB).
Published to Cloudflare Pages on every merge that touches `app/`
(`.github/workflows/deploy-web.yml`: `flutter build web` beside
`flutter test`, published only when the tests pass). The same deploy builds the Android app (`app/android`
is made there, not committed) and publishes it on the GitHub release
`android`; Mais › "App Android" offers it on Android phones, and in the
Android app says when a newer version is out and installs it (the in-repo
plugin `packages/apk_installer`; `docs/hosting.md`). The Android app gets
its notifications through Firebase Cloud Messaging (the in-repo plugin
`packages/android_push`); a tap opens the page in the app. It keeps the
sign-in encrypted with a key in the Android Keystore
(`flutter_secure_storage`) and leaves its data out of Android's backups.

## Languages

Portuguese remains the default. Mais › "Idioma" / More › "Language" changes
the interface immediately without resetting navigation, filters or notes.
Signed-in accounts save their choice in `account_languages` for their other
devices, notifications and weekly summaries; visitors save it on this device
only. Startup restores the cached choice. Changing accounts restores that
account's own preference (Portuguese when unset), never another account's;
signing out keeps the device choice. Loading and saving failures are shown
with a retry rather than silently treating a failed request as an unset choice.

Currency stays in euros and distances in kilometres. Display and numeric
input use the selected language's separators. Seller descriptions, account
names, saved-search names, notes, model/place names and technical diagnostics
remain in their original language.

Bundled messages live in `lib/l10n/app_pt.arb` and `app_en.arb`, with typed
placeholders and ICU plurals. `flutter gen-l10n` generates the ignored
`lib/l10n/generated/` files; Flutter also generates them during dependency
resolution/builds. Edit both catalogs, not generated Dart. Widgets use
`context.strings` / `context.language`; pure text helpers and formatters take
an explicit `AppLanguage`. Do not cache translated errors in state or change
the global Intl locale. The collector has its own pure-Dart notification
catalog; no translation API or runtime AI is used.

The account-language migration is applied on merge before deployment.
PR previews use the existing database without applying new migrations:
local visitor switching works there, but account persistence needs the
migration; an unavailable table is reported as a preference load/save error.

## Screens

Screen names below use the Portuguese labels; English provides the same screens.

- **Ofertas:** listings of your models (from your years), sorted by Deal Score (or
  newest, cheapest, most expensive, nearest), with filters shown as chips
  (including several models at once, picked by brand, e.g. two of the
  Hondas; "Distância máxima" from your home and equipment: 19 kinds,
  e.g. quickshifter, escape, malas, proteções, suporte de matrícula curto,
  bolha, and "Só nas suas cores": each model's favourite colours; with
  "Mais barato" that is the best price in your colour) and paged 40 at a
  time. Labelled filter, sort and save controls sit above the results;
  while more pages remain, the count explicitly describes loaded ads.
  The count and "Compare até 3 anúncios" share a text baseline, wrapping
  on narrow screens and respecting enlarged text.
  By default, photo-led cards show the source, Deal Score, price change,
  year, mileage, place and distance from your home, and preferred-colour
  indicator, with a visible "Comparar" action. "Cartões" lets each signed-in
  account show or hide these details, or add Risk Score, seller type,
  colour, owners / first owner, service book, origin, factory and seller
  warranties, the stand's name, status, and publication, renewal and
  first-found dates. Publication is the site's date, never our discovery
  date; first-owner information also uses the ad's existing risk signal
  when no owner count is known. Missing facts are omitted. Choices apply to
  Ofertas and Favoritos, are saved across devices, and can be reset to the
  defaults. Photo, model, price, removal notices, favourite star and
  comparison actions stay visible; the listing page, filters, scores and
  alerts are unchanged.
  The grid grows to three columns; phone and enlarged-text layouts use
  naturally sized cards.
- **Favoritos:** the listings you starred (star on a listing's page; star
  in the Ofertas app bar or Mais opens the list), newest first, each with
  your private note and the problems found on the viewing checklist;
  removed ones stay, marked. A favourite always alerts
  you about price drops and its removal.
- **Comparar:** up to 3 listings side by side ("Comparar" on a card in
  Ofertas, long press the card, or "Comparar" on a listing's page), the best
  value of each row marked.
- **Listing page:** photo gallery (full screen on a tap; there pinch, the
  mouse wheel or a double tap zooms; admins also mark each of the first 3
  photos "Problema" or "Bem", which the collector learns from, P.3); in
  Avaliação, what the photos may show and "Examinar todas as fotos" (every
  photo at the next collection, P.4; 5 a day); model, price and facts with the Deal
  Score and its verdict beside them; removed / duplicate / relisted notices;
  your note when it is a favourite. Photos and summary sit side by side
  on wide screens and stack on phones, with a visible fullscreen control.
  The original-listing button stays at the bottom, with the price beside
  it on wide screens. Below, four parts picked using scrollable tabs
  (the last one picked stays open for the next listing):
  - **Avaliação:** why this score (the reasons and the risk), the same bike
    on the other site, "O stand" for dealers (what we have seen of its ads
    on both sites: relists, sharp price changes, missing mileage, repeated
    ads, price drops; from 5 bikes it also counts in the Deal Score, and
    the reasons say how the dealer scored), and "O que as fotos podem
    mostrar": a free image model's hints of damage in the photos, and
    "Parecida com fotos marcadas como problema" once the admins' marks
    trained a classifier (a tap opens the photo; never part of a score).
  - **Detalhes:** the bike's facts, the seller's description, the ad's
    facts.
  - **Mercado:** market behaviour for the model (with where the asking
    price sits among the model's live listings, and about how many days
    this ad has left on the market, from the model's ads at a similar
    price), the price history, the
    comparison with a new one, "E se a comprar no estrangeiro?" (the
    same bike's price in Spain, France or Germany, the engine size
    filled in, plus ISV, legalisation and transport, against this ad's
    price), "Custo de ter esta mota" (yearly cost:
    depreciation, IUC, your insurance, tyres, services, chain; "Alterar"
    sets your insurance, km per year and years to keep, saved to your
    account).
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
- **Pesquisas:** saved searches, each with its criteria, configured alert
  types and "N anúncios encontrados". Tap the card to apply it; the
  options menu edits or deletes it; swipe right to edit, left to confirm
  deletion. "Nova pesquisa" creates one (Ofertas
  can also save its current filters; filters already saved read "Pesquisa
  guardada", and the same search is never saved twice).
- **Alertas:** new listings, price drops, excellent opportunities, bikes
  you followed back on the market in a new ad ("Voltou ao mercado") and
  removed listings, grouped by day, with an unread summary above them;
  the tab also shows the unread count. Swipe left to confirm deletion, or
  right to edit the saved search that created the alert; the same actions
  are in its options menu. Without a source search, only deletion is
  available. Deleted alerts leave the list and unread count but retain
  their database history, so the same event cannot be generated again;
  pending notifications are marked handled without a push, and the
  listing's later removal or return no longer alerts because of them.
- **Mais:** in sections (Conta, Pessoal, Ferramentas, Notificações, A app, Recolha de dados; "Administração" for admins only: "Contas e convites", "Estado da recolha", "Recolher agora"): account, "Idioma", "Cartões dos anúncios" (the same card display choices as Ofertas), "Partilhar a app" (the app's link), "Notificações neste aparelho" (with "Horas de silêncio": the hours, Portugal time, when alerts wait for the next collection, 23:00 to 08:00 unless changed, for all the account's devices; "Enviar notificação de teste", an example of any alert or collection message, and "Enviar o resumo da semana"), "Resumo da semana" (your models' last 7 days, made every Monday and sent as a notification that opens it: counts, new listings per model, the best deals and the biggest drops, each opening its listing), "A sua localidade" (your home town: every listing
  shows its distance from it), "Modelos acompanhados" (your own models: switch on/off, first
  year, favourite colours of each (listings in them are marked "Cor
  preferida", never scored), new-bike price, add models: brand and model picked from the sites'
  lists or entered by name, with optional engine size; both OLX and
  Standvirtual are searched automatically, without copied URLs; alternative
  model names are tucked under "Outros nomes do modelo"), "Comparar modelos"
  (your models side by side: typical asking
  price and its spread, the typical bike, time until leaving the market,
  price drops, depreciation, the price trend of the last weeks adjusted for
  year and km, with a small chart; cheapest first), "Quanto vale a minha
  mota" (a bike of one of your models, or with an account any brand and
  model, collected for the request and answered by a notification after
  the next collection, from its year and km: the market value and its
  range, adjusted to its condition when you say it (falls or accidents,
  owners, service book, warranty), the price to ask, the time to sell
  and a dealer's trade-in; your last requests below), "Comprar no
  estrangeiro" (the same form for a bike seen in Spain, France or
  Germany: its price there plus vehicle tax (ISV), legalisation and
  transport, against its value here), the collection status (last run, what it found, requests, next run; admins: "Estado da recolha" with the last runs, their errors and how long the scores took, the last 30 days' failures by site and cause, each site's requests today and pause, each search's pages read and ads found in the last run, the GitHub token's expiry and the database's size against the free plan's 500 MB, "Recolher agora") and data quality
  per site (live listings, unmatched, duplicates, missing year/km/location,
  when listings were last seen, sudden price changes).

## Running it

Use **Flutter 3.44.8 / Dart 3.12.2**. The root `.fvmrc` pins the SDK for
FVM and all app workflows (checks, smoke, preview, web/Android builds and
mutation testing). With FVM, run `fvm use 3.44.8` from the repository root
and put `.fvm/flutter_sdk/bin` first on `PATH` for the `make` commands.

```sh
cp env/dev.example.json env/dev.json   # SUPABASE_URL + SUPABASE_PUBLISHABLE_KEY
make app-run                           # from the repo root: Chrome
make app-check                         # analyze and test
make app-smoke                         # offline Chrome flow; matching ChromeDriver on PATH
make app-serve                         # release build on http://localhost:8080
```

The `intl` constraint accepts 0.20.2, pinned by Flutter 3.44's
`flutter_localizations`, as well as compatible newer patch releases.
Keep that lower bound compatible with the supported Flutter SDK when
updating dependencies; `go_router` also brings in the SDK localizations.

`make app-smoke` uses Flutter's SDK `integration_test` with the real app and
router and the widget tests' in-memory repositories. It applies a saved
search, changes and saves its filters, opens a listing, then opens an alert
and returns to Alertas through browser history. It switches between English
and Portuguese and checks the browser's document language without losing
the current route. No Supabase credentials,
live data, sign-in or native notification delivery are involved. It needs
Chrome and a matching ChromeDriver on PATH; the runner starts and cleans up
its own driver on an automatically allocated port. `check.yml` runs it
separately from `make check`.

Visitors get an anonymous session. Accounts come from invites: an admin
(Mais › Administração › "Contas e convites") creates a link and shares it, and
whoever opens it (`/#/join?code=…`) chooses an email and password; the
account is made at once (Supabase Auth's admin API, called by the
database). Admins also see the accounts, make other admins and remove
accounts. "Partilhar a app" sends the app's link to anyone.

## Code layout

```text
lib/app/        App widget, theme, router (go_router, one shell with 4 tabs; ads and their
                photos above it, pushed), DI (get_it)
lib/core/       Formatting, shared widgets
lib/l10n/       Portuguese/English ARB catalogs; ignored generated localizations
lib/features/   listings, collector_status, settings
  <feature>/domain/        entities, repository interfaces
  <feature>/data/          models (fromJson), Supabase repositories
  <feature>/presentation/  cubits, pages, widgets, *_text.dart (text built from data)
test/           unit tests for the cubits and *_text.dart functions; responsive
                widget and interaction regressions in interface_test.dart
integration_test/  offline browser smoke and shared in-memory interface fixtures
test_driver/    Flutter browser integration driver
```

The four tabs share editorial headings (`core/widgets/page_intro.dart`).
A compact wordmark with the app logo (`app_brand.dart`,
`assets/brand/app_logo.png`) anchors Ofertas and the
desktop navigation. Bottom navigation on
phones becomes a compact rail on tablets and an extended sidebar on
desktops. Empty/error messages scroll when space is short or text is
enlarged. Widget regressions use the actual bundled fonts, not test
substitutes (`integration_test/support/interface_fixture.dart`, also used by
the browser smoke).

The look lives in `lib/app/theme/`: `AppTheme` (light and dark colour
schemes, component styles) and `AppColors` (good/bad and Deal Score
colours). Fonts are bundled in `assets/fonts`: Barlow for text and Barlow
Semi Condensed for titles, prices and scores (SIL Open Font License),
with arrows drawn in by `tool/font_arrows.py`; Barlow Regular is also
registered as "Roboto", the web engine's default font, which it would
otherwise download from Google. `tool/font_coverage.py` (`make tool-check`)
fails when the app writes a character the fonts lack, when a font keeps
TrueType hinting (the web app downloads every font before it draws; the
command to strip it is in the script) or when a font file isn't declared
in `pubspec.yaml`. Only the weights the app uses are bundled.

The start (`lib/app/startup.dart`) asks for the first listings while it
signs in, and `web/index.html` opens the connections it needs early
(Google's CDN for the engine, the photos' CDN, and the database, whose
address the deploy writes in with `tool/web_preconnect.sh`). For a
visitor without an account's session, `web/index.html` also asks for the
first page of listings and the model list while the app downloads, and
starts the first cards' photos; the start takes that answer
(`core/platform/first_page.dart`) instead of asking again. Its queries
are the app's own, checked by `test/first_page_test.dart`.

State uses Cubits (flutter_bloc) with Equatable states. Shared listings,
saved searches, alerts and favourites follow the account through
`SessionCubit` and `core/auth/account_scoped_cubit.dart`, not through
callbacks in the sign-in or invite screens. Account changes and sign-out
clear their cached data before reloading; late reads, writes and failed
optimistic rollbacks cannot restore the earlier account's data. The same
account's token refresh and anonymous startup keep the current data;
listing filters and sort are preserved.

Photos use
`Image.network` with `WebHtmlElementStrategy.prefer`, because the photo
sites send no CORS headers.
