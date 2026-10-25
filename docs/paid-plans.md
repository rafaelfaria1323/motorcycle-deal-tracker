# Paid plans and other income (plan, on hold)

Rafael, 2026-10-22: "plan the paid features if in the future we want to
start having paid subscriptions: what could we offer to people that pay
(features we already have or don't have yet), and what would be other ways
to make money". This file is the plan. Its steps are in the roadmap
(Sprint 16); subscriptions, entitlements, checkout and paywalls are not built.
It waits for the sites'
permission (1.1, Rafael's decision). It is not legal or tax advice.
Where it says "check", a lawyer or an accountant decides.

## 1. Before anything is charged (Rafael's decisions)

These come first. None of them is a technical choice.

### 1.1 The data: may it be sold at all?

The collection's basis today is **personal, non-commercial use**
(`docs/sources.md`, 2026-10-19: "The owner accepted the terms risk
knowingly"). Charging money for access ends that basis.

- **Terms of use.** Neither site's terms are read and recorded yet (open
  item in `docs/sources.md`). Classified sites usually forbid automated
  extraction and commercial reuse. Under EU law such terms can bind even
  where no database right applies (CJEU, *Ryanair v PR Aviation*,
  C-30/14, 2015).
- **Database right.** The EU database right (Directive 96/9/EC, in
  Portugal Decreto-Lei 122/2000) protects a site's investment in its
  listings. Two CJEU judgments are close to this app:
  - *Innoweb v Wegener* (C-202/12, 2013): a search engine across car-ad
    sites "re-utilised" their databases.
  - *CV-Online Latvia v Melons* (C-762/19, 2021): a job-ad search engine
    infringes when it puts the original site's investment at risk.

  An app that charges people to search Standvirtual and OLX listings sits
  close to both.
- **Ways forward**, from safest to riskiest:
  1. Keep the app free among invited friends, as today. Donations only
     (16.13).
  2. Ask the sites for permission or a data licence, then charge.
  3. Charge only for what is ours, and show less of theirs. Our parts are
     the analysis, the alerts' timing, the negotiation and visit tools, and
     the valuation and import calculators. Each ad's link stays, but the
     app no longer shows its description or photos. Ask a lawyer first.
  4. Charge as the app is now: not recommended.

**Decision (Rafael, 2026-10-22): option 2 only.** Paid plans come only if
the sites make their data available to us: an API, or a licence for the
listings. Until then the app stays free for invited accounts, and no page
offers plans to anyone. Every step below assumes that permission exists.

### 1.2 The business (check with an accountant)

- **Activity at Finanças** (trabalhador independente, "Recibos verdes").
  Segurança Social contributions are exempt in the first 12 months of a
  new independent activity (check).
- **VAT.** Below about €15 000 a year, Portugal's small-business exemption
  applies (art. 53.º CIVA; check the current figure). Sales to consumers
  in other EU countries follow the VAT rules of each country (OSS).
- **Invoices.** Portugal requires certified invoicing software or the
  Portal das Finanças. A plain Stripe receipt is not a Portuguese invoice.
- **Who sells: a Merchant of Record (recommended).** Paddle or Lemon
  Squeezy (about 5 % + €0.50 per payment; check current prices) sell to
  the customer in their own name. They handle VAT, invoices, refunds and
  the customer portal, and pay out monthly. Rafael then invoices one
  company instead of every customer.
- **Stripe** is cheaper per payment (about 1.5 % + €0.25 for EU cards)
  and takes Multibanco. With Stripe, the VAT, the certified invoices and
  the refunds are Rafael's work.
- **MB WAY** is what Portuguese buyers expect. Few Merchants of Record
  offer it. Portuguese gateways (ifthenpay, Eupago, easypay) do, but
  without the VAT and invoice handling.

### 1.3 Consumer law and privacy (check)

- **Terms of use and a privacy policy** (GDPR). The policy has to cover
  the accounts' emails, home places, notes and devices, and name the
  processors: Supabase, Cloudflare, GitHub and Google Firebase.
- **Account deletion** by the person (today only admins remove accounts).
- **Livro de Reclamações Eletrónico** (Decreto-Lei 74/2017): a link on the
  site.
- **Dispute resolution.** Consumers must be told which out-of-court body
  (RAL entity) handles disputes (Lei 144/2015).
- **Prices shown with VAT.**
- **14-day withdrawal right** (Decreto-Lei 24/2014). The checkout asks for
  consent to start at once. A pro-rata refund may still be due.

### 1.4 What paying people need from the service

- **Supabase Pro**, about $25 a month. The free plan pauses idle projects,
  keeps no backups and stops at 500 MB. Paying users need daily backups.
- **A domain of its own**, about €10–15 a year.
- **Email for sign-up and password reset.** A transactional email
  service's free tier covers a few thousand emails a month.
- **GitHub Actions** stays free only while the repository is public.
  Private, it gets 2 000 minutes a month. Decide the repository's
  visibility and licence: with a public repository, anyone can run their
  own copy.
- **More users mean more models, and more models mean more requests.**
  Every model someone follows is collected for everyone. Free accounts
  get few models (2), and the fewer-requests work (roadmap R) comes
  before any growth.
- **Break-even:** about 7 Pro subscribers, or 4 passes a month, cover
  Supabase Pro after VAT and fees (section 4).

## 2. What people pay for

A bike is bought once every few years, for €5 000–10 000, and a good deal
saves hundreds of euros. People pay for **time** (seeing the good ad
first) and **money in the negotiation**. A monthly subscription tends to
end with the purchase. The main product is therefore a **purchase pass**
for the weeks of a search. A monthly plan serves enthusiasts and people
who buy and resell bikes.

**Rule: the scores and their explanations stay free.** Seeing why an ad
is or isn't a good deal is what makes people trust the app and share it.
Paid plans sell speed, scale and the buying tools. A score is never for
sale, and neither is a place in the list.

### 2.1 Features we already have

| Feature (in the app) | Grátis | Pro / Passe |
|---|---|---|
| Ofertas with Deal Score, Risk Score and why | ✅ | ✅ |
| Personalizar cartões dos anúncios (15.31; possible paid extra, not decided) | standard layout | choose the details shown |
| Anúncio: price history, estimate, comparables, risk reasons | ✅ | ✅ |
| Modelos acompanhados | 2 | 10 |
| Pesquisas guardadas | 1 | unlimited |
| Alerts in Alertas and the weekly summary | ✅ | ✅ |
| Notifications on the phone after every collection | weekly summary only | ✅ |
| Favoritos with notes | 5 | unlimited |
| Comparar (3 ads) | ✅ | ✅ |
| Distance from home, Custo de ter esta mota | ✅ | ✅ |
| Quanto oferecer: opening, second offer, ceiling, messages, counter-offer | ⬜ | ✅ |
| Negotiation arguments, Pressa do vendedor, what to ask a dealer | ⬜ | ✅ |
| Para a visita: checklist with repair costs off the offer | checklist only | ✅ |
| Target-price and "back on the market" alerts | ⬜ | ✅ |
| Mercado deste modelo, Comparar modelos (depreciation, time on sale) | ⬜ | ✅ |
| "O stand": dealer figures | score only | ✅ |

**Possible subscription benefit (Rafael, 2026-10-25): card customization.**
The feature is available now to every signed-in account, free: choose the
details shown in Ofertas and Favoritos, with the existing layout as the
default and a reset option. Optional facts include first owner / owner
count, service book, origin, warranties, colour, stand name and the ad's
publication, renewal and first-found dates. If paid plans launch, keeping
the standard layout free and offering the personal choice of fields with
Pro/Passe is an option, not a decision. This does not put scores or
explanations behind a paywall: Deal Score stays on the standard cards, and
the full scores and explanations remain available on listing pages.
No subscription check, payment flow or restriction is implemented by this
feature; the permission and invited-account rules above still apply.

### 2.2 New features worth paying for (⬜)

- **Quanto vale a minha mota** (sellers, a second audience). Model, year
  and km in; out come the estimate from the same comparables, how long
  such bikes take to sell, an asking price and a trade-in floor. It uses
  only our own aggregates.
- **Relatório de um anúncio.** One ad's full analysis as a link to
  share: estimate, history, relists, contradictions, offer plan and
  visit checklist. Sold one at a time, for people who found an ad and
  want a second opinion.
- **Follow any ad by its link.** Paste a Standvirtual or OLX link; it is
  read once and followed even outside one's models. Roadmap "Next" 2
  already plans updating such ads.
- **Import calculator** (Spain, Germany, France). Asking price + ISV for
  motorcycles by engine size, reduced by age for used EU bikes +
  homologation and inspection + transport, set against the Portuguese
  estimate. The tax rules need checking (Código do ISV).
- **Price trends and when to buy** (roadmap 15.8): seasonal prices per
  model. "Prices of this model fall about X % from October to February."
- **More sources:** CustoJusto, then foreign sites for imports. Each one
  needs its terms read, and adds requests.
- **Shared lists.** A couple buying together, or a mechanic friend who
  sees the favourites, notes and checklist.
- **Export** of favourites with notes and checklists, as CSV or PDF.
- **Registration check guidance.** The checklist links to the IRN's
  online vehicle certificate (liens, ownership reservation). It is
  guidance, not a service of ours.

## 3. Other income

| Way | Fit | Note |
|---|---|---|
| **Affiliate links**: insurance, financing, gear (helmets, jackets), inspection, import transport | good | Contextual: the insurance link sits beside "Custo de ter esta mota", gear after a purchase. Always marked "ligação de afiliado"; never part of a score. |
| **Stand plan** (€29–49 a month) | good, later | A dealer's stock against the market: overpriced ads, time to sell, price suggestions. Never placement, never a better score, never hidden risk reasons. |
| **Market report** (quarterly, per model) | maybe | Aggregates only. Sponsors, media, importers. The same data question as 1.1. |
| **Donations** (GitHub Sponsors, Ko-fi) | possible now | No business setup beyond declaring the income. |
| Display ads | no | Small audience. Ads need cookie consent, hurt trust and slow the app. |
| Selling leads to dealers | no | A conflict of interest with the scores. |
| Selling the raw data | no | Not ours to sell (1.1). |

## 4. Prices (to test, not decided)

| Plan | Price (VAT included) | What |
|---|---|---|
| Grátis | €0 | 2.1's free column |
| Pro mensal | €4.99 a month or €39 a year | Everything in 2.1, export, shared list |
| Passe de compra | €9.99 for 60 days, no renewal | Pro for the weeks of a purchase |
| Relatório de um anúncio | €2.99 | One ad's report, for good |
| Quanto vale a minha mota | €2.99, or in Pro | One valuation |
| Stand | €29 (one stand) – €49 a month | Section 3 |

- **Trial:** 14 days of Pro for every new account, no card.
- **Invited accounts and admins** keep Pro for free (plan `convidado`).
- **Small payments lose most to fees and VAT.** Through a Merchant of
  Record the price includes 23 % VAT (the Merchant of Record is the
  seller, whatever Rafael's own exemption), then about 5 % + €0.50 goes
  to fees. What is left:
  - the €2.99 report: about €1.80;
  - Pro mensal (€4.99): about €3.30;
  - the €9.99 pass: about €7.10.

## 5. How it would be built

The steps are in the roadmap's Sprint 16, in this order:

1. 16.0, the decisions above (the data question decided: only with the
   sites' API or licence).
2. Plans and entitlements in the database (16.1).
3. Payments through the Merchant of Record's hosted checkout and a
   webhook (16.2). No card data ever reaches us.
4. Open sign-up (16.3).
5. The "Planos" page (16.4).
6. Legal pages (16.5).
7. Metrics without trackers (16.6).
8. Infrastructure (16.7).
9. The new paid features (16.8–16.12).

The fewer-requests work (roadmap R) comes first, so more accounts don't
mean many more requests to the sites.
