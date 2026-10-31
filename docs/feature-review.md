# Feature review (2026-10-31)

Rafael asked for a review of every feature: what could be better, what
doesn't make sense, and what to change in the code and in the UI/UX.
This file holds the findings and the order to work through them.
Each finding was checked against the code (file and line named), not
guessed from the docs. Steps get the ids **F.1, F.2, ...** in the roadmap
as they are done; tick them here too.

Tags: **[bug]** something gives a wrong or useless result today, **[ux]**
how it looks or reads, **[odd]** a feature that doesn't make sense where
or how it is, **[code]** how it is written, **[data]** collection,
scoring or alerts. Priority: **P1** do first (wrong results or noise
every day), **P2** clear gain, **P3** when convenient.

None of these needs Rafael's decision except where it says so. None
touches the fetching rules.

---

## 1. Ofertas (the list)

1. **P1 [bug] "Mais barato primeiro" starts with placeholder prices.**
   `getListings` (`supabase_listings_repository.dart`) has no price
   floor. Ads at 1 € or 100 € (sellers who write "consultar") sort to the
   top. The scoring already ignores them (under 300 €, "ads under 300 €
   never count"), and so does the offer. *Proposal:* sort them last in
   the price sorts, and show "Preço por consultar" in place of the
   price on the card and the page.
2. **P1 [bug] "Mais perto" and "Distância máxima" without a home give
   nonsense.** Without `user_home`, every `distance_km` is null:
   - the sort falls back to the id, so the order is effectively random;
   - the distance filter matches nothing, and the person sees "Nenhum
     anúncio corresponde a estes filtros".

   Both are offered anyway: `ListingSort.values` in the sort menu, the
   distance field in the filter sheet. *Proposal:* when no home is set,
   show the sort and the field disabled, with "Defina a sua localização
   em Mais" and a button that opens it.
3. **P2 [ux] About half of a phone's first screen comes before the first
   ad.** On the dashboard, these all sit above the list:
   - the editorial intro ("O seu radar de motas" / "A sua próxima mota
     começa aqui" / a sentence);
   - a toolbar of four buttons, which wraps to two rows on a phone;
   - the chips;
   - a divider;
   - the count and "Compare até 3 anúncios".

   The intro reads well once, but this is the screen opened several
   times a day. *Proposal:* keep the intro only in the empty state; put
   the count on the toolbar row; drop the compare hint once the person
   has compared once (the card's footer button already says "Comparar").
4. **P2 [odd] "Cartões" sits in the daily toolbar.** It sets which facts
   the cards show: a preference set once. It already lives in Mais ›
   "Cartões dos anúncios", yet it takes a toolbar slot next to Filtros
   and Ordenar. *Proposal:* remove it from the toolbar (Mais keeps it),
   which also gets the toolbar back to one row on most phones.
5. **P2 [ux] The list doesn't refresh when the app comes back.**
   `AppShell` reloads the alerts on resume, but not Ofertas. Collections
   run every 2 h, so the list is stale until a pull to refresh.
   *Proposal:* on resume, if the last load is over 30 minutes old, ask
   how many ads are newer than the first one shown. If there are any,
   show "N anúncios novos — mostrar" on top. This keeps the scroll
   position instead of reloading under the person's finger.
6. **P3 [ux] Free-text "Localização" next to "Distância máxima".**
   `ilike '%Porto%'` also matches "Porto de Mós" and misses spellings.
   With `places` (towns, municipalities, districts) and the distance
   filter, the text field is the weaker tool. *Proposal:* replace it with
   a district picker (or drop it).
7. **P3 [ux] Missing filters:** a maximum year and a minimum price.
   Both are cheap to add to the filters and to `saved_search_matches`.
   With item 1 done, the minimum price matters less.
8. **P3 [ux] The card doesn't show the most useful number.** The Deal
   Score badge is there, but "x % abaixo do valor estimado" (the reason
   the ad is a deal) needs a tap. *Proposal:* add it as an optional card
   field (`ListingCardField.marketPosition`), on by default. Its value
   is already in `score_breakdown->pct_below_market`, but only
   `risk_reasons` is selected today: add only that one key to
   `summaryColumns` and to `web/index.html`'s first page
   (`first_page_test.dart`).

## 2. The listing page

1. **P2 [ux] The title bar says "Anúncio".** Once the header scrolls
   away, nothing says which bike this is. *Proposal:* show "Yamaha MT-07
   · 2021" in the AppBar once the header is out of view.
2. **P2 [ux] No way to share an ad.** "Partilhar" exists for invites
   (`core/platform/share.dart`), but not for a listing. People do send
   bikes to a friend. *Proposal:* add a share action that sends the app's
   link (`/#/deals/<id>`) and the site's link.
3. **P3 [odd] The page opens on the last tab used, even from a
   notification.** `_ContentState._lastSection` is static, so the tab
   used last opens on every ad. That helps when comparing ads one after
   another. But a "Novo anúncio" push for a new bike then opens on, for
   example, Negociar. *Proposal:* open on Avaliação when the page comes
   from a notification or an alert; keep the last tab when coming from
   the list.
4. **P3 [odd] The import calculator is on every ad.** In Mercado, every
   Portuguese ad has a full "Comprar no estrangeiro" card above the cost
   of ownership. That is a question about buying elsewhere, not about
   this ad. *Proposal:* collapse it behind one line ("E se a comprasse
   no estrangeiro?"), as `CollapsibleSection` does elsewhere.

## 3. Pesquisas, Alertas and the notifications

1. **P1 [data] One bike, two notifications.** A new ad scoring 80+ that
   matches a saved search with both "novos anúncios" and "excelente
   oportunidade" on gets two alerts in the same run:
   `generate_new_listing_alerts` and `generate_excellent_opportunity_alerts`
   each insert one, and the unique indexes are per type. `notifyPending`
   then sends one push per alert, so the same bike arrives twice and
   shows twice in Alertas. *Proposal:* in `notifyPending`, send one push
   per account and listing per run, with the stronger title ("Excelente
   oportunidade" wins over "Novo anúncio"). Keep both rows: they mean
   different things and are deduplicated separately.
2. **P1 [data] Bursts.** Each alert is its own push. A model followed
   for the first time, a busy evening, or the first run after quiet
   hours (23:00–08:00; every waiting alert goes at 08:00) can send 10–20
   notifications in a row. *Proposal:* when one account has more than 3
   alerts in a run, send the 3 best (by type, then Deal Score) and one
   summary push "Mais 7 alertas: 5 novos anúncios, 2 descidas de preço"
   that opens Alertas. This is pure collector logic, in
   `notify/notify_pending.dart` and `notification_text.dart`, with tests.
3. **P2 [ux] Alertas loads the latest 100 and nothing older.** The list
   has no "load more" (`supabase_alerts_repository.dart`, `.limit(100)`)
   and no way to clean it but swiping one at a time. *Proposal:*
   - filter chips by type (Novos / Descidas / Removidos / Excelentes);
   - "Apagar os lidos" next to "Marcar todos como lidos";
   - paging as in Ofertas.

   `dismiss_alert` already exists, so the bulk delete is a small RPC
   (`dismiss_read_alerts`).
4. **P2 [odd] Pesquisas is a tab, Favoritos is not.** A saved search is
   set up once and then works through Alertas, so its tab is opened
   rarely. Favoritos, the bikes the person is actually weighing, is a
   pushed page reached from Ofertas' AppBar or Mais. *Proposal:* use the
   tabs Ofertas / Favoritos / Alertas / Mais, and move Pesquisas into
   Alertas as its second segment ("Alertas | Pesquisas"), since searches
   exist to make alerts. The swipe actions, the editor and the deep
   links stay as they are; only where Pesquisas sits changes. *This
   changes habits, so I'd do it, but say no if you prefer the current
   tabs.*

## 4. Mais

1. **P2 [odd] The collection's internals are shown to everyone.**
   "Recolha de dados" (the last runs, "Qualidade dos dados" per site,
   missing fields, sharp price changes) is shown to every account and
   to anonymous visitors. It is admin information. *Proposal:* for
   non-admins, keep one line ("Última recolha há 40 min · próxima às
   14:00"), and move "Recolhas recentes" and "Qualidade dos dados" under
   Administração next to "Estado da recolha".
2. **P2 [odd] Two different features are both called "Comparar".**
   "Comparar modelos" in Ferramentas opens the market per model
   (`/market`). "Comparar" in Ofertas compares up to 3 ads. *Proposal:*
   rename the first "Mercado por modelo" / "Market by model".
3. **P3 [ux] Mais is long.** It has seven sections; on a phone, the
   tools and notifications sit two screens down. With 4.1 and the
   Favoritos tab (3.4), Pessoal loses an entry and Recolha shrinks to
   one line, which is most of the fix.
4. **P3 [ux] The account row says "Toque para terminar a sessão".** A
   tap opens a sheet, not a sign-out, and a sign-out is not what one
   expects a tap to do. *Proposal:* "Conta e sessão" / "Account and
   sign-in".

## 5. Tools (Mercado, Quanto vale, Comprar no estrangeiro, Modelos)

1. **P3 [data] Estimates come only from asking prices.** The app says
   so, but the database already knows more. An ad that left the market
   without being relisted most likely sold, at or a little below its
   last price (`listings.last_pct_below_market`, `listing_time_to_sale`).
   *Proposal, in two steps:*
   - show "Saíram do mercado por" (the median last price of the model's
     gone ads in the last 90 days, adjusted like the estimate) in
     Mercado and in "Quanto vale a minha mota";
   - only after some weeks of comparing it with the estimate, decide
     whether it should feed the fair value.

   Nothing changes in the score until then.
2. **P3 [ux] Bike value and the import calculator share one 598-line
   page** (`bike_value_page.dart`, `importing: true`). This is fine for
   the person, but see 7.3.

## 6. Notifications setup (operational)

1. **P1 Firebase is not set up.** The last deploy logged
   `FIREBASE_ANDROID_CONFIG not set: the app is built without
   notifications`, so the Android app gets none.
   - The steps are in `docs/hosting.md`, "Notifications in the Android
     app": create the project, add the two secrets, deploy again.
   - **Rafael:** only you can create the project and the secrets.

## 7. Code

1. **P2 [code] There is no single place to read the current schema.**
   There are 129 migrations, and the functions are redefined many
   times:
   - `recalculate_deal_scores` 13 times;
   - `risk_assessment` 11;
   - `generate_alerts` 7;
   - `pending_notifications` 6.

   To read today's version, one has to find the last file that defines
   it. *Proposal:* `make db-test` already builds a fresh database, so
   `tool/schema_snapshot.sh` would dump it (`pg_dump --schema-only`,
   sorted and without owners) into `supabase/schema.sql`. That file is
   committed, and CI fails when it differs from what the migrations
   produce. It is never applied, only read (by people and by the
   backlog passes).
2. **P2 [code] `features/listings` holds everything.** It has 140 files:
   alerts, saved searches, favourites, the comparison, the market, bike
   value, import and ownership cost. The convention ("clean
   architecture per feature") isn't really kept: `listings/presentation`
   alone has 89 files. *Proposal:* move, without changing code, into
   `alerts`, `saved_searches`, `favourites`, `compare`, `market` and
   `valuation` (bike value, import, ownership). Do it one feature per PR,
   with `make dead-code` and the tests as the check.
3. **P3 [code] The biggest widgets mix layout and logic:**
   - `listing_detail_page.dart` (604 lines);
   - `bike_value_page.dart` (598);
   - `dashboard_page.dart` (526: the list item nests four builders);
   - `offer_card.dart` (419);
   - `listing_card.dart` (409).

   *Proposal:* when touching them for the items above, extract the
   toolbar, the list item and the bottom bar into their own widgets.
   The collector's `store/listing_store.dart` (803 lines, every
   database call) splits the same way: listings, alerts and pushes,
   photos, runs.
4. **P3 [code] Localization keys named after files.**
   - 46 of the 1 046 keys end in the file they were extracted from
     (`listingListingDetailPage`, `compareDashboardPage`,
     `removeOfferCard`).
   - 11 English texts exist under two keys (`signIn` / `signInAction`,
     `remove` / `removeOfferCard`, `serviceBook` /
     `bikeValueServiceBook`, …).

   *Proposal:* do one pass that renames them by meaning and merges the
   true duplicates. Keep the texts that only look the same but may
   translate differently: "Ano" as a field label and as a column
   heading are the same, but "Nenhum" for damage and for a service book
   are not.
5. **P3 [code] Leftovers:**
   - The policy "Users delete their own alerts" (`create_alerts.sql`)
     outlived its grant (removed in S.1). It is harmless but misleading.
   - `pending_notifications` still works out `to_telegram` (a lookup in
     `app_admins` per alert), which nothing reads since 2026-10-21.

   *Proposal:* drop both in the next migration that touches alerts
   (with item 3.1).

## 8. Docs

1. **Done in this PR:** `concept.status.md` §12 and §14 and the roadmap's
   4.7 note still said:
   - market behaviour is "data being collected" as a score slice (it
     was decided out of the score on 2026-10-28);
   - text contradictions are "planned" (done, 15.6);
   - reused images are "not started" (done, P.1);
   - the equipment slice is live (it became a bonus, 15.21).

---

## Order

The P1s first, each a small PR with its tests:

| Step | Items | Where |
|---|---|---|
| F.1 ✅ | 3.1 one push per bike, 3.2 summary push for bursts | collector |
| F.2 ✅ | 1.1 placeholder prices, 1.2 sort and distance without a home | app, small migration for the sort |
| F.3 | 1.3 compact Ofertas header, 1.4 Cartões out of the toolbar, 4.2 rename | app |
| F.4 | 2.1 title, 2.2 share, 2.3 opening tab, 2.4 import card folded | app |
| F.5 | 4.1 collection internals to Administração, 4.4 account row | app |
| F.6 | 3.3 Alertas filters, bulk delete, paging; 7.5 leftovers | app + migration |
| F.7 | 1.5 "N anúncios novos" on resume, 1.8 market position on cards | app |
| F.8 | 7.1 schema snapshot | tool + CI |
| F.9 | 3.4 Favoritos tab, Pesquisas inside Alertas (if Rafael agrees) | app |
| F.10 | 7.2 split `features/listings`, 7.3 big widgets, 7.4 keys | app, several PRs |
| F.11 | 1.6, 1.7 filters; 5.1 "Saíram do mercado por" | app + SQL |

Item 6.1 (Firebase) is Rafael's and can happen at any time.
