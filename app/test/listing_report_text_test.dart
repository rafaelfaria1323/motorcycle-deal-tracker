import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/app/theme/app_colors.dart';
import 'package:motorcycle_deal_tracker/app/theme/app_theme.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/favourites/domain/entities/favourite.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/vehicle_recall.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/listing_report.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/listing_report_pdf.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/listing_report_text.dart';

final _today = DateTime(2026, 11, 14);

Listing _listing({
  int? dealScore = 82,
  int? riskScore = 20,
  double? price = 6500,
  double? estimate = 7000,
  List<VehicleRecall> recalls = const [],
}) => Listing(
  id: 'l1',
  source: 'olx',
  url: 'https://www.olx.pt/d/anuncio/mt-07-IDabc.html',
  brand: 'Yamaha',
  model: 'MT-07',
  year: 2021,
  mileage: 12000,
  status: ListingStatus.active,
  sellerType: SellerType.private,
  images: const [],
  firstSeenAt: DateTime(2026, 11, 1),
  lastSeenAt: null,
  price: price,
  initialPrice: price,
  dealScore: dealScore,
  riskScore: riskScore,
  recalls: recalls,
  scoreBreakdown: estimate == null
      ? null
      : {'market_price': estimate, 'market_listing_count': 12},
);

VehicleRecall _recall(String name, {required bool applies}) => VehicleRecall(
  caseNumber: name,
  publishedOn: DateTime(2026, 3, 1),
  name: name,
  alertUrl: 'https://ec.europa.eu/safety-gate-alerts/$name',
  applies: applies,
);

void main() {
  test('reportLine marks good, bad and neutral lines', () {
    expect(reportLine(ReportTone.positive, 'a'), '+ a');
    expect(reportLine(ReportTone.negative, 'b'), '− b');
    expect(reportLine(ReportTone.neutral, 'c'), '· c');
  });

  test('starts with the bike and the date and ends with the app', () {
    final text = listingReportText(_listing(), today: _today);
    final lines = text.split('\n');
    expect(lines.first, 'Relatório: Yamaha MT-07 · 2021');
    expect(lines[1], contains('14/11/2026'));
    expect(lines.last, 'No Motorcycle Deal Tracker:');
    expect(text, contains('Anúncio original: https://www.olx.pt/'));
    expect(text, contains('Deal Score: 82/100'));
    expect(text, contains('Risk Score: 20/100'));
    // Sections are separated by one blank line, never more.
    expect(text, isNot(contains('\n\n\n')));
  });

  test('a bike without a score says so and has no offer', () {
    final text = listingReportText(
      _listing(dealScore: null, estimate: null),
      today: _today,
    );
    expect(text, contains('Deal Score: ainda sem pontuação'));
    expect(text, isNot(contains('Quanto oferecer')));
    expect(text, isNot(contains('Mercado\n')));
  });

  test('has the offer plan when there is an estimate', () {
    final text = listingReportText(_listing(), today: _today);
    expect(text, contains('Quanto oferecer'));
    expect(RegExp(r'^· .+: .*€', multiLine: true).hasMatch(text), isTrue);
  });

  test('lists the checklist with problems first and the notes', () {
    final text = listingReportText(
      _listing(),
      today: _today,
      checklist: const {
        'documents': ChecklistEntry(mark: ChecklistMark.ok),
        'keys': ChecklistEntry(mark: ChecklistMark.issue, note: 'só uma'),
        'service': ChecklistEntry(),
      },
    );
    final visit = text
        .split('\n\n')
        .firstWhere((section) => section.startsWith('Na visita'));
    final lines = visit.split('\n');
    expect(lines, hasLength(3));
    expect(lines[1], startsWith('− '));
    expect(lines[1], endsWith(': só uma'));
    expect(lines[2], startsWith('+ '));
  });

  test('without checklist marks there is no visit section', () {
    final text = listingReportText(_listing(), today: _today);
    expect(text, isNot(contains('Na visita')));
  });

  test('lists only the recalls that can cover the bike', () {
    final text = listingReportText(
      _listing(
        recalls: [
          _recall('Travões', applies: true),
          _recall('Outra', applies: false),
        ],
      ),
      today: _today,
    );
    expect(text, contains('Chamadas à oficina (UE)'));
    expect(text, contains('· Travões ('));
    expect(text, isNot(contains('Outra')));
  });

  test('is written in English when asked', () {
    final text = listingReportText(
      _listing(),
      today: _today,
      language: AppLanguage.english,
    );
    expect(text, startsWith('Report: Yamaha MT-07 · 2021'));
    expect(text, contains('How much to offer'));
    expect(text.split('\n').last, 'On Motorcycle Deal Tracker:');
  });

  test('the report in parts has the bike, the scores and the sections', () {
    final report = listingReportOf(_listing(), today: _today);
    expect(report.title, 'Relatório: Yamaha MT-07 · 2021');
    expect(report.bike, 'Yamaha MT-07');
    expect(report.year, 2021);
    expect(report.deal?.figure, 82);
    expect(report.deal?.colour, AppColors.light.score(82).toARGB32());
    expect(report.risk?.figure, 20);
    expect(report.adUrl, 'https://www.olx.pt/d/anuncio/mt-07-IDabc.html');
    expect(report.notScoredShort, 'Ainda sem pontuação');
    expect([
      for (final section in report.sections) section.title,
    ], containsAllInOrder(['Mercado', 'Quanto oferecer']));
    final offer = report.sections.firstWhere(
      (section) => section.title == 'Quanto oferecer',
    );
    expect(offer.lines.where((line) => line.value != null), isNotEmpty);
  });

  test('an unscored bike has no score tiles to fill', () {
    final report = listingReportOf(
      _listing(dealScore: null, riskScore: null, estimate: null),
      today: _today,
    );
    expect(report.deal, isNull);
    expect(report.risk, isNull);
    expect(report.breakdown, isNull);
    expect(report.reasons, isEmpty);
  });

  test('the PDF is named after the bike in the language', () {
    expect(reportFileName(_listing()), 'relatorio-yamaha-mt-07-2021.pdf');
    expect(
      reportFileName(_listing(), language: AppLanguage.english),
      'report-yamaha-mt-07-2021.pdf',
    );
  });

  test('the PDF is made with the app fonts, scored or not', () async {
    ByteData font(String name) =>
        ByteData.sublistView(File('assets/fonts/$name.ttf').readAsBytesSync());
    final fonts = ReportFonts(
      regular: font('Barlow-Regular'),
      medium: font('Barlow-Medium'),
      semiBold: font('Barlow-SemiBold'),
      display: font('BarlowSemiCondensed-Bold'),
    );
    final scheme = AppTheme.light.colorScheme;
    final palette = ReportPalette(
      primary: scheme.primary.toARGB32(),
      ink: scheme.onSurface.toARGB32(),
      muted: scheme.onSurfaceVariant.toARGB32(),
      hairline: scheme.outlineVariant.toARGB32(),
      panel: scheme.surfaceContainer.toARGB32(),
      positive: AppColors.light.positive.toARGB32(),
      negative: AppColors.light.negative.toARGB32(),
      onBand: AppColors.onPhoto.toARGB32(),
    );
    Future<String> pdf(ListingReport report) async => latin1.decode(
      await listingReportPdf(
        report,
        fonts: fonts,
        palette: palette,
        appUrl: 'https://example.test/#/deals/l1',
        appName: 'Motorcycle Deal Tracker',
      ),
    );
    for (final listing in [
      _listing(recalls: [_recall('Travões', applies: true)]),
      _listing(dealScore: null, riskScore: null, estimate: null),
    ]) {
      final text = await pdf(
        listingReportOf(
          listing,
          today: _today,
          checklist: const {
            'keys': ChecklistEntry(mark: ChecklistMark.issue, note: 'só uma'),
          },
        ),
      );
      expect(text, startsWith('%PDF-'));
      expect(text.trimRight(), endsWith('%%EOF'));
      // Both links can be opened from the PDF.
      expect(text, contains('/URI(https://www.olx.pt/d/anuncio/mt-07'));
      expect(text, contains('example.test/#/deals/l1'));
    }
  });
}
