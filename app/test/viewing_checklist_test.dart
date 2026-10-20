import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/favourite.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/viewing_checklist.dart';

const _ok = ChecklistEntry(mark: ChecklistMark.ok);
const _issue = ChecklistEntry(mark: ChecklistMark.issue);

void main() {
  test('every item has its own key, a title and a hint', () {
    final keys = viewingChecklistItems.map((i) => i.key).toList();
    expect(keys.toSet(), hasLength(keys.length));
    expect(keys, hasLength(12));
    for (final item in viewingChecklistItems) {
      expect(item.key, matches(RegExp(r'^[a-z_]+$')));
      expect(item.title, isNotEmpty);
      expect(item.hint, endsWith('.'));
    }
  });

  group('checklistSummaryText', () {
    test('nothing seen yet says how many points there are', () {
      expect(checklistSummaryText({}), '12 pontos para ver na visita');
      // A note alone is not a mark.
      expect(
        checklistSummaryText({'tyres': const ChecklistEntry(note: 'x')}),
        '12 pontos para ver na visita',
      );
    });

    test('counts what was seen and the problems', () {
      expect(
        checklistSummaryText({'tyres': _ok, 'chain': _ok}),
        '2 de 12 vistos',
      );
      expect(
        checklistSummaryText({'tyres': _issue, 'chain': _ok, 'keys': _ok}),
        '3 de 12 vistos · 1 problema',
      );
      expect(
        checklistSummaryText({'tyres': _issue, 'chain': _issue}),
        '2 de 12 vistos · 2 problemas',
      );
    });

    test('everything seen, with or without problems', () {
      final all = {for (final i in viewingChecklistItems) i.key: _ok};
      expect(checklistSummaryText(all), 'Tudo visto, sem problemas');
      expect(
        checklistSummaryText({...all, 'brakes': _issue}),
        'Tudo visto · 1 problema',
      );
    });

    test('items no longer on the list are ignored', () {
      expect(
        checklistSummaryText({'old_item': _issue, 'keys': _ok}),
        '1 de 12 vistos',
      );
    });
  });

  test('checklistIssuesText names the problems in list order', () {
    expect(checklistIssuesText({'tyres': _ok}), isNull);
    expect(checklistIssuesText({'tyres': _issue}), 'Problema: Pneus');
    expect(
      checklistIssuesText({'brakes': _issue, 'tyres': _issue, 'old': _issue}),
      'Problemas: Pneus, Travões e discos',
    );
  });
}
