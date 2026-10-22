# Data sources

Rule: before any collector reads a source, its access is verified and recorded
here. Robots.txt is not permission; the source's terms of use decide.

## Decision log

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
(Mais › Recolha de dados, "Estado da recolha"). To set caps again:
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
searches already name the engine size (`q-650`, `q-7`). An ad whose seller
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
links. Phone numbers are never read. Ads OLX shows as copies of Standvirtual
ads (`partner: standvirtual`, 8 of 47 on the first page checked) are
skipped: the original is collected from Standvirtual.

**Not committed.** Saved pages (`collector/samples/olx/`) are in
`.gitignore`.

**Open: OLX terms of use** (row in the table below): to be read and quoted
by the owner.

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

**Open: terms of use (to be filled by the owner).**

| Source | Clause (quote) | Verdict |
|---|---|---|
| Standvirtual terms | _paste the clause(s) about robots, automated access, extraction, reuse of content/database_ | _allowed / not allowed / unclear_ |
| OLX Portugal terms | _same_ | _same_ |

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