import 'package:collector/collector.dart';
import 'package:test/test.dart';

void main() {
  const english = NotificationLanguage.english;

  test('notification language codes are explicit and supported', () {
    for (final language in NotificationLanguage.values) {
      expect(NotificationLanguage.fromCode(language.code), language);
    }
    for (final code in ['', 'es', 'EN', 'en_GB']) {
      expect(() => NotificationLanguage.fromCode(code), throwsFormatException);
    }
  });

  test('numbers and euro prices follow the recipient language', () {
    expect(english.number(12500), '12,500');
    expect(english.number(-12500), '-12,500');
    expect(euros(7650, language: english), '€7,650');
    expect(euros(-1234, language: english), '-€1,234');
    expect(euros(950.4, language: english), '€950');
    expect(euros(7650), '7 650 €');
  });

  test('zero, one and several events have grammatical count labels', () {
    for (final (count, listings, drops) in [
      (0, '0 new listings', '0 price drops'),
      (1, '1 new listing', '1 price drop'),
      (2, '2 new listings', '2 price drops'),
    ]) {
      expect(english.newListings(count), listings);
      expect(english.priceDrops(count), drops);
      expect(english.goneListings(count), '$count left the market');
    }
  });

  test('every alert type has an English heading and local price facts', () {
    for (final (type, heading) in [
      ('new_listing', '🆕 New listing'),
      ('price_reduction', '📉 Price drop'),
      ('excellent_opportunity', '🔥 Excellent opportunity'),
      ('listing_removed', '🚫 Listing removed'),
      ('back_on_market', '🔁 Back on the market'),
      ('target_price_reached', '🎯 Your target price was reached'),
      ('unknown', '🔔 Alert'),
    ]) {
      final message = pushMessage(
        PendingAlert(
          alertId: 'alert',
          type: type,
          brand: 'Honda',
          model: 'CB650R',
          url: 'https://example.com/listing',
          listingId: 'listing',
          oldPrice: 7400,
          newPrice: 7000,
          mileage: 12500,
          dealScore: 87,
          location: 'Porto',
        ),
        language: english,
      );
      expect(message['title'], '$heading: Honda CB650R', reason: type);
      expect(message['body'], contains('€7,000'), reason: type);
      expect(message['body'], contains('12,500 km · Porto'), reason: type);
      expect(message['url'], '/#/deals/listing');
      expect(message['tag'], 'alert');
      expect(message['language'], 'en');
      if (type == 'back_on_market') {
        expect(message['body'], startsWith('€7,000 (previously €7,400)'));
      } else if (type == 'target_price_reached') {
        expect(message['body'], startsWith('€7,000 (your target: €7,400)'));
      } else if (type == 'listing_removed') {
        expect(message['body'], isNot(contains('Score')));
      }
    }
    expect(
      english.alertHeading('new_listing', myColour: true),
      '🆕 New listing in your colour',
    );
    expect(english.inYourColour, 'In your colour');
  });

  test('health copy is English but original diagnostic lines stay intact', () {
    const diagnostic = 'olx: Failed: mensagem original';
    final message = runHealthMessage([
      (status: 'failed', problems: [diagnostic]),
      (status: 'ok', problems: <String>[]),
    ], language: english)!;
    expect(message['title'], '⚠️ Listing collection failed.');
    expect(message['body'], startsWith(diagnostic));
    expect(message['body'], contains('Prices in the app may be out of date'));
    expect(message['url'], '/#/collection-status');
    expect(message['tag'], 'run-health');
    expect(
      runHealthMessage([
        (status: 'failed', problems: [diagnostic]),
        (status: 'failed', problems: [diagnostic]),
      ], language: english),
      isNull,
    );
    expect(
      runHealthMessage([
        (status: 'partial', problems: [diagnostic]),
        (status: 'partial', problems: [diagnostic]),
        (status: 'ok', problems: <String>[]),
      ], language: english)?['title'],
      '⚠️ Listing collection failed twice in a row.',
    );
  });

  test('every selectable test notification is built in English', () {
    for (final kind in pushTestKinds) {
      final message = samplePushMessage(kind, null, language: english);
      expect(message['language'], 'en', reason: kind);
      expect(message['tag'], 'push-test', reason: kind);
      if (kind == 'test') {
        expect(message['title'], 'Test notification');
        expect(
          message['body'],
          startsWith('This device receives notifications.'),
        );
      } else {
        expect(message['body'], endsWith('Test example: nothing has changed.'));
      }
    }
  });
}
