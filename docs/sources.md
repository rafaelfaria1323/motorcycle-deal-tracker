# Data sources

Rule: before any collector reads a source, its access is verified and recorded
here. Robots.txt is not permission; the source's terms of use decide.

## Decision log

### 2026-11-14: candidate sources' robots.txt read (15.9)

For 15.9 (one European site for imports, or more Portuguese ones), the
robots.txt of the likely candidates was read once each on 2026-11-14,
by hand, with an honest user agent; nothing else was fetched and nothing
was stored. What each says for a crawler like ours (`User-agent: *`):

- **leboncoin.fr**: "It's forbidden to use search robots or other
  automatic methods to access Leboncoin.fr. Access is only permitted with
  special permission". Ruled out.
- **subito.it**: answered 403 to the robots.txt itself. Ruled out.
- **lacentrale.fr**: `Disallow: /` for named crawlers; cars more than
  motorcycles. Not worth asking.
- **milanuncios.com**: search results disallowed (`/*?s=`, `/*pagina=`,
  `/*?pag`, `/listing/`...). Ruled out: no search pages to read.
- **mobile.de** (suchen.mobile.de): search and result pages
  (`/fahrzeuge/search.html`, `searchresults.html`, `*pageNumber=`,
  `/consumer/api/`) and ad pages (`/*inserat/`) disallowed. Ruled out.
- **AutoScout24** (autoscout24.com): result lists disallowed (`/lst?`,
  `/lst-moto?`); autoscout24.pt reset the connection. Ruled out.
- **moto.it**: its searches disallowed (`/*/ricerca?`). Ruled out.
- **wallapop** (es.wallapop.com): `/search` and every address with a
  query (`/*?`) disallowed; its results come from an app API. Ruled out.
- **motos.net** (now motos.coches.net): ad pages (`/Detail/`,
  `/Vehiculo.aspx*`) and pages from 7 on (`/*pg=7*`...) disallowed.
  Ruled out: ads can't be read, nor a search followed to its end.
- **autouncle.pt** (an aggregator of other sites' ads): allows most of
  the site, but its ads are Standvirtual's and OLX's, which are read
  already, plus others it gathers under its own terms. Not worth it.

Decision: no new source now. Every European marketplace a buyer would
import from refuses automated reading of its searches, so the import
side stays the calculator with a price the person types (16.10,
"Comprar no estrangeiro"). Left in 15.9: Portuguese dealers' own sites
with their stock, each only after Rafael reads its terms, and only with
the fetching rules (robots.txt, 6-10 s apart, never parallel). Rafael
can name a dealer to look at; nothing is built without that.

### 2026-11-14: CustoJusto not used (N.98)

Rafael asked for CustoJusto (custojusto.pt) as a third source. Its
robots.txt, read once on 2026-11-14, begins: "It is expressly forbidden to
use spiders or other automated methods to access CustoJusto.pt. Only if
custojusto.pt has given special permit such access is allowed." It also
disallows every results page after the first (`/*?o=*`, `/*&o=*`), so even
what it lets a crawler read would be one page per search: not enough to
follow ads or see them go. Not built; nothing was stored. Only with the
site's written permission would this be looked at again.

### 2026-11-13: motorcycle recalls from the EU's Safety Gate (N.86)

**Why.** A used bike may have been called in by its maker (a chain, a
brake hose, a fuel pump) and never taken to the dealer; the buyer should
ask. Nothing in the listings says so.

**Source.** Safety Gate, the European Commission's rapid alert system
for dangerous non-food products
(https://ec.europa.eu/safety-gate-alerts/), built for the public to read.
Its weekly reports are published as XML: the list
(`/safety-gate-alerts/api/download/weeklyReport/list/xml/en`) and each
report (the list's address, `language=en`, or `pt` for the Portuguese
text). No key. Each alert names the product, brand, model, type, production
dates, the maker's recall code, the danger and the notifying country. No
personal data. The Commission's content may be reused with
acknowledgement of the source (Decision 2011/833/EU, the Commission's
reuse policy); the app's cards say they come from Safety Gate, the
Commission's alerts, and link each alert.

**Decision.** The database reads it, not the collector (pg_cron
`refresh-vehicle-recalls`, every hour at :13, `refresh_vehicle_recalls()`):
the list at most once every 20 hours, then the reports not yet read,
newest first, one request at a time 3 s apart, at most 2 minutes a run,
30 s timeout, an honest user agent; a failure stops the run and warns.
Reports from 2010 on (some 850 to read once, over a few days; then
one a week). Only the alerts in "Motor vehicles" whose product is a
motorcycle, moped or scooter are kept (`vehicle_recalls`), and only for
those the Portuguese report is read too. Matched to the catalog by brand
and model name (or alias), with the production years against the bike's.
Nothing about the listing sites changes.

### 2026-11-13: model specifications from API Ninjas (N.76)

**Why.** "Ficha técnica", "Cabe-me?", the cost of ownership and the A2
filter need each model's figures; models added from the app had none.

**Source.** API Ninjas' motorcycles API
(https://api-ninjas.com/api/motorcycles), a paid service with a free
tier (3 000 calls a month); Rafael created the account (2026-11-13). Per model year it gives
the makers' figures as text with units (power, torque, weights, seat
height, tank, consumption, tyres, engine layout). No personal data.

**Decision.** The collector asks it weekly (`model-specs.yml`), only about
models missing a figure or never checked (a few calls a week), one call
at a time, with the key in a header from the secret `API_NINJAS_KEY`.
The first run used 19 calls (every model once); after it, a model is
asked again only while it still misses a figure, once every 30 days (about
2-3 calls a month today), plus one or two per model added from the app.
Only empty catalog figures are filled; typed ones stay and differences are
reported. Nothing about the listing sites changes.

### 2026-11-12: fuel prices from DGEG's public API (N.74)

**Why.** The cost of ownership needs the price of a litre of petrol.

**Source.** DGEG (Direção-Geral de Energia e Geologia), the State's fuel
price portal, https://precoscombustiveis.dgeg.gov.pt/, built for the
public to read. Its API (`/api/PrecoComb/PMD?idsTiposComb=3201&dataIni=…&dataFim=…`)
needs no key and returns JSON: per day, the national average price
("PrecoMedio", "1,911 €"), the stations counted and the range. Robots.txt
disallows only /media and /files. Only national averages, no personal
data.

**Decision.** The database reads it, not the collector: once a day
(pg_cron `refresh-fuel-prices`, `refresh_fuel_prices()`), one request for
the last week of "Gasolina simples 95" (id 3201), 20 s timeout, an honest
user agent, stored in `fuel_prices`. A failure only warns; the app keeps
the last price with its date. Nothing about the listing sites changes.

### 2026-11-12: Standvirtual read at the engine size too (N.71)

**Why.** A CBR650R Rafael's father found (ID8Q1m16, "Honda CBR", the
version empty, 649 cc) never reached the app (N.70). Standvirtual's model
filter is a family ("CBR", "CB", "R"), and our searches narrowed it with
words (`/motos/honda/cbr/q-650`), which match only an ad whose version
spells them. Checked by hand on 2026-11-12 (a few requests, 10 s apart,
robots.txt allows search pages): CBR with "q-650" 1 ad, CBR at 640-660 cc
8 (this ad among them); CB with "q-650" 7, at 640-660 cc 15; R with "q-7"
3, at 680-710 cc 2. The engine-size filter
(`search[filter_float_engine_capacity:from]` / `:to]`, inclusive) misses
ads that leave the engine size empty (an R7 "Edição 60º Aniversário", an
R7 for the A2 licence, a CB650R E-Clutch 2026), which the words find.

**Decision.** Keep each word search inside a model filter and read the same
filter at its models' engine sizes after it (`standvirtualEngineSearch`:
the lowest `engine_cc_min` to the highest `engine_cc_max`, the same first
year; only when every model has both). Ads in both are stored once; the
resolver matches the family and engine size ("CBR", 649 cc = CBR650R; a
CB650F stays out by its excluded words). About one more page per such
search and run (three today); the fetching rules are unchanged. Searches
without a model filter ("/motos/yamaha/q-mt-07") get none: the engine
size would bring every model of the brand at that size.

On OLX, which gives no exact engine size, a title naming only the family
("Honda CBR") now takes the model the description names right after the
brand in its first 12 words ("VENDE-SE – HONDA CBR650R E-Clutch"), only of
the ad's own OLX family, so "troco por Honda CB650R" never matches.
Standvirtual's search pages have no description, so this is OLX only (a
re-import would otherwise undo it).

### 2026-10-28: terms of use read (5.2)

**Source.** Rafael's summary of both sites' terms (in Portuguese, the
key words quoted as he gave them). The exact clauses of the versions in
force are still to be copied in; the summary itself says to check them.

**OLX Portugal.** The archived general terms restrict the use of the
site's content and "a agregação e o tratamento de dados do site para
partilha com terceiros noutros sites". OLX's developer portal offers an
API after registration and approval of the application; OLX may refuse
or block that access if the application breaks the terms or harms the
platform or its users.

**Standvirtual.** The terms for professional sellers restrict commercial
use of the site without express permission and "a descarga, agregação ou
tratamento repetido e sistemático de dados" that breaks the terms of use.

**What this means for the collector.**

| Point in the terms | What the app does today | Reading |
|---|---|---|
| OLX: aggregating the site's data to share with third parties on other sites | Collects OLX ads into a private database used only by Rafael (invites exist but nobody else uses the app, 2026-10-28; no public page, no republishing, every ad links back) | In line while only Rafael uses it; inviting others would reopen it |
| Standvirtual: repeated and systematic download or aggregation of data | Reads the followed models' search pages 9 times a day and each listing page once | Not allowed as written, unless the clause is read as applying only to professional sellers' accounts, or only where it breaks the other terms |
| Standvirtual: commercial use without express permission | Free, personal, no income (paid plans on hold, 16.0) | Allowed |
| Both: public ads are not free to reuse | Stores only what the scores need; never private sellers' names or phone numbers | In line |

**Decision (unchanged until Rafael says otherwise).** The collection's
basis stays personal, non-commercial, low-volume use with the risk
accepted by the owner (2026-10-19). The terms confirm what that entry
assumed: neither site grants automated collection, and Standvirtual's
wording names it. No rule is loosened. Still open, Rafael's decisions:
(1) inviting anyone else would count as OLX's "partilha com
terceiros": ask first, (2) asking both sites for written permission or OLX's API
(the access request below), (3) the verbatim clauses of the current
versions, to be pasted into the table at the end.

### 2026-10-28: damage hints from a free image model (P.2)

**Why.** The second step of Rafael's photo checks: point out photos that
may show damage, free, without tokens, more requests or a slower run.

**Decision.** No new source and no extra request: the photos P.1 already
downloads from the photo CDN are also given to CLIP ViT-B/32 (MIT
licence, `Xenova/clip-vit-base-patch32` on Hugging Face, downloaded by
the workflow once and cached; Hugging Face is not a listing source and
sees no listing data) on the runner, from memory, never written to
disk. Listings fingerprinted before it get their 3 photos from the CDN
once more, under the same rules and 5-minute budget. Kept: the model's
scores and each photo's embedding (512 bytes), never the photo.

### 2026-10-28: photo fingerprints from the photo CDN (P.1)

**Why.** Rafael asked for the ads' photos to be examined, free and
without tokens, without more requests to the sites or a slower run.

**Decision.** The photos come only from the photo CDN both sites already
serve them from (`https://ireland.apollo.olxcdn.com/v1/files/...`, the
addresses the search and listing pages give), never from a site page.
Its own fetcher and state (`FetchSite.photos`, `.fetch_state.photos.json`):
one photo at a time, 2-3 s apart, at most 5 minutes a run, after the run
is recorded; the same stops and 24 h pause on 403/429/503 or a reply that
isn't an image, and robots.txt is obeyed when the CDN has one (the
longest matching Allow/Disallow line decides, RFC 9309, compared
percent-decoded, N.42; a refused photo
stops the step and leaves the listings unchecked). The first
3 photos of each listing, once. Only a 64-bit hash of each photo is kept,
never the photo. The requests are counted apart ("Photo requests:"), so
the sites' counts are unchanged.

### 2026-10-28: light runs read newest first (R.2)

**Why.** Most runs re-read pages of ads already seen: a search of 4 pages
costs 4 requests every run though only its first page changes.

**Decision.** Fewer requests, never more: the rules are unchanged (same
addresses, same pauses, one at a time). Four runs a day (00, 08, 14 and
20 h Lisbon time) read every page as before; the other five read a search
read in full in the last 12 hours only up to the ads published or renewed
2 hours before that read, then stop. The sorts used are the sites' own,
read from their sort menus on saved pages: OLX `search[order]=created_at:desc`
("Mais recente"; its default is relevance); Standvirtual's default order
("Destacado", `created_at:desc`) already lists ads by the later of
publication and renewal (`vas.bumpDate`), so its address is unchanged
("Mais recentes", `created_at_first:desc`, ignores renewals). Top ads are
left out of the date check on both sites. A search read this way never
removes listings, and a price change on a later page waits for the next
full run.

### 2026-10-23: every added model is searched on both sites (9.9c)

**Why.** The model picker's Standvirtual-only warning was accurate: a
missing OLX model filter left `olx_search` empty, so the collector skipped
OLX. Manual entry also required at least one copied search address.

**Decision.** Every catalog model gets both source addresses, including
previously single-source models. Existing addresses remain unchanged.
`catalog_search_url()` uses known ids from that source's `site_models`
when available; otherwise it builds a keyword search under the same
allowed motorcycle path. A known brand filter is kept, with only the
model in the keywords (OLX matches any word, so repeating the brand would
bring unrelated bikes); without that filter, both brand and model are
included. Empty search terms are refused, never expanded to the whole
market, and malformed site ids are not used. Accented search words are
kept and encoded by the collector's URI handling.

**App.** Pick or enter brand and model, first year and optional engine
size. No source choice or search URLs; alternative names stay optional.
The database fills missing searches, so older clients benefit too.

**Unchanged.** No new source, extra requests to discover ids, parallel
fetching or retries. The normal fetcher, year/engine filters, model
matching and incomplete-search removal safeguards still apply. Following
more searches can mean more requests within the existing run-time limits.

### 2026-11-11: robots.txt read with the one retry; changed photos read again (N.56)

**Decisions (Rafael).** (1) Reading robots.txt gets the one retry a page
already has (below): 60 s after a timeout, a dropped connection or HTTP
500/502/504, counted as a request. A single timeout on it used to lose the
site's whole run. Blocks (403, 429, 503) are still never retried and pause
the site. (2) When an OLX seller replaces an ad's first three photos (seen
in the search results already read, no extra request to the sites), the
photo step reads the new three from the photo CDN, as it does for a new
ad: "3 photos per listing, once" is now once per set of photos. Its own
spacing, 5-minute limit and stops are unchanged.

### 2026-10-27: one retry after a passing error (N.22)

**Why.** Four runs in three days lost a whole search to one passing error:
OLX sending no headers within the timeout (three times) and a Standvirtual
HTTP 502. The search then removed nothing and the run failed.

**Decision (Rafael).** A page that timed out, whose connection dropped or
that answered HTTP 500, 502 or 504 is asked for once more, 60 seconds
later (`FetchPolicy.retryDelay`). The retry is an ordinary request: counted,
after the usual pause, never in parallel, and within the run's 30 minutes
(if they run out first, the first failure stands). A second failure stops
the site's run as before. Blocks (403, 429, 503) and pages that aren't
normal are never retried and still pause the site for 24 hours.

### 2026-10-22: robots.txt kept up to 24 hours (R.4)

**Decision (Rafael).** robots.txt is read once a day per site instead of
at the start of every run. The copy read is kept in the site's fetch state
(`.fetch_state*.json`) for up to 24 hours (`FetchPolicy.robotsMaxAge`),
the most RFC 9309 allows a crawler to keep one. It is forgotten when the
site pushes back, so the run after the 24-hour pause reads it again. The
kept copy decides what may be read, as a fresh one would. This saves 6 of
the 7 robots.txt requests a day per site. Everything else in the rules is
unchanged.

### 2026-10-22: paid plans planned; the data's basis is personal use

**Not a change to the collection.** Rafael asked for a plan of paid
subscriptions (`docs/paid-plans.md`, roadmap Sprint 16). Every decision
below rests on personal, non-commercial use, and charging for the app
would end that basis. Before anything is charged, the terms (table at the
end) must be read, and the sites asked for permission or a lawyer
consulted. The EU database right and two CJEU judgments on search engines
over classified-ad sites (Innoweb v Wegener, CV-Online v Melons) are why
(`docs/paid-plans.md` §1.1).

**Decision (Rafael), the same day.** Paid plans only if the sites make
their data available to us: an API, or a licence for the listings. Until
then the app stays free for invited accounts.

### 2026-10-22: no request caps, the amounts shown instead (9.6e)

**Decision (Rafael).** The caps of 20 requests per run and 120 per day per
site are removed, to see what the collection really needs; they can come
back once the numbers are known. Each run reads every page of the tracked
models' searches and every Standvirtual listing page still to read.

**Kept.** robots.txt read every run, only the allowed paths, 6-10 s
between requests, one at a time, no retries, a 24 h pause on 403/429/503
or a non-normal page, honest user agent. New guard: at most 30 minutes of
requests per site and run (`FetchPolicy.maxRunTime`); what is left waits
for the next run. At 6-10 s that is at most about 225 requests per site
and run (7 runs a day, 9.6d).

**Watched.** Requests per run, per day and per month are shown in the app
(Mais › "Estado da recolha", admins). To set caps again:
`FetchPolicy(maxRequestsPerRun: …, maxRequestsPerDay: …)` in
`collector/lib/src/fetch/polite_fetcher.dart` (see `docs/hosting.md`).
The limits recorded below are those of their time.

### 2026-10-20: place coordinates from GeoNames (15.11)

The distance from home needs coordinates for the place names the sites
give. Source: GeoNames (geonames.org, CC BY 4.0: free use with credit),
taken from the npm package `cities.json` 1.1.65 (Portuguese towns over
1 000 people, the municipalities and districts). It is a one-off copy in
the migration `20261022150000_listing_distance.sql` (table `places`); no
site is read at run time. Credit: "Place coordinates: GeoNames
(geonames.org), CC BY 4.0".

### 2026-10-21: OLX searches ask for the engine size (9.13)

**Why.** OLX's model filter is a family: "R" holds the R125, R3, R6, R7, R1
and R9; "CB"/"CBR" every Honda CB and CBR from 125 to 1000 cc. A search for
the R7 or the CB650R also read every other model of the family, so more
than 100 stored OLX ads matched no followed model (Rafael, 2026-10-21):
pages and storage spent on bikes nobody follows.

**Decision.** When every model of an OLX search has an engine size inside
one of OLX's engine-size bands, the search asks for that band only
(`search[filter_enum_cilindrada][0]`). The bands are the values of OLX's
own filter list in its search pages (`ate-50-cc`, `51-125-cc`,
`126-500-cc`, `501-1000-cc`, `mais-de-1000-cc`; the last four added on
2026-10-21 for word searches such as the Forza 350 and ADV 350, which
brought every Honda: 2 pages each); an unknown value would make OLX return nothing, so a banded search whose
first page has no ads is not saved: it isn't read in full and removes
nothing, and the log says so. A model without an engine
size, or models in different bands, keep the search as it was. Standvirtual
searches name the engine size in words (`q-650`, `q-7`; since N.71 also
read at the models' engine sizes). An ad whose seller
left the engine size empty, or chose the wrong band, is no longer found on
OLX (Standvirtual still lists dealer ads).

**Cleanup.** The unmatched ads already stored were set to removed once
(migration `20261023160000`, not those with an alert or a favourite); the
next run makes the ones its searches still bring live again.

### 2026-10-19: searches come from the tracked models (9.9)

**Decision.** Each catalog model stores the OLX and Standvirtual search
that lists it (`motorcycles.olx_search`, `standvirtual_search`); the
`sources/*_searches.txt` files are gone. Every run, `make searches` writes
the searches of the tracked models (switched on in the app), one per
address: models that share one (R7, R1, R3, R9 under OLX "R/YZF") share
the requests, and each search gets a "year from" filter of the earliest
year any of them tracks (Standvirtual's since 2026-10-20, see below). Models can be added from the app with a search address copied
from the site.

**Limits unchanged.** The same fetch rules and budget apply (20 requests
per run, 120 per day, per site; removed on 2026-10-22, see above). Searches run oldest model first; when the
budget runs out the rest wait for the next run, and the app warns when the
OLX searches are many.

**Removal per search.** `fetch.dart` writes `searches.json` next to the
pages (planned searches, and the search of each saved page); each listing
records the search that found it (`listings.search_key`). A run removes
only listings of searches it read in full: a search cut short, with an
unreadable page, or no longer run (its models switched off) keeps its
listings. Listings not yet tied to a search are covered only when every
planned search was read in full.

### 2026-10-20: every page of a Standvirtual search, and fewer missed ads

**Decision.** Standvirtual searches ask for the first tracked year
(`search[filter_float_first_registration_year:from]`) and every page of a
search is read (32 listings per page, `?page=N`, the same path robots.txt
allows), as on OLX. Until now only the first page was read; a search over
32 listings was reported incomplete and the rest never collected.

**Also.** A model named with its engine size ("Forza 350", "ADV 350") but
added without one now gets that size's range, so ads named only "Forza" or
"ADV" are matched by the engine size the ad states (14 Standvirtual ads
were left unmatched in the run of 2026-10-20 16:40); "350cc" in a title
reads as "350". Listings under a search address no planned search uses any
more are removed by a run that read every search in full (tracked model,
within its years); before, they stayed live for good.

**Limits unchanged.** Same requests budget; the year filter keeps the page
count down (the 2026-10-20 run used 5 of 20 Standvirtual requests).

### 2026-10-19: OLX search pages as a second source (9.7)

**Decision.** The same low-volume personal fetcher reads the owner's OLX
search pages (the tracked models' OLX searches, `make refresh-olx`). OLX search
results already hold the full description, so no listing pages are read.

**Limits (enforced in code).** The same rules as Standvirtual, with OLX's
own budget (`.fetch_state.olx.json`): only www.olx.pt over https, only
/carros-motos-e-barcos/motociclos-scooters/ paths allowed by robots.txt
(read every run); 6-10 s between requests; max 20 per run and 120 per day;
no retries; stops on HTTP 403/429/503 or a page without OLX's
`__PRERENDERED_STATE__`, then refuses to run for 24 h. Searches carry a
2023+ year filter so each one is a few pages; every page of a search is
read, and a search with missing pages never removes listings.

**robots.txt (checked 2026-10-19, saved by the owner).** For `*`: blocks
*/ajax/, /adminpanel/, /api/ (including /api/v1/offers, which the search
page itself calls; we read the HTML page, never the API), */facebook/,
*/rss/, */account/, */myaccount/, /adprint/, /anuncio/leaflet/,
/anuncio/contact/, /payment/, /searchform/, ad-posting confirmation pages,
abuse and contact pages, */i2/*; `Allow: /`; no crawl delay.

**What is stored.** Source id `olx.pt/<ad id>`, url, brand, model, year,
mileage, price, seller type, business name (business accounts only; private
sellers' names are never read), city, description and up to 30 photo
links. Phone numbers are never read, and one written in the description
or title is removed before it is stored (N.43). Ads OLX shows as copies of Standvirtual
ads (`partner: standvirtual`, 8 of 47 on the first page checked) are
skipped when the original is already stored: it is collected from
Standvirtual with more detail. Our Standvirtual searches can miss an ad
(the CBR650R search's `q-650` needs "650" in the title, and a dealer's
"Honda CBR" has none), so a copy whose original (the ad code at the end of
its `externalUrl`) isn't stored is kept as an OLX ad (N.70, 2026-11-12):
no extra requests, and duplicate detection links the two if Standvirtual
finds the original later.

**Not committed.** Saved pages (`collector/samples/olx/`) are in
`.gitignore`.

**OLX terms of use**: read on 2026-10-28 (decision log, top; row in the
table below).

### 2026-10-19: low-volume personal fetcher for Standvirtual search pages (9.2)

**Decision.** For personal, non-commercial use, a capped fetcher downloads a
handful of the owner's own search pages (`make fetch`). The owner accepted the
terms risk knowingly; the terms clauses are still to be recorded below.

**Limits (enforced in code).** Only www.standvirtual.com over https, only
/motos/ paths allowed by robots.txt (read at the start of every run); 6-10 s
between requests; max 20 requests per run and 120 per day (60 until
2026-10-19, raised for runs every 4 hours); no retries; stops on
HTTP 403/429/503 or a non-normal page and then refuses to run for 24 h;
honest user-agent ("MotorcycleDealTracker/0.1 (personal project, low volume)").

**robots.txt (checked 2026-10-19).** For `*`: blocks /adminpanel/, /account/,
/myaccount/, /payment/, /api/, /ajax/, /i2/, /authentication*, /catalog/*/*/,
*/rss/, ad-action and confirmation paths; `Allow: /`; no crawl delay for `*`.

**Data use.** Kept in the owner's private Supabase project, never republished;
every listing keeps its link to the original.

### 2026-10-19: Standvirtual saved-page adapter, personal testing only (9.1)

**Decision.** A second adapter, `source = 'standvirtual'`, reads listing pages
that the owner saves by hand from the browser (File > Save, "HTML only") into
`collector/samples/standvirtual/`. The collector makes no request to the
website: the saved files are its only input.

**Why.** Whether the pipeline and the Deal Score work on real listings is the
largest unknown in the project, and it can be answered without automated
access. Using this adapter for anything beyond personal testing, or any
automated fetching, is blocked until the terms are read and recorded below.

**What the pages contain (checked 2026-10-19, one listing page).** The
`application/ld+json` blocks hold only site-wide data (WebSite, Organization).
The listing is in the `__NEXT_DATA__` JSON at `props.pageProps.advert`: id,
status, price and currency, make, model, registration year, mileage, seller
type and name, the dealer's address, description, photos and dates.
`createdAt` changes when an ad is bumped; `originalCreatedAt` is the first
publication date.

**What the adapter stores.** Source id (`standvirtual.com/<ad id>`), url,
brand, model, year, mileage, price, seller type, business name (dealers only),
municipality, description and up to 30 photo links (search results
carry one thumbnail; the listing page read for the details has them all,
14.4h). It does not read phone
numbers or other contact details, and it drops the generic boilerplate dealers
add to every ad, which would otherwise make unrelated bikes look like
duplicates.

**Not committed.** Saved pages are in `.gitignore`: they contain other
people's content and contact details.

**Terms of use** (read from Rafael's summary on 2026-10-28; see that entry).

| Source | Clause (summary) | Verdict |
|---|---|---|
| Standvirtual terms | No commercial use without express permission; no repeated, systematic download, aggregation or processing of data against the terms. _Verbatim clause of the current version to be pasted._ | Automated collection not granted; personal use at the owner's risk |
| OLX Portugal terms | Restrictions on using the content and on aggregating and processing the site's data to share with third parties on other sites; API only after registration and approval. _Verbatim clause of the current version to be pasted._ | Automated collection not granted; sharing with others unclear (today only the owner uses the app) |

Standvirtual's terms are linked from its footer to a help-centre page that is
rendered with JavaScript, so they could not be read automatically.

**Open: access request.** Ask each company whether a data feed or API for
market analysis exists. Date sent: _____ Answer: _____

### 2026-10-13: first source is a manual import (5.1, 5.2)

**Decision.** The first adapter imports listings from a JSON/CSV file that the
owner fills in by hand from ads they browse themselves. It uses
`source = 'manual'`. Real marketplaces come later as separate adapters.

**Why.** Access to OLX and Standvirtual could not be confirmed as permitted
(findings below). A manual adapter still exercises the whole pipeline:
adapter, normalization, storage, deduplication, scoring and alerts.

**Findings (checked 2026-10-13)**

| Source | Finding |
|---|---|
| OLX Group Partner API | For approved partners that post and manage their own adverts on behalf of an authorizing user. Documented endpoints: adverts (create/update/delete/activate/deactivate), advert metadata, taxonomy, promotions. No public search endpoint listed; Portugal not mentioned. FAQ says it is not for advert statistics or market data. |
| OLX Portugal developer portal | Login with an OLX account and app registration. Says nothing about reading public adverts. |
| OLX robots.txt / terms | Not verified (robots.txt could not be fetched; terms not read). |
| Standvirtual robots.txt | Crawling allowed in general; blocks account, ad-action, `/api/`, `/ajax/`, RSS and some catalog paths; fully blocks the Trovit aggregator bot. No statement about scraping. |
| Standvirtual terms | Not found/read on 2026-10-13. Standvirtual does list motorcycles (`/motos/`), confirmed 2026-10-19. |

**Checklist before adding an automated source**

1. Official API, feed or written permission available? Prefer that.
2. Terms of use read; the relevant clause quoted here.
3. Robots.txt checked and respected.
4. Allowed data and allowed usage (storage, display, republishing) written down.
5. Rate limit and schedule defined; identify the client honestly.
6. Always keep a link back to the original listing.
7. Date of verification recorded; re-check periodically.

**Data minimization.** Store only what the app needs. Do not store personal
names of private sellers; business names of dealers are fine. Keep the original
URL on every listing.

## Sources

- OLX Group developer FAQ: https://developer.olxgroup.com/faq
- OLX Group API reference: https://developer.olxgroup.com/reference
- OLX Portugal developer portal: https://developer.olx.pt/
- Standvirtual robots.txt: https://www.standvirtual.com/robots.txt
- Standvirtual terms (help centre): https://ajuda.standvirtual.com/standvirtualhelp/s/topic/0TO09000000kiW2GAI/novos-termos-e-condi%C3%A7%C3%B5es
- DGEG fuel prices (portal and API): https://precoscombustiveis.dgeg.gov.pt/
- API Ninjas motorcycles API: https://api-ninjas.com/api/motorcycles
- Safety Gate (EU alerts on dangerous products): https://ec.europa.eu/safety-gate-alerts/
- CustoJusto robots.txt (not used, N.98): https://www.custojusto.pt/robots.txt
- Candidates read for 15.9 (not used): https://www.leboncoin.fr/robots.txt,
  https://www.subito.it/robots.txt, https://www.lacentrale.fr/robots.txt,
  https://www.milanuncios.com/robots.txt, https://suchen.mobile.de/robots.txt,
  https://www.autoscout24.com/robots.txt, https://www.moto.it/robots.txt,
  https://es.wallapop.com/robots.txt, https://motos.coches.net/robots.txt,
  https://www.autouncle.pt/robots.txt
