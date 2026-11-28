import '../../../app/theme/app_colors.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/formatting/name_search.dart';
import '../../../core/localization/localizations.dart';
import '../../../core/platform/app_build.dart';
import '../../favourites/domain/entities/favourite.dart';
import '../../favourites/presentation/viewing_checklist.dart';
import '../../market/domain/entities/market_behaviour.dart';
import '../domain/entities/listing.dart';
import 'listing_card_text.dart';
import 'listing_detail_text.dart';
import 'listing_labels.dart';
import 'listing_report.dart';
import 'negotiation_text.dart';
import 'offer_text.dart';
import 'recall_text.dart';
import 'score_breakdown_text.dart';
import 'score_explanation.dart';

export 'listing_report.dart';

/// "Relatório do anúncio" (16.8, N.127): the ad's whole analysis in
/// parts, to send to a mechanic or to whoever goes to see the bike with
/// you, as a PDF or as plain text ([listingReportText]). Built from what
/// the ad's page already says: the bike, the Deal Score and its reasons,
/// the Risk Score, the market, the offer plan (after the visit when the
/// checklist has problems), the checklist's marks with their notes, the
/// EU recalls that can cover the bike, the Deal Score's sums and the
/// seller's ad's address. Sections without anything to say are left out.
/// Never the private note.
ListingReport listingReportOf(
  Listing listing, {
  required DateTime today,
  MarketBehaviour? market,
  List<Listing> cheaper = const [],
  Map<String, ChecklistEntry> checklist = const {},
  AppLanguage language = .portuguese,
}) {
  final m = language.messages;
  final explanation = ScoreExplainer.explain(
    listing,
    today: today,
    language: language,
  );
  final colours = AppColors.light;
  final ad = adAddress(listing);
  return ListingReport(
    title: m.reportTitle(bike: listing.nameAndYear),
    madeOn: m.reportMadeOn(date: Formatters.date(today), app: appName),
    eyebrow: m.listingReport,
    bike: listing.name,
    year: listing.year,
    priceName: m.askingPriceLabel,
    price: listing.priceLabel(language: language),
    specs: heroSpecs(listing, language: language),
    about: [
      ?sellerText(listing, language: language),
      ?placeText(listing, language: language),
      if (listing.isRemoved || listing.status == .sold)
        '${m.listingStatus}: ${listing.status.label(language: language)}',
    ],
    deal: explanation == null
        ? null
        : ReportScore(
            name: m.dealScore,
            figure: explanation.score,
            band: explanation.label,
            line: m.reportDealScore(
              score: explanation.score,
              band: explanation.label,
            ),
            colour: colours.score(explanation.score).toARGB32(),
          ),
    risk: switch (listing.riskScore) {
      final risk? => ReportScore(
        name: m.riskScore,
        figure: risk,
        band: ScoreExplainer.riskLabel(risk, language: language),
        line: m.reportRiskScore(
          score: risk,
          band: ScoreExplainer.riskLabel(risk, language: language),
        ),
        colour:
            (risk >= 50
                    ? colours.scorePoor
                    : risk >= 20
                    ? colours.scoreInteresting
                    : colours.scoreExcellent)
                .toARGB32(),
      ),
      null => null,
    },
    notScored: m.reportNotScored,
    notScoredShort: m.reportPdfNotScored,
    reasonsTitle: m.whyThisScore,
    reasons: [
      for (final line in explanation?.lines ?? const <ExplanationLine>[])
        ReportLine(line.text, tone: _tone(line.tone)),
    ],
    sections: [
      ?_market(listing, language),
      ?_offer(listing, today, market, cheaper, checklist, language),
      ?_visit(listing, checklist, language),
      ?_recalls(listing, language),
    ],
    breakdownTitle: m.scoreBreakdownTitle,
    breakdown: scoreBreakdownOf(listing, language: language),
    note: m.reportAskingPricesNote,
    adLine: ad == null ? null : m.originalAdAddress(url: '$ad'),
    adUrl: ad?.toString(),
    onApp: m.onApp(app: appName),
  );
}

/// The PDF's file name: "relatorio-yamaha-mt-07-2021.pdf".
String reportFileName(Listing listing, {AppLanguage language = .portuguese}) =>
    '${language.messages.reportFileName}-'
    '${fileNamePart(listing.nameAndYear)}.pdf';

/// The report as plain text, for a message or an email: it ends as
/// [listingShareText] does, so the app's link sent after it reads as its
/// last line.
String listingReportText(
  Listing listing, {
  required DateTime today,
  MarketBehaviour? market,
  List<Listing> cheaper = const [],
  Map<String, ChecklistEntry> checklist = const {},
  AppLanguage language = .portuguese,
}) {
  final report = listingReportOf(
    listing,
    today: today,
    market: market,
    cheaper: cheaper,
    checklist: checklist,
    language: language,
  );
  final sections = <List<String>>[
    [report.title, report.madeOn],
    [
      [...report.specs, report.price].join(' · '),
      ...report.about,
    ],
    [
      if (report.deal case final deal?) ...[
        deal.line,
        for (final line in report.reasons) _textLine(line),
      ] else
        report.notScored,
      ?report.risk?.line,
    ],
    for (final section in report.sections)
      [section.title, for (final line in section.lines) _textLine(line)],
    [report.note, ?report.adLine, report.onApp],
  ];
  return [
    for (final section in sections)
      if (section.isNotEmpty) section.join('\n'),
  ].join('\n\n');
}

String _textLine(ReportLine line) => switch (line) {
  ReportLine(heading: true) => line.text,
  ReportLine(:final value?) => '· ${line.text}: $value',
  ReportLine(:final tone?) => reportLine(tone, line.text),
  _ => line.text,
};

ReportTone _tone(ExplanationTone tone) => switch (tone) {
  .positive => .positive,
  .negative => .negative,
  .neutral => .neutral,
};

/// A line of a list in the report: "+ " good, "− " bad, "· " neither.
String reportLine(ReportTone tone, String text) => switch (tone) {
  .positive => '+ $text',
  .negative => '− $text',
  .neutral => '· $text',
};

ReportSection? _market(Listing listing, AppLanguage language) {
  final lines = [
    ?cardMarketPositionText(listing, language: language),
    ?estimatedValueText(listing, language: language),
    ?comparablesText(listing, language: language),
  ];
  return lines.isEmpty
      ? null
      : ReportSection(language.messages.reportMarket, [
          for (final line in lines) ReportLine(line),
        ]);
}

ReportSection? _offer(
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
  if (planned == null) return null;
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
  return ReportSection(language.messages.howMuchToOffer, [
    ReportLine(offer.headline(language: language)),
    for (final step in offer.steps(language: language))
      ReportLine(
        step.label,
        value: Formatters.price(step.price, language: language),
      ),
    if (arguments.isNotEmpty) ...[
      ReportLine(language.messages.reportArguments, heading: true),
      for (final argument in arguments) ReportLine(argument, tone: .neutral),
    ],
  ]);
}

/// The checklist's marked or noted items in list order, problems first.
ReportSection? _visit(
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
  if (items.isEmpty) return null;
  ReportLine line((ChecklistItem, ChecklistEntry) marked) {
    final (item, entry) = marked;
    final note = entry.note?.trim();
    final text = note == null || note.isEmpty
        ? item.title
        : '${item.title}: $note';
    return ReportLine(
      text,
      tone: switch (entry.mark) {
        ChecklistMark.issue => .negative,
        ChecklistMark.ok => .positive,
        null => .neutral,
      },
    );
  }

  return ReportSection(language.messages.reportVisit, [
    for (final mark in [ChecklistMark.issue, ChecklistMark.ok, null])
      for (final marked in items.where((marked) => marked.$2.mark == mark))
        line(marked),
  ]);
}

ReportSection? _recalls(Listing listing, AppLanguage language) {
  final lines = recallLines(
    listing.recalls,
    applying: true,
    language: language,
  );
  if (lines.isEmpty) return null;
  return ReportSection(language.messages.reportRecalls, [
    for (final recall in lines)
      ReportLine('${recall.title} (${recall.facts})', tone: .neutral),
  ]);
}
