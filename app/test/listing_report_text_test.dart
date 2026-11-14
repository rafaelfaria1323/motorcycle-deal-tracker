import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/favourites/domain/entities/favourite.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/vehicle_recall.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/listing_report_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/score_explanation.dart';

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
    expect(reportLine(ExplanationTone.positive, 'a'), '+ a');
    expect(reportLine(ExplanationTone.negative, 'b'), '− b');
    expect(reportLine(ExplanationTone.neutral, 'c'), '· c');
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
    final visit = text.split('\n\n').firstWhere(
      (section) => section.startsWith('Na visita'),
    );
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
}
