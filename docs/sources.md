# Data sources

Rule: before any collector reads a source, its access is verified and recorded
here. Robots.txt is not permission; the source's terms of use decide.

## Decision log

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
| Standvirtual terms | Not found/read. Whether it lists motorcycles is also unconfirmed. |

**Checklist before adding a real source**

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
## Pipeline test (5.7)

Tested the full path (manual JSON → adapter → mapper → store → duplicates → scoring) with a deliberately messy file (`collector/samples/manual_edge_cases.json`).

### What worked
- Records without a URL are rejected at read time with a clear message.
- Tracking parameters (`utm_*`, `fbclid`), `www.` and trailing slashes are stripped, so the same listing gets one canonical `source_listing_id`.
- Messy input normalizes to the catalog: `honda` / `cb 650 r` → `honda-cb650r`, `particular` → private, padded locations are trimmed.
- In-file duplicates are dropped before writing; re-running the same file stores nothing new (idempotent).
- Duplicate detection runs before scoring, so duplicates stay out of market stats and scores.

### Findings
- Models not in the catalog are accepted as `unmatched` (stored with no `motorcycle_id`). They used to get a score from year/mileage only, which ranked bikes with no market price misleadingly. Fixed in 5.7b: only listings matched to a catalog model are scored; unmatched ones are stored, shown, and unscored.
- Cleanup SQL for test data must cover every fake domain used (`example.com` and `example.org`); a pattern for one domain left a stray row that skewed market stats.
- Dry run does not show in-file duplicates or normalized seller type / location; those are only visible in the database after a real run.

### Real listings (hand-copied, 3-5 samples)
- Normalizer problems seen: _fill in_
- Fields on the real pages that our format cannot hold (fuel, engine size, warranty, etc.): _fill in_
- Scores that looked off for a real bike: _fill in_

### Decisions
- Automated collection from a marketplace stays blocked until the terms of use are reviewed and recorded here. Until then the manual import adapter is the only live source.
