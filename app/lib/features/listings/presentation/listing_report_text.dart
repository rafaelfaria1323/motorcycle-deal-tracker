import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import '../../../core/platform/app_build.dart';
import '../../favourites/domain/entities/favourite.dart';
import '../../favourites/presentation/viewing_checklist.dart';
import '../../market/domain/entities/market_behaviour.dart';
import '../domain/entities/listing.dart';
import 'listing_card_text.dart';
import 'listing_detail_text.dart';
import 'listing_labels.dart';
import 'negotiation_text.dart';
import 'offer_text.dart';
import 'recall_text.dart';
import 'score_explanation.dart';

/// "Relatório do anúncio" (16.8): the ad's whole analysis as plain text,
/// to send to a mechanic or to whoever goes to see the bike with you, in
/// a message or an email. Built from what the ad's page already says:
/// the bike, the Deal Score and its reasons, the Risk Score, the market,
/// the offer plan (after the visit when the checklist has problems), the
/// checklist's marks with their notes, the EU recalls that can cover the
/// bike, and the seller's ad's address; it ends as [listingShareText]
/// does, so the app's link sent after it reads as its last line.
/// Sections without anything to say are left out. Never the private
/// note.
String listingReportText(
  Listing listing, {
  required DateTime today,
  MarketBehaviour? market,
  List<Listing> cheaper = const [],
  Map<String, ChecklistEntry> checklist = const {},
  AppLanguage language = .portuguese,
}) {
  final m = language.messages;
  final sections = <List<String>>[
    [
      m.reportTitle(bike: listing.nameAndYear),
      m.reportMadeOn(date: Formatters.date(today), app: appName),
    ],
    _bike(listing, language),
    _scores(listing, today, language),
    _market(listing, language),
    _offer(listing, today, market, cheaper, checklist, language),
    _visit(listing, checklist, language),
    _recalls(listing, language),
    [
      m.reportAskingPricesNote,
      if (adAddress(listing) case final ad?)
        m.originalAdAddress(url: '$ad'),
      m.onApp(app: appName),
    ],
  ];
  return [
    for (final section in sections)
      if (section.isNotEmpty) section.join('\n'),
  ].join('\n\n');
}

/// A line of a list in the report: "+ " good, "− " bad, "· " neither.
String reportLine(ExplanationTone tone, String text) => switch (tone) {
  .positive => '+ $text',
  .negative => '− $text',
  .neutral => '· $text',
};

List<String> _bike(Listing listing, AppLanguage language) => [
  [
    ...heroSpecs(listing, language: language),
    listing.priceLabel(language: language),
  ].join(' · '),
  if (sellerText(listing, language: language) case final seller?) seller,
  if (placeText(listing, language: language) case final place?) place,
  if (listing.isRemoved || listing.status == .sold)
    '${language.messages.listingStatus}: '
        '${listing.status.label(language: language)}',
];

List<String> _scores(Listing listing, DateTime today, AppLanguage language) {
  final m = language.messages;
  final explanation = ScoreExplainer.explain(
    listing,
    today: today,
    language: language,
  );
  return [
    if (explanation == null)
      m.reportNotScored
    else ...[
      m.reportDealScore(
        score: explanation.score,
        band: explanation.label,
      ),
      for (final line in explanation.lines) reportLine(line.tone, line.text),
    ],
    if (listing.riskScore case final risk?)
      m.reportRiskScore(
        score: risk,
        band: ScoreExplainer.riskLabel(risk, language: language),
      ),
  ];
}

List<String> _market(Listing listing, AppLanguage language) {
  final lines = [
    ?cardMarketPositionText(listing, language: language),
    ?estimatedValueText(listing, language: language),
    ?comparablesText(listing, language: language),
  ];
  return lines.isEmpty ? const [] : [language.messages.reportMarket, ...lines];
}

List<String> _offer(
  Listing listing,
  DateTime today,
  MarketBehaviour? market,
  List<Listing> cheaper,
  Map<String, ChecklistEntry> checklist,
  AppLanguage language,
) {
  final days = daysOnSale(listing, now: today);
  final planned = suggestOffer(
    listing,
    market: market,
    daysListed: days,
    language: language,
  );
  if (planned == null) return const [];
  final visit = listingVisitFindings(listing, checklist, language: language);
  final offer = afterVisit(planned, visit, language: language);
  final arguments = negotiationArguments(
    listing,
    market: market,
    daysListed: days,
    cheaper: cheaper,
    visit: visit,
    today: today,
    language: language,
  );
  return [
    language.messages.howMuchToOffer,
    offer.headline(language: language),
    for (final step in offer.steps(language: language))
      '· ${step.label}: ${Formatters.price(step.price, language: language)}',
    if (arguments.isNotEmpty) ...[
      language.messages.reportArguments,
      for (final argument in arguments) '· $argument',
    ],
  ];
}

/// The checklist's marked or noted items in list order, problems first.
List<String> _visit(
  Listing listing,
  Map<String, ChecklistEntry> checklist,
  AppLanguage language,
) {
  final items = [
    for (final item in viewingChecklistItems(
      language: language,
      listing: listing,
    ))
      if (checklist[item.key] case final entry? when !entry.isEmpty)
        (item, entry),
  ];
  if (items.isEmpty) return const [];
  String line((ChecklistItem, ChecklistEntry) marked) {
    final (item, entry) = marked;
    final note = entry.note?.trim();
    final text = note == null || note.isEmpty
        ? item.title
        : '${item.title}: $note';
    return reportLine(switch (entry.mark) {
      ChecklistMark.issue => .negative,
      ChecklistMark.ok => .positive,
      null => .neutral,
    }, text);
  }

  final sorted = [
    for (final mark in [ChecklistMark.issue, ChecklistMark.ok, null])
      ...items.where((marked) => marked.$2.mark == mark),
  ];
  return [language.messages.reportVisit, for (final item in sorted) line(item)];
}

List<String> _recalls(Listing listing, AppLanguage language) {
  final lines = recallLines(
    listing.recalls,
    applying: true,
    language: language,
  );
  if (lines.isEmpty) return const [];
  return [
    language.messages.reportRecalls,
    for (final recall in lines) '· ${recall.title} (${recall.facts})',
  ];
}
