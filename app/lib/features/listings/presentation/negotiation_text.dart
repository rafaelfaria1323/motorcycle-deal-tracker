import '../../../core/formatting/formatters.dart';
import '../domain/entities/favourite.dart';
import '../domain/entities/listing.dart';
import '../domain/entities/market_behaviour.dart';
import 'market_behaviour_text.dart';
import 'offer_text.dart';
import 'ownership_cost.dart';
import 'score_explanation.dart';
import 'viewing_checklist.dart';

/// A problem marked at the visit and what fixing it typically costs.
class VisitRepair {
  const VisitRepair(this.title, this.cost);

  final String title;
  final double cost;
}

/// What the viewing checklist found: problems with a repair cost, and
/// problems that stop the deal until they are cleared up.
class VisitFindings {
  const VisitFindings({this.repairs = const [], this.blockers = const []});

  final List<VisitRepair> repairs;
  final List<String> blockers;

  double get total => repairs.fold(0, (sum, r) => sum + r.cost);

  bool get isEmpty => repairs.isEmpty && blockers.isEmpty;

  /// "pneus (~300 €), corrente e cremalheira (~200 €)".
  String get repairsText => repairs
      .map((r) => '${r.title.toLowerCase()} (~${Formatters.price(r.cost)})')
      .join(', ');
}

/// Checklist items whose problem is no matter of price: papers that don't
/// match, a debt on the bike, an engine or gearbox that needs a mechanic.
const visitBlockers = {'documents', 'registry', 'cold_start', 'test_ride'};

/// The typical cost of fixing a problem marked on [key] (workshop prices,
/// 2026), from the bike's running costs where they apply. Null for items
/// with no fixed price (the blockers).
double? repairCost(String key, RunningCostTable costs) => switch (key) {
  'tyres' => costs.tyreSet,
  'chain' => costs.chainKit,
  'service' => costs.service,
  'brakes' => 150,
  'suspension' => 200,
  'fall' => 150,
  'keys' => 120,
  'electrics' => 80,
  _ => null,
};

/// The problems marked in [checklist], in list order.
VisitFindings visitFindings(
  Map<String, ChecklistEntry> checklist, {
  int? engineCc,
}) {
  final costs = runningCostsFor(engineCc);
  final repairs = <VisitRepair>[];
  final blockers = <String>[];
  for (final item in viewingChecklistItems) {
    if (checklist[item.key]?.mark != ChecklistMark.issue) continue;
    if (visitBlockers.contains(item.key)) {
      blockers.add(item.title);
    } else if (repairCost(item.key, costs) case final cost?) {
      repairs.add(VisitRepair(item.title, cost));
    }
  }
  return VisitFindings(repairs: repairs, blockers: blockers);
}

/// The offer after the visit: the repairs come off both the opening and
/// the most to pay. Unchanged without repairs.
OfferSuggestion afterVisit(OfferSuggestion offer, VisitFindings findings) {
  if (findings.repairs.isEmpty) return offer;
  return offer.lowerBy(
    findings.total,
    'Na visita: ${findings.repairsText}. Isso sai da proposta e do máximo.',
  );
}

/// Tyres this old are probably due, unless the ad says they are new.
const oldTyresYears = 5;

/// What to say to the seller to justify a lower price, strongest first,
/// from what we know of this bike and its market. [cheaper] are live
/// listings of the same model, of a similar year and not more km, that
/// cost less; [visit] what the viewing checklist found.
List<String> negotiationArguments(
  Listing listing, {
  MarketBehaviour? market,
  int? daysListed,
  List<Listing> cheaper = const [],
  VisitFindings? visit,
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final price = listing.price;
  final data = listing.scoreBreakdown ?? const <String, dynamic>{};
  final arguments = <String>[];

  if (visit != null && visit.repairs.isNotEmpty) {
    arguments.add(
      'Viu na visita: ${visit.repairsText}. São '
      '${Formatters.price(visit.total)} que vai ter de gastar.',
    );
  }

  final estimate = (data['market_price'] as num?)?.toDouble();
  final comparables = (data['market_listing_count'] as num?)?.toInt();
  if (price != null &&
      estimate != null &&
      estimate > 0 &&
      (comparables ?? minComparables) >= minComparables &&
      price > estimate * 1.03) {
    arguments.add(
      'Está ${Formatters.percent((price / estimate - 1) * 100)} '
      '(${Formatters.price(price - estimate)}) acima do valor de mercado '
      'para o ano e os quilómetros (${Formatters.price(estimate)}).',
    );
  }

  if (cheaper.isNotEmpty) {
    final cheapest = cheaper
        .map((l) => l.price)
        .whereType<double>()
        .fold<double?>(null, (a, b) => a == null || b < a ? b : a);
    if (cheapest != null) {
      arguments.add(
        cheaper.length == 1
            ? 'Há outra ${listing.model} de ano parecido, sem mais km, por '
                  '${Formatters.price(cheapest)}.'
            : 'Há ${cheaper.length} ${listing.model} de ano parecido, sem '
                  'mais km, mais baratas: desde ${Formatters.price(cheapest)}.',
      );
    }
  }

  final km = listing.mileage;
  final year = listing.year;
  if (km != null && year != null) {
    final normal = expectedMileage(year, decimalYear(now));
    if (km > normal * 1.1) {
      arguments.add(
        'Tem ${Formatters.mileage(km)}, acima do normal para uma mota de '
        '$year (cerca de ${Formatters.mileage(normal)}).',
      );
    }
  }

  final reasons = (data['risk_reasons'] as List? ?? const []).toSet();
  for (final (code, text) in _riskArguments) {
    if (reasons.contains(code)) arguments.add(text);
  }
  if (reasons.contains('relisted') || reasons.contains('relisted_often')) {
    arguments.add('Já esteve à venda noutro anúncio e não se vendeu.');
  }

  if (daysListed != null) {
    final typical =
        market != null &&
            market.goneCount >= minMarketData &&
            market.medianDaysToGone != null
        ? market.medianDaysToGone!
        : null;
    if (daysListed > (typical ?? defaultLongListingDays)) {
      arguments.add(
        typical == null
            ? 'Está à venda há $daysListed dias.'
            : 'Está à venda há $daysListed dias; uma mota destas costuma '
                  'sair em $typical.',
      );
    }
  }

  final initial = listing.initialPrice;
  if (price != null && initial != null && initial > price) {
    arguments.add(
      'Já baixou de ${Formatters.price(initial)} para '
      '${Formatters.price(price)}: quer vender.',
    );
  }

  final extras = data['extras'] as List? ?? const [];
  if (year != null &&
      now.year - year >= oldTyresYears &&
      !extras.contains('new_tyres') &&
      visit?.repairs.any((r) => r.title == 'Pneus') != true) {
    arguments.add(
      'Com ${now.year - year} anos, se os pneus forem os de origem precisam '
      'de troca (~${Formatters.price(runningCostsFor(listing.engineCc).tyreSet)}).',
    );
  }

  return arguments;
}

const _riskArguments = [
  (
    'no_service_book',
    'Não tem o livro de revisões completo: o que faltar fica por sua conta.',
  ),
  ('many_owners', 'Já teve 3 ou mais donos.'),
  ('imported', 'É importada: vale menos quando a vender.'),
  (
    'text_mileage_mismatch',
    'A descrição fala em mais quilómetros do que o anúncio indica.',
  ),
  ('text_year_mismatch', 'O ano na descrição não bate certo com o do anúncio.'),
];

/// Ready to send when making the offer [amount] (the first or a second
/// one).
String offerMessage(double amount) =>
    'Obrigado pela resposta. Se estiver tudo como descrito, consigo chegar '
    'aos ${Formatters.price(amount)}, com pagamento na hora. Pode ser?';

/// Ready to send with the most you will pay.
String lastOfferMessage(double amount) =>
    'Compreendo. A minha última proposta é ${Formatters.price(amount)}: '
    'é o máximo que consigo pagar por ela. Se mudar de ideias, diga-me.';

/// Ready to send when taking the seller's price.
String acceptMessage(double amount) =>
    'Combinado, ${Formatters.price(amount)}. Quando e onde podemos tratar '
    'do negócio?';

/// Ready to send when it doesn't work out: polite, and leaves the door open.
const walkAwayMessage =
    'Obrigado pelo seu tempo. Por esse valor não consigo; se baixar o '
    'preço, diga-me.';

enum Urgency { low, medium, high }

/// How keen the seller seems to be to sell, from what the ads show, with
/// the reasons ("à venda há 90 dias", "já baixou o preço").
class SellerUrgency {
  const SellerUrgency(this.level, this.reasons);

  final Urgency level;
  final List<String> reasons;

  /// "Pressa do vendedor: alta (à venda há 90 dias, já baixou o preço)".
  String get text {
    final label = switch (level) {
      Urgency.high => 'alta',
      Urgency.medium => 'média',
      Urgency.low => 'baixa',
    };
    return reasons.isEmpty
        ? 'Pressa do vendedor: $label'
        : 'Pressa do vendedor: $label (${reasons.join(', ')})';
  }
}

/// Points: on sale past the model's typical time (1, 2 past twice it, 3
/// past three times it: that alone is high), an earlier drop (1), put up
/// again after an earlier ad (1, or 2 when often). 3 or more is high, 1-2
/// medium, none low.
SellerUrgency sellerUrgency(
  Listing listing, {
  MarketBehaviour? market,
  int? daysListed,
}) {
  var points = 0;
  final reasons = <String>[];

  final typical =
      market != null &&
          market.goneCount >= minMarketData &&
          market.medianDaysToGone != null
      ? market.medianDaysToGone!
      : defaultLongListingDays;
  if (daysListed != null && daysListed > typical) {
    points += daysListed > 3 * typical
        ? 3
        : daysListed > 2 * typical
        ? 2
        : 1;
    reasons.add('à venda há $daysListed dias');
  }

  final price = listing.price;
  final before = [listing.initialPrice, listing.priceBeforeDrop]
      .whereType<double>()
      .fold<double?>(null, (a, b) => a == null || b > a ? b : a);
  if (price != null && before != null && before > price) {
    points += 1;
    reasons.add('já baixou o preço');
  }

  final risk = (listing.scoreBreakdown?['risk_reasons'] as List? ?? const [])
      .toSet();
  if (risk.contains('relisted_often')) {
    points += 2;
    reasons.add('posta à venda várias vezes');
  } else if (risk.contains('relisted') || listing.relistedFrom != null) {
    points += 1;
    reasons.add('já esteve noutro anúncio');
  }

  final level = points >= 3
      ? Urgency.high
      : points >= 1
      ? Urgency.medium
      : Urgency.low;
  return SellerUrgency(level, reasons);
}

/// A dealer rarely gives much off the price but often adds something: what
/// to ask for instead of (or as well as) a discount. Tyres only on a bike
/// old enough for them to be due, unless the ad says they are new.
List<String> dealerAsks(Listing listing, {DateTime? today}) {
  final year = listing.year;
  final extras = listing.scoreBreakdown?['extras'] as List? ?? const [];
  final tyresDue =
      !extras.contains('new_tyres') &&
      ((year != null && (today ?? DateTime.now()).year - year >= 3) ||
          (listing.mileage ?? 0) >= 10000);
  return [
    'a revisão feita antes da entrega',
    if (tyresDue) 'pneus novos',
    'a garantia por escrito (numa usada vendida por um stand, a lei dá '
        'pelo menos 18 meses)',
    'o registo de propriedade pago por eles',
  ];
}

/// Ready to send to a dealer: the price, and the extras to include.
String dealerMessage(Listing listing, double amount, {DateTime? today}) {
  final asks = dealerAsks(listing, today: today);
  return [
    'Olá, boa tarde.',
    '',
    'Tenho interesse na ${listing.brand} ${listing.model}'
        '${listing.year == null ? '' : ' de ${listing.year}'}. Se fecharmos '
        'por ${Formatters.price(amount)}, consegue incluir:',
    for (final ask in asks) '- $ask;',
    '',
    'Obrigado.',
  ].join('\n');
}
