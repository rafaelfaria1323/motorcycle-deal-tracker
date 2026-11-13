import 'package:collector/collector.dart';
import 'package:test/test.dart';

class _Store implements PushStore {
  _Store(this.values, {this.devices = const {}});

  final List<OwnedBikeValue> values;
  final Map<String, List<PushTarget>> devices;
  DateTime? askedAt;

  @override
  Future<List<OwnedBikeValue>> recordOwnedBikeValues(DateTime at) async {
    askedAt = at;
    return values;
  }

  @override
  Future<Map<String, NotificationLanguage>> accountLanguages(
    List<String> userIds,
  ) async => {
    for (final user in userIds)
      user: user == 'en'
          ? NotificationLanguage.english
          : NotificationLanguage.portuguese,
  };

  @override
  Future<Map<String, List<PushTarget>>> pushTargets() async => devices;

  @override
  Future<void> forgetPushTargets(List<String> endpoints) async {}

  @override
  Future<void> markPushTargetsUsed(List<String> endpoints) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Push implements WebPushSender {
  final sent = <Map<String, Object?>>[];

  @override
  Future<PushResult> send(
    PushTarget target,
    Map<String, Object?> message,
  ) async {
    sent.add(message);
    return PushResult.sent;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

OwnedBikeValue _bike({
  String user = 'u1',
  String bike = 'b1',
  double value = 5432,
  int? mileage = 21000,
  double? previous = 5554,
}) => OwnedBikeValue(
  userId: user,
  bikeId: bike,
  brand: 'Yamaha',
  model: 'MT-07',
  year: 2020,
  value: value,
  mileage: mileage,
  previousValue: previous,
  previousMonth: previous == null ? null : DateTime.utc(2026, 10),
);

void main() {
  group('the monthly value', () {
    test('worth now, and the drop since last month; a tap opens it', () {
      expect(ownedBikeValuePush(_bike()), {
        'title': '💶 A sua Yamaha MT-07 2020 vale cerca de 5 430 €',
        'body': 'Menos 120 € (2,2 %) do que em outubro.',
        'url': '/#/my-bike',
        'tag': 'bike-month-b1',
        'language': 'pt',
      });
    });

    test('in English, and a rise', () {
      final message = ownedBikeValuePush(
        _bike(value: 5800, previous: 5600),
        language: .english,
      );
      expect(
        message['title'],
        '💶 Your Yamaha MT-07 2020 is worth about €5,800',
      );
      expect(message['body'], '€200 (3.6%) more than in October.');
      expect(
        ownedBikeValuePush(_bike(value: 5800, previous: 5600))['body'],
        'Mais 200 € (3,6 %) do que em outubro.',
      );
    });

    test('within 1 %: about the same', () {
      expect(
        ownedBikeValuePush(_bike(value: 5550, previous: 5600))['body'],
        'Mais ou menos o mesmo que em outubro.',
      );
      expect(
        ownedBikeValuePush(
          _bike(value: 5650, previous: 5600),
          language: .english,
        )['body'],
        'About the same as in October.',
      );
    });

    test('the first month: the mileage, and that it comes monthly', () {
      expect(
        ownedBikeValuePush(_bike(previous: null))['body'],
        'Com 21 000 km. A partir de agora diz-lhe todos os meses quanto mudou.',
      );
      expect(
        ownedBikeValuePush(
          _bike(previous: null, mileage: null),
          language: .english,
        )['body'],
        "From now on you'll hear each month how much it changed.",
      );
    });

    test('read from the database row', () {
      final bike = OwnedBikeValue.fromRow({
        'user_id': 'u1',
        'bike_id': 'b1',
        'brand': 'Honda',
        'model': 'CB650R',
        'year': 2021,
        'value': 6123.45,
        'mileage': null,
        'previous_value': 6200,
        'previous_month': '2026-10-01',
      });
      expect(
        (bike.value, bike.mileage, bike.previousValue, bike.previousMonth),
        (6123.45, null, 6200.0, DateTime(2026, 10)),
      );
      final first = OwnedBikeValue.fromRow({
        'user_id': 'u1',
        'bike_id': 'b1',
        'brand': 'Honda',
        'model': 'CB650R',
        'year': 2021,
        'value': 6123,
        'mileage': 15000,
        'previous_value': null,
        'previous_month': null,
      });
      expect((first.previousValue, first.previousMonth), (null, null));
    });

    test('every month name in both languages', () {
      expect(
        [
          for (var m = 1; m <= 12; m++)
            NotificationLanguage.portuguese.monthName(m),
        ],
        [
          'janeiro',
          'fevereiro',
          'março',
          'abril',
          'maio',
          'junho',
          'julho',
          'agosto',
          'setembro',
          'outubro',
          'novembro',
          'dezembro',
        ],
      );
      expect(NotificationLanguage.english.monthName(1), 'January');
      expect(NotificationLanguage.english.monthName(12), 'December');
    });
  });

  group('sendOwnedBikeValues', () {
    test('one notification per bike, each in its owner\'s language', () async {
      final store = _Store(
        [_bike(), _bike(bike: 'b2'), _bike(user: 'en', bike: 'b3')],
        devices: {
          'u1': [PushTarget(endpoint: 'https://p/u1', p256dh: 'k', auth: 'a')],
          'en': [PushTarget(endpoint: 'https://p/en', p256dh: 'k', auth: 'a')],
        },
      );
      final push = _Push();
      final at = DateTime.utc(2026, 11, 2, 8, 52);
      expect(await sendOwnedBikeValues(store, push, at), (valued: 3, sent: 3));
      expect(store.askedAt, at);
      expect(push.sent.map((m) => (m['tag'], m['language'])), [
        ('bike-month-b1', 'pt'),
        ('bike-month-b2', 'pt'),
        ('bike-month-b3', 'en'),
      ]);
    });

    test('without Web Push the values are still kept', () async {
      final store = _Store([_bike()]);
      expect(await sendOwnedBikeValues(store, null, DateTime.utc(2026)), (
        valued: 1,
        sent: 0,
      ));
      expect(store.askedAt, DateTime.utc(2026));
    });
  });

  group('the push test example', () {
    test('the listing\'s bike, 2 % down on last month', () {
      final message = samplePushMessage('bike_value_month', {
        'id': 'abc',
        'brand': 'Honda',
        'model': 'CB650R',
        'year': 2020,
        'price': 6500,
      });
      expect(
        message['title'],
        '💶 A sua Honda CB650R 2020 vale cerca de 6 500 €',
      );
      expect(
        message['body'],
        startsWith('Menos 130 € (2,0 %) do que em outubro.\n'),
      );
      expect(message['url'], '/#/my-bike');
      expect(message['tag'], 'push-test');
      expect(pushTestKinds, contains('bike_value_month'));
    });

    test('without a listing, the example bike', () {
      final message = samplePushMessage(
        'bike_value_month',
        null,
        language: .english,
      );
      expect(
        message['title'],
        '💶 Your Yamaha MT-07 2021 is worth about €6,500',
      );
    });
  });
}
