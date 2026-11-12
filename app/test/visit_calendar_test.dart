import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/calendar/calendar_event.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
import 'package:motorcycle_deal_tracker/features/favourites/domain/entities/favourite.dart';
import 'package:motorcycle_deal_tracker/features/favourites/presentation/visit_calendar_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';

final _start = DateTime.utc(2026, 11, 20, 9, 30);

CalendarEvent _event({
  String title = 'Visita: Yamaha MT-07 · 2021',
  String description = 'Leve a lista.',
  String? location = 'Braga',
  Duration? reminder = const Duration(hours: 1),
}) => CalendarEvent(
  uid: 'visit-l1@motorcycle-deal-tracker',
  title: title,
  start: _start,
  end: _start.add(const Duration(hours: 1)),
  description: description,
  location: location,
  reminder: reminder,
);

List<String> _lines(String ics) {
  expect(ics, endsWith('\r\n'));
  return ics.substring(0, ics.length - 2).split('\r\n');
}

/// The content lines with their folds joined again (RFC 5545 3.1).
List<String> _unfolded(String ics) => _lines(ics.replaceAll('\r\n ', ''));

void main() {
  final stamp = DateTime.utc(2026, 11, 12, 8, 5, 7);

  group('icsText (N.73)', () {
    test('one event in UTC with its alarm, CRLF lines', () {
      final lines = _lines(icsText(_event(), stamp: stamp));
      expect(lines.first, 'BEGIN:VCALENDAR');
      expect(lines.last, 'END:VCALENDAR');
      expect(lines, contains('VERSION:2.0'));
      expect(lines, contains('UID:visit-l1@motorcycle-deal-tracker'));
      expect(lines, contains('DTSTAMP:20261112T080507Z'));
      expect(lines, contains('DTSTART:20261120T093000Z'));
      expect(lines, contains('DTEND:20261120T103000Z'));
      expect(lines, contains('SUMMARY:Visita: Yamaha MT-07 · 2021'));
      expect(lines, contains('LOCATION:Braga'));
      final alarm = lines.indexOf('BEGIN:VALARM');
      expect(lines.sublist(alarm, alarm + 5), [
        'BEGIN:VALARM',
        'ACTION:DISPLAY',
        'DESCRIPTION:Visita: Yamaha MT-07 · 2021',
        'TRIGGER:-PT60M',
        'END:VALARM',
      ]);
      expect(lines.indexOf('BEGIN:VEVENT'), lessThan(alarm));
      expect(lines.indexOf('END:VEVENT'), greaterThan(alarm));
      expect(lines.any((line) => line.contains('\n')), isFalse);
    });

    test('local times are written in UTC', () {
      final local = DateTime(2026, 11, 20, 9, 30);
      expect(icsTime(local), icsTime(local.toUtc()));
      expect(icsTime(DateTime.utc(2027, 1, 2, 3, 4, 5)), '20270102T030405Z');
    });

    test('escapes backslashes, semicolons, commas and new lines', () {
      final lines = _lines(
        icsText(
          _event(
            description:
                r'6 400 €; a\b, c'
                '\nd\r\ne',
          ),
          stamp: stamp,
        ),
      );
      expect(lines, contains(r'DESCRIPTION:6 400 €\; a\\b\, c\nd\ne'));
    });

    test('no place and no alarm leave their lines out', () {
      final ics = icsText(_event(location: '  ', reminder: null), stamp: stamp);
      expect(ics, isNot(contains('LOCATION')));
      expect(ics, isNot(contains('VALARM')));
    });

    test('folds long lines at 75 octets, never inside a character', () {
      final description = 'Moto à venda é ótima ' * 12;
      final ics = icsText(_event(description: description), stamp: stamp);
      for (final line in _lines(ics)) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75), reason: line);
      }
      expect(
        _unfolded(ics),
        contains('DESCRIPTION:${description.replaceAll(',', r'\,')}'),
      );
    });
  });

  group('visitEvent (N.73)', () {
    const listing = Listing(
      id: 'l1',
      source: 'olx',
      url: 'https://www.olx.pt/d/anuncio/mt-07-IDabc.html',
      brand: 'Yamaha',
      model: 'MT-07',
      status: .active,
      sellerType: .private,
      images: [],
      year: 2021,
      price: 6400,
      location: 'Braga',
    );
    final at = DateTime(2026, 11, 20, 18);

    test('the bike, an hour at its place, the links and the checklist', () {
      final event = visitEvent(
        Favourite(listingId: 'l1', createdAt: at, listing: listing),
        at,
        origin: 'https://app.example',
      );
      expect(event.uid, 'visit-l1@motorcycle-deal-tracker');
      expect(event.title, 'Visita: Yamaha MT-07 · 2021');
      expect(event.start, at);
      expect(event.end, at.add(const Duration(hours: 1)));
      expect(event.location, 'Braga');
      expect(event.reminder, const Duration(hours: 1));
      final lines = event.description.split('\n');
      expect(lines, hasLength(4));
      expect(lines[0], contains('6'));
      expect(lines[0], contains('€'));
      expect(lines[1], 'https://app.example/#/deals/l1');
      expect(
        lines[2],
        'Anúncio original: https://www.olx.pt/d/anuncio/mt-07-IDabc.html',
      );
      expect(lines[3], 'Leve a lista «Para a visita» da app.');
    });

    test('in English, and without the ad loaded', () {
      final event = visitEvent(
        Favourite(listingId: 'l2', createdAt: at),
        at,
        origin: 'https://app.example',
        language: AppLanguage.english,
      );
      expect(event.title, 'Viewing: motorcycle');
      expect(event.location, isNull);
      expect(event.description.split('\n'), [
        'https://app.example/#/deals/l2',
        'Bring the app\'s “For the viewing” checklist.',
      ]);
    });
  });
}
