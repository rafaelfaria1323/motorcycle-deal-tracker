# Data sources

Rule: before any collector reads a source, its access is verified and recorded
here. Robots.txt is not permission; the source's terms of use decide.

## Decision log

### 2026-10-19: OLX search pages as a second source (9.7)

**Decision.** The same low-volume personal fetcher reads the owner's OLX
search pages (`sources/olx_searches.txt`, `make refresh-olx`). OLX search
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
sellers' names are never read), city, description and up to 10 photo
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
municipality, description and up to 10 photo links. It does not read phone
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