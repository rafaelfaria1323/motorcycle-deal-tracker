import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:motorcycle_deal_tracker/core/auth/session_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/listing_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/repositories/supabase_listing_card_preferences_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_card_preferences.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/listing_card_preferences_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/listing_card_preferences_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/listing_card_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/listing_labels.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _minimal = ListingCardPreferences(const []);
final _riskOnly = ListingCardPreferences(const [ListingCardField.riskScore]);
const _defaults = ListingCardPreferences.defaults();

Listing _cardListing([Map<String, dynamic> fields = const {}]) =>
    ListingModel.fromJson({
      'id': 'card',
      'source': 'olx',
      'url': 'https://example.pt/card',
      'brand': 'Yamaha',
      'model': 'MT-07',
      'status': 'active',
      'seller_type': 'private',
      ...fields,
    });

Future<void> _settle() => Future<void>.delayed(Duration.zero);

User _user(String id) => User(
  id: id,
  email: 'same@example.pt',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-25T00:00:00Z',
);

class _Preferences implements ListingCardPreferencesRepository {
  final values = <String, ListingCardPreferences>{};
  final reads = <String>[];
  final writes = <(String, ListingCardPreferences)>[];
  final pendingReads = <String, Completer<ListingCardPreferences>>{};
  Completer<void>? pendingSave;
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<ListingCardPreferences> get(String userId) async {
    reads.add(userId);
    if (failReads) throw StateError('Offline');
    final pending = pendingReads.remove(userId);
    if (pending != null) return await pending.future;
    return values[userId] ?? _defaults;
  }

  @override
  Future<void> save(String userId, ListingCardPreferences preferences) async {
    writes.add((userId, preferences));
    if (failWrites) throw StateError('Offline');
    await pendingSave?.future;
    values[userId] = preferences;
  }
}

class _Recorder extends http.BaseClient {
  final calls = <(String, Uri, String)>[];
  List<Map<String, Object?>> rows = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls.add((
      request.method,
      request.url,
      await request.finalize().bytesToString(),
    ));
    final reading = request.method == 'GET';
    return http.StreamedResponse(
      Stream.value(utf8.encode(reading ? jsonEncode(rows) : '')),
      reading ? 200 : 201,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  test(
    'defaults: the earlier card and the market position, new details opt-in',
    () {
      expect(_defaults.fields.map((field) => field.code), [
        'source',
        'deal_score',
        'price_change',
        'market_position',
        'year',
        'mileage',
        'location',
        'preferred_colour',
      ]);
      for (final field in ListingCardPreferences.additionalFields) {
        expect(_defaults.shows(field), isFalse);
      }
      expect(ListingCardField.values.map((field) => field.label()), [
        'Site de origem',
        'Deal Score',
        'Variação do preço',
        'Posição face ao mercado',
        'Ano',
        'Quilometragem',
        'Localização e distância',
        'Indicação de cor preferida',
        'Risk Score',
        'Tipo de vendedor',
        'Quando foi encontrado',
        'Cor',
        'Donos / primeiro dono',
        'Livro de revisões',
        'Origem',
        'Garantia de fábrica',
        'Garantia do vendedor',
        'Nome do stand',
        'Data de publicação',
        'Renovação no site',
        'Estado do anúncio',
      ]);
    },
  );

  test('choices are immutable sets and every optional field may be hidden', () {
    final input = <ListingCardField>[ListingCardField.year];
    final preferences = ListingCardPreferences(input);
    input.clear();
    expect(preferences.shows(ListingCardField.year), isTrue);
    expect(preferences.fields.clear, throwsUnsupportedError);
    expect(preferences.withField(ListingCardField.year, false), _minimal);
    expect(_minimal.withField(ListingCardField.riskScore, true), _riskOnly);
    expect(_riskOnly.withField(ListingCardField.riskScore, true), _riskOnly);
    expect(
      ListingCardPreferences(_defaults.fields.toList().reversed),
      _defaults,
    );
  });

  test('extra card facts use existing data and skip unavailable values', () {
    final preferences = ListingCardPreferences(ListingCardField.values);
    final listing = Listing(
      id: 'l1',
      source: 'olx',
      url: 'https://example.pt/l1',
      brand: 'Yamaha',
      model: 'MT-07',
      status: ListingStatus.active,
      sellerType: SellerType.dealer,
      images: const [],
      riskScore: 23,
      firstSeenAt: DateTime.utc(2026, 10, 23, 12),
    );
    expect(
      listingCardExtraFacts(
        listing,
        preferences,
        now: DateTime.utc(2026, 10, 25, 12),
      ),
      [
        (ListingCardField.riskScore, 'Risk Score: 23/100'),
        (ListingCardField.sellerType, 'Profissional'),
        (ListingCardField.firstSeenAt, 'Encontrado há 2 dias'),
        (ListingCardField.status, 'Estado: Ativo'),
      ],
    );
    expect(listingCardExtraFacts(listing, _defaults), isEmpty);
    expect(
      listingCardExtraFacts(
        const Listing(
          id: 'l2',
          source: 'olx',
          url: 'https://example.pt/l2',
          brand: 'Honda',
          model: 'CB650R',
          status: ListingStatus.unknown,
          sellerType: SellerType.unknown,
          images: [],
        ),
        preferences,
      ),
      isEmpty,
    );
  });

  test('the market position reads in whole percent, both ways (F.7)', () {
    expect(marketPositionText(8.04), '8 % abaixo do mercado');
    expect(marketPositionText(-5.4), '5 % acima do mercado');
    expect(marketPositionText(0.4), 'No valor de mercado');
    expect(marketPositionText(-0.4), 'No valor de mercado');
    expect(marketPositionText(null), isNull);
    expect(
      marketPositionText(12.3, language: .english),
      '12% below market value',
    );
    expect(_cardListing({'market_position': 12.3}).marketPosition, 12.3);
    expect(_cardListing({'market_position': -4}).marketPosition, -4.0);
    expect(_cardListing({}).marketPosition, isNull);
  });

  test('cards offer the structured bike and ad facts from the detail page', () {
    final listing = _cardListing({
      'seller_type': 'dealer',
      'seller_name': '  Motos do Norte  ',
      'status': 'price_changed',
      'risk_score': 23,
      'first_seen_at': '2026-10-23T12:00:00Z',
      'colour': 'blue',
      'registrations': 1,
      'service_book': true,
      'origin': 'national',
      'warranty_until': '2027-03-01',
      'dealer_warranty_months': 18,
      'published_at': '2026-10-09T12:00:00Z',
      'site_refreshed_at': '2026-10-24T12:00:00Z',
    });
    expect(
      listingCardExtraFacts(
        listing,
        ListingCardPreferences(ListingCardField.values),
        now: DateTime.utc(2026, 10, 25, 12),
      ),
      [
        (ListingCardField.riskScore, 'Risk Score: 23/100'),
        (ListingCardField.sellerType, 'Profissional'),
        (ListingCardField.firstSeenAt, 'Encontrado há 2 dias'),
        (ListingCardField.colour, 'Cor: Azul'),
        (ListingCardField.registrations, 'Primeiro dono'),
        (ListingCardField.serviceBook, 'Livro de revisões completo'),
        (ListingCardField.origin, 'Nacional'),
        (ListingCardField.warrantyUntil, 'Garantia de fábrica até 01/03/2027'),
        (
          ListingCardField.dealerWarrantyMonths,
          '18 meses de garantia do vendedor',
        ),
        (ListingCardField.sellerName, 'Stand: Motos do Norte'),
        (ListingCardField.publishedAt, 'Publicado: 09/10/2026 (há 16 dias)'),
        (
          ListingCardField.siteRefreshedAt,
          'Renovado no site: 24/10/2026 (ontem)',
        ),
        (ListingCardField.status, 'Estado: Preço alterado'),
      ],
    );
    expect(listingCardExtraFacts(listing, _defaults), isEmpty);
  });

  test('owner counts take precedence over first-owner scoring signals', () {
    final preferences = ListingCardPreferences(const [
      ListingCardField.registrations,
    ]);
    final cases = <(Map<String, dynamic>, String?)>[
      ({'registrations': 1}, 'Primeiro dono'),
      (
        {
          'card_risk_reasons': ['first_owner'],
        },
        'Primeiro dono (indicado no anúncio)',
      ),
      (
        {
          'registrations': 3,
          'card_risk_reasons': ['first_owner'],
        },
        '3 registos (donos)',
      ),
      ({'registrations': 2}, '2 registos (donos)'),
      (
        {
          'card_risk_reasons': ['service_book'],
        },
        null,
      ),
      ({}, null),
    ];
    for (final (fields, expected) in cases) {
      expect(listingCardExtraFacts(_cardListing(fields), preferences), [
        if (expected != null) (ListingCardField.registrations, expected),
      ]);
    }
  });

  test(
    'negative facts remain visible and missing or private data is omitted',
    () {
      final preferences = ListingCardPreferences(const [
        ListingCardField.serviceBook,
        ListingCardField.origin,
        ListingCardField.colour,
        ListingCardField.dealerWarrantyMonths,
        ListingCardField.sellerName,
      ]);
      expect(
        listingCardExtraFacts(
          _cardListing({
            'service_book': false,
            'origin': 'imported',
            'dealer_warranty_months': 1,
            'seller_name': 'Not a dealer',
          }),
          preferences,
        ),
        [
          (ListingCardField.serviceBook, 'Sem livro de revisões completo'),
          (ListingCardField.origin, 'Importada'),
          (
            ListingCardField.dealerWarrantyMonths,
            '1 mês de garantia do vendedor',
          ),
        ],
      );
      expect(
        listingCardExtraFacts(
          _cardListing({
            'colour': 'unknown',
            'origin': 'unknown',
            'seller_type': 'dealer',
            'seller_name': '   ',
          }),
          preferences,
        ),
        isEmpty,
      );
    },
  );

  test(
    'publication is not discovery and renewal follows the detail-page rule',
    () {
      final preferences = ListingCardPreferences(const [
        ListingCardField.publishedAt,
        ListingCardField.siteRefreshedAt,
      ]);
      final now = DateTime.utc(2026, 10, 25, 12);
      expect(
        listingCardExtraFacts(
          _cardListing({'first_seen_at': '2026-10-23T12:00:00Z'}),
          preferences,
          now: now,
        ),
        isEmpty,
      );
      expect(
        listingCardExtraFacts(
          _cardListing({
            'published_at': '2026-10-24T12:00:00Z',
            'site_refreshed_at': '2026-10-24T18:00:00Z',
          }),
          preferences,
          now: now,
        ),
        [(ListingCardField.publishedAt, 'Publicado: 24/10/2026 (ontem)')],
      );
      expect(
        listingCardExtraFacts(
          _cardListing({'site_refreshed_at': '2026-10-24T12:00:00Z'}),
          preferences,
          now: now,
        ),
        [
          (
            ListingCardField.siteRefreshedAt,
            'Renovado no site: 24/10/2026 (ontem)',
          ),
        ],
      );
    },
  );

  group('Supabase card preferences', () {
    late _Recorder recorder;
    late SupabaseClient client;
    late SupabaseListingCardPreferencesRepository repository;

    setUp(() {
      recorder = _Recorder();
      client = SupabaseClient(
        'https://db.example',
        'sb_publishable_test',
        httpClient: recorder,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      repository = SupabaseListingCardPreferencesRepository(client);
      addTearDown(client.dispose);
    });

    test('no row preserves defaults; an empty selection stays empty', () async {
      expect(await repository.get('a'), _defaults);
      expect(recorder.calls.single.$2.queryParameters, {
        'select': 'visible_fields',
        'user_id': 'eq.a',
      });
      recorder.rows = [
        {'visible_fields': <String>[]},
      ];
      expect(await repository.get('a'), _minimal);
      recorder.rows = [
        {
          'visible_fields': ['seller_type', 'risk_score', 'risk_score'],
        },
      ];
      expect(
        await repository.get('a'),
        ListingCardPreferences(const [
          ListingCardField.sellerType,
          ListingCardField.riskScore,
        ]),
      );
    });

    test(
      'invalid stored fields fail instead of replacing saved choices',
      () async {
        recorder.rows = [
          {
            'visible_fields': ['description'],
          },
        ];
        await expectLater(repository.get('a'), throwsFormatException);
      },
    );

    test(
      'saves stable codes and the initiating account, including defaults',
      () async {
        await repository.save(
          'a',
          ListingCardPreferences(_defaults.fields.toList().reversed),
        );
        final (method, uri, body) = recorder.calls.single;
        expect(method, 'POST');
        expect(uri.path, '/rest/v1/listing_card_preferences');
        expect(uri.queryParameters['on_conflict'], 'user_id');
        expect(jsonDecode(body), {
          'user_id': 'a',
          'visible_fields': _defaults.fields
              .map((field) => field.code)
              .toList(),
        });
        await repository.save('b', _minimal);
        expect(jsonDecode(recorder.calls.last.$3), {
          'user_id': 'b',
          'visible_fields': <String>[],
        });
      },
    );

    test('all detail-field choices survive saving and loading', () async {
      final preferences = ListingCardPreferences(
        ListingCardField.values.reversed,
      );
      await repository.save('a', preferences);
      final saved =
          jsonDecode(recorder.calls.single.$3) as Map<String, dynamic>;
      expect(
        saved['visible_fields'],
        ListingCardField.values.map((field) => field.code).toList(),
      );
      recorder.rows = [
        {'visible_fields': saved['visible_fields']},
      ];
      expect(await repository.get('a'), preferences);
    });
  });

  group('Card preferences cubit', () {
    late _Preferences repository;
    late StreamController<User?> users;
    late SessionCubit session;
    late ListingCardPreferencesCubit cubit;

    setUp(() async {
      repository = _Preferences();
      users = StreamController<User?>();
      session = SessionCubit(
        const SessionState(
          userId: 'a',
          email: 'same@example.pt',
          signedIn: true,
        ),
        users.stream,
      );
      cubit = ListingCardPreferencesCubit(repository, session);
      addTearDown(() async {
        if (!cubit.isClosed) await cubit.close();
        await session.close();
        await users.close();
      });
      await _settle();
    });

    test('loads the account and persists choices and resetting', () async {
      expect(cubit.state.status, ListingCardPreferencesStatus.success);
      expect(repository.reads, ['a']);
      expect(await cubit.save(_riskOnly), isTrue);
      expect(cubit.state.preferences, _riskOnly);
      expect(repository.values['a'], _riskOnly);
      await cubit.load();
      expect(cubit.state.preferences, _riskOnly);
      expect(await cubit.save(_defaults), isTrue);
      expect(repository.writes, [('a', _riskOnly), ('a', _defaults)]);
      expect(cubit.state.preferences, _defaults);
    });

    test(
      'load failures are explicit and can be retried without losing choices',
      () async {
        await cubit.save(_riskOnly);
        repository.failReads = true;
        await cubit.load();
        expect(cubit.state.status, ListingCardPreferencesStatus.failure);
        expect(cubit.state.error, isNotNull);
        expect(cubit.state.preferences, _riskOnly);
        expect(await cubit.save(_minimal), isFalse);
        expect(repository.writes, hasLength(1));
        repository.failReads = false;
        await cubit.load();
        expect(cubit.state.status, ListingCardPreferencesStatus.success);
        expect(cubit.state.error, isNull);
      },
    );

    test(
      'only a successful save changes the cards, with duplicate saves blocked',
      () async {
        final pending = repository.pendingSave = Completer<void>();
        final save = cubit.save(_riskOnly);
        expect(cubit.state.saving, isTrue);
        expect(cubit.state.preferences, _defaults);
        expect(await cubit.save(_minimal), isFalse);
        pending.complete();
        expect(await save, isTrue);
        expect(cubit.state.saving, isFalse);
        expect(cubit.state.preferences, _riskOnly);
        repository.failWrites = true;
        expect(await cubit.save(_minimal), isFalse);
        expect(cubit.state.preferences, _riskOnly);
        expect(cubit.state.saving, isFalse);
        expect(cubit.state.error, isNotNull);
      },
    );

    test(
      'signing out restores defaults and refuses writes without a read',
      () async {
        await cubit.save(_riskOnly);
        users.add(null);
        await _settle();
        expect(cubit.state.userId, isNull);
        expect(cubit.state.preferences, _defaults);
        expect(cubit.state.status, ListingCardPreferencesStatus.success);
        expect(repository.reads, ['a']);
        expect(await cubit.save(_minimal), isFalse);
        expect(
          cubit.state.error,
          ListingCardPreferencesFailure.accountRequired,
        );
        expect(repository.writes, hasLength(1));
      },
    );

    test(
      'an old load cannot leak preferences into a different account',
      () async {
        await cubit.save(_riskOnly);
        final pending = Completer<ListingCardPreferences>();
        repository.pendingReads['a'] = pending;
        final loading = cubit.load();
        repository.failReads = true;
        users.add(_user('b'));
        await _settle();
        expect(cubit.state.userId, 'b');
        expect(cubit.state.preferences, _defaults);
        expect(cubit.state.status, ListingCardPreferencesStatus.failure);
        pending.complete(_minimal);
        await loading;
        expect(cubit.state.userId, 'b');
        expect(cubit.state.preferences, _defaults);
      },
    );

    test(
      'older loads of the same account cannot replace newer choices',
      () async {
        final pending = Completer<ListingCardPreferences>();
        repository.pendingReads['a'] = pending;
        final oldLoad = cubit.load();
        repository.values['a'] = _riskOnly;
        await cubit.load();
        pending.complete(_minimal);
        await oldLoad;
        expect(cubit.state.preferences, _riskOnly);
      },
    );

    test('an in-flight save stays with its initiating account', () async {
      final pending = repository.pendingSave = Completer<void>();
      final save = cubit.save(_riskOnly);
      repository.values['b'] = _minimal;
      users.add(_user('b'));
      await _settle();
      pending.complete();
      expect(await save, isFalse);
      expect(repository.writes, [('a', _riskOnly)]);
      expect(repository.values['a'], _riskOnly);
      expect(cubit.state.userId, 'b');
      expect(cubit.state.preferences, _minimal);
      expect(cubit.state.saving, isFalse);
    });

    test('late responses after closing do not emit', () async {
      final pending = Completer<ListingCardPreferences>();
      repository.pendingReads['a'] = pending;
      final loading = cubit.load();
      await cubit.close();
      pending.completeError(StateError('Offline'));
      await loading;
      expect(cubit.isClosed, isTrue);
    });
  });
}
