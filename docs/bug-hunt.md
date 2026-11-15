# Bug hunt (2026-11-15)

Rafael asked for a big hunt for bugs and improvements, documented first
and fixed later. This pass read the newest features, where bugs are most
likely (N.100-N.110: the first page, typed ads and their scores, the ad
check, year ranges, similar models, value coverage and generations, the
iPhone shortcut), against `supabase/schema.sql` and the app and
collector code. Each finding names its file and line and was checked in
the code. Steps get the ids **B.1, B.2, ...** in the roadmap as they are
done; tick them here too.

Tags and priorities are those of `feature-review.md`: **[bug]** a wrong
or useless result today, **[ux]** how it looks or reads, **[code]** how
it is written, **[data]** collection, scoring or alerts, **[perf]**
speed. **P1** do first, **P2** clear gain, **P3** when convenient.

No finding needs Rafael's decision, and none touches the fetching rules.

What was checked and found right (no finding):

- The typed ad's market position below 3 comparables: the breakdown
  carries `pct_below_market` anyway, but `typedAdListing`
  (`typed_ad.dart:116`) leaves it out, as for a stored ad.
- An ad check answered with a listing that has no Deal Score yet: the
  push (`bike_value_push.dart:90`) leaves the score out.
- `parseComparableYears` refuses a range that runs backwards, so
  `bike_value_in_years` never gets an empty range from the app.

---

## 1. Typed ads and their scores (N.105, N.107)

1. ✅ (B.1) **P2 [data] The ad's title is never read for risk signals or
   equipment.** `typed_ad_score` calls `description_signals(null,
   p_description)` and `listing_extras(null, p_description)`
   (`20261115150000_year_ranges.sql:225`, `:268`). A stored ad passes
   its version or title as the first argument (`variant`). A Facebook
   or CustoJusto title often says what the text doesn't: "MT-07 35 kW
   A2", "por legalizar", "com Akrapovic". The shared ad brings its
   title (`SharedAd.title`), but `sharedAdFacts` only uses it for the
   year, the km and the model's guess (`shared_ad_text.dart:180`,
   `:205`, `:385`). *Proposal:* add `p_variant text default null` (a new
   migration replacing the function) and send the shared ad's title, or
   a "Título do anúncio" field when the person types the ad by hand.
2. **P3 [data] An imported bike typed by hand never gets the
   `imported` sign.** `typed_ad_score` passes `p_origin` as null
   (`risk_from_signals`, argument 11). Only the text's "por legalizar"
   reaches the score. *Proposal:* add an "Importada" answer to
   `BikeConditionFields`, passed as `'imported'`, and say what it
   changes. Low priority: the text rules already catch most of these.
3. ✅ (B.3) **P3 [ux] The time on sale doesn't read the sites' own words.**
   `typedAdDaysValue` (`typed_ad_history.dart:12`) takes "5 semanas"
   but not what Facebook and CustoJusto show:
   - "há 5 semanas" and "5 weeks ago";
   - "1 ano" and "1 year";
   - "há 3 horas" (0 days).

   Each of these reads as an error. *Proposal:* drop a leading "há" and a
   trailing "ago", take years (365 days), and read hours and minutes as 0
   days. Add tests for each.

## 2. Ad check and value coverage (N.102, N.106)

1. **P3 [perf] `listing_for_ad` reads every listing of the site.**
   `substring(l.url from '-(ID…)\.html') = ad_link_code(p_url)`
   (`20261115100000_ad_checks.sql:54`) has no index, so each call
   applies a regular expression to every OLX or Standvirtual row.
   Three places call it:
   - the computed field `ad_listing`, once per request row;
   - `request_ad_check`;
   - `answer_bike_value_requests`, once per waiting request, in an
     `exists`.

   Visitors can call `listing_for_ad` too. It is fine at today's size,
   but it grows with the table. *Proposal:* add an expression index
   `on listings (source, substring(url from '-(ID[0-9A-Za-z]+)\.html'))`
   (the expression must match the query's exactly), with a test that
   `explain` uses it.
2. **P3 [data] "5 ads within 3 years" can mean fewer comparables.**
   `near_comparable_count` (`20261115120000_value_coverage.sql:20`)
   counts ads with or without a mileage. `bike_value_in_years` leaves
   out ads without one when the bike has one. A request can then be
   "ready" and still be answered with fewer than 3 comparables, so with
   no price. *Proposal:* count with the same rule (`p_mileage is null or
   c.mileage is not null`): pass the mileage to `near_comparable_count`.

## 3. Similar models (N.106b)

1. **P3 [code] Models added later never join a platform group.** The
   migration says models added from the app under those names "join
   too" (`20261115130000_similar_models.sql:20`). But the `update` runs
   only once, when the migration is applied. Neither `bike_value_model`
   nor adding a model from "Modelos acompanhados" sets `similar_group`.
   An "XSR 700" added tomorrow stays alone. CLAUDE.md already says
   "empty for models added from the app", so the comment is the wrong
   one. *Proposal:* move the table of names into a function
   `similar_group_of(brand, model)`. Call it from a `before insert`
   trigger on `motorcycles` and from the migration's `update`. Test it
   with a model added by name.

## 4. iPhone shortcut and shared ads (N.110)

1. ✅ (B.2) **P3 [ux] The same ad shared twice with different tracking waits
   twice.** `receive_shared_ad` compares the exact address for "already
   waiting" (`20261115180000_shared_ad_page_text.sql:87`). Facebook and
   CustoJusto add `?ref=…`, `?tracking=…` or a fragment, so the second
   share of the same ad makes a second row and uses one of the 10
   places. *Proposal:* store and compare the address without its query
   and fragment, with the host in lower case, as `request_ad_check`
   already does for its links (`20261115100000_ad_checks.sql`,
   `regexp_replace(v_url, '[?#].*$', '')`). Keep the query only for a
   site whose ad id lives in it: Facebook's `/marketplace/item/<id>/`
   doesn't need one.
2. **P3 [code] The hourly and daily limits aren't held against two
   shares at once.** The `count(*)` checks (`:76`, `:78`, `:88`) read
   without a lock, so two calls in the same instant could both pass at
   20. One person's shortcut can't realistically do that. *Proposal:*
   only if it is ever needed, `pg_advisory_xact_lock` on the user's id
   before the counts.
3. **P3 [code] Photo addresses from any https host.** `receive_shared_ad`
   keeps any `https://` photo (`:117`), and the app then loads them. The
   only sender is the account's own key, so the risk is low (a request
   to a host of their choice). *Proposal:* keep the photos of the hosts
   the sites use (Facebook's `scontent*.fbcdn.net`, CustoJusto's CDN,
   `apollo.olxcdn.com`), drop the others, and say so in the inbox.

---

## Order

1. ✅ B.1: typed ad's title read for signals and equipment (1.1).
2. ✅ B.2: shared ad addresses without tracking (4.1).
3. ✅ B.3: time on sale in the sites' words (1.3).
4. B.4: similar groups for models added later (3.1).
5. B.5: the index for `listing_for_ad` (2.1) and the same count for
   value coverage (2.2), in one migration.
6. B.6, when convenient: origin for typed ads (1.2), share limits and
   photo hosts (4.2, 4.3).
