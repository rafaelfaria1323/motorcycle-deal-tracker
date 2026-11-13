import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/vehicle_recall.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/recall_text.dart';

VehicleRecall _recall({
  String caseNumber = 'SR/4/26',
  bool applies = true,
  String name = 'Honda CBR650R',
  String alertUrl =
      'https://ec.europa.eu/safety-gate-alerts/screen/webReport/alertDetail/1',
  String? productionDates = '2019-2021',
  String? recallCode = 'MC-123',
  String? dangerEn = 'The chain may break.',
  String? dangerPt = 'A corrente pode partir.',
  String? countryEn = 'Spain',
  String? countryPt = 'Espanha',
}) => VehicleRecall(
  caseNumber: caseNumber,
  publishedOn: DateTime(2026, 3, 12),
  name: name,
  alertUrl: alertUrl,
  applies: applies,
  productionDates: productionDates,
  recallCode: recallCode,
  dangerEn: dangerEn,
  dangerPt: dangerPt,
  countryEn: countryEn,
  countryPt: countryPt,
);

void main() {
  test('a recall in Portuguese and in English', () {
    final pt = recallLine(_recall());
    expect(pt.title, 'Honda CBR650R');
    expect(pt.danger, 'A corrente pode partir.');
    expect(
      pt.facts,
      'Produção: 2019-2021 · Código MC-123 · Espanha, 12/03/2026',
    );
    expect(pt.link?.host, 'ec.europa.eu');

    final en = recallLine(_recall(), language: AppLanguage.english);
    expect(en.danger, 'The chain may break.');
    expect(en.facts, 'Production: 2019-2021 · Code MC-123 · Spain, 12/03/2026');
  });

  test('missing Portuguese falls back to English; blanks are left out', () {
    final line = recallLine(
      _recall(
        name: ' ',
        dangerPt: null,
        countryPt: '',
        productionDates: '  ',
        recallCode: null,
      ),
    );
    expect(line.title, 'Recolha');
    expect(line.danger, 'The chain may break.');
    expect(line.facts, 'Spain, 12/03/2026');
    expect(
      recallLine(
        _recall(
          dangerEn: null,
          dangerPt: null,
          countryEn: null,
          countryPt: null,
        ),
      ).facts,
      endsWith('· 12/03/2026'),
    );
    expect(recallLine(_recall(dangerEn: null, dangerPt: null)).danger, isNull);
  });

  test('only https alerts can be opened', () {
    expect(recallLine(_recall(alertUrl: 'http://ec.europa.eu/x')).link, isNull);
    expect(recallLine(_recall(alertUrl: 'javascript:alert(1)')).link, isNull);
  });

  test('the lines that apply, or the model\'s others, in order', () {
    final recalls = [
      _recall(caseNumber: 'a'),
      _recall(caseNumber: 'b', applies: false, name: 'Honda CB650R'),
      _recall(caseNumber: 'c', name: 'Honda CBR650R ABS'),
    ];
    expect(recallLines(recalls, applying: true).map((l) => l.title), [
      'Honda CBR650R',
      'Honda CBR650R ABS',
    ]);
    expect(recallLines(recalls, applying: false).map((l) => l.title), [
      'Honda CB650R',
    ]);
    expect(recallLines(const [], applying: true), isEmpty);
  });

  test('the checklist asks for the recall by its code, else its date', () {
    final item = recallChecklistText(_recall());
    expect(item.title, 'Recolha MC-123 feita?');
    expect(item.hint, startsWith('A corrente pode partir. Peça'));
    expect(
      recallChecklistText(
        _recall(recallCode: null, dangerEn: null, dangerPt: null),
      ),
      (
        title: 'Recolha 12/03/2026 feita?',
        hint:
            'Peça o comprovativo da intervenção, ou pergunte num '
            'concessionário da marca com o número de quadro.',
      ),
    );
    expect(
      recallChecklistText(_recall(), language: AppLanguage.english).title,
      'Recall MC-123 done?',
    );
  });
}
