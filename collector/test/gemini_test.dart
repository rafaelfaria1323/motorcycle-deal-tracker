import 'dart:async';
import 'dart:convert';

import 'package:collector/collector.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

String _answer(Object? json) => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {'text': jsonEncode(json)},
        ],
      },
    },
  ],
});

void main() {
  group('GeminiClient', () {
    test(
      'asks for JSON in the shape given, with the key in a header',
      () async {
        late http.Request sent;
        final waits = <Duration>[];
        final client = GeminiClient(
          apiKey: 'k',
          model: 'm1',
          httpClient: MockClient((r) async {
            sent = r;
            return http.Response(_answer([1, 2]), 200);
          }),
          wait: (d) async => waits.add(d),
        );
        expect(await client.generateJson('p', {'type': 'ARRAY'}), [1, 2]);
        expect(
          sent.url.toString(),
          'https://generativelanguage.googleapis.com/v1beta/models/m1:generateContent',
        );
        expect(sent.headers['x-goog-api-key'], 'k');
        expect(sent.url.query, isEmpty, reason: 'the key never in the address');
        final body = jsonDecode(sent.body) as Map<String, Object?>;
        expect(body['contents'], [
          {
            'role': 'user',
            'parts': [
              {'text': 'p'},
            ],
          },
        ]);
        expect(body['generationConfig'], {
          'temperature': 0,
          'responseMimeType': 'application/json',
          'responseSchema': {'type': 'ARRAY'},
          'thinkingConfig': {'thinkingBudget': 0},
        });
        expect(waits, isEmpty, reason: 'the first request waits for nothing');
        await client.generateJson('p', {});
        expect(waits, [const Duration(seconds: 15)]);
      },
    );

    test(
      'a model that refuses to stop thinking is asked again, with it on',
      () async {
        final configs = <Object?>[];
        final client = GeminiClient(
          apiKey: 'k',
          httpClient: MockClient((r) async {
            final config =
                (jsonDecode(r.body) as Map<String, Object?>)['generationConfig']
                    as Map<String, Object?>;
            configs.add(config['thinkingConfig']);
            return config.containsKey('thinkingConfig')
                ? http.Response(
                    jsonEncode({
                      'error': {'message': 'Thinking budget is not supported'},
                    }),
                    400,
                  )
                : http.Response(_answer({'ok': true}), 200);
          }),
          wait: (_) async {},
        );
        expect(await client.generateJson('p', {}), {'ok': true});
        expect(await client.generateJson('p', {}), {'ok': true});
        expect(configs, [
          {'thinkingBudget': 0},
          null,
          null,
        ], reason: 'asked once with it, then never again');
        final other = GeminiClient(
          apiKey: 'k',
          httpClient: MockClient((r) async => http.Response('bad schema', 400)),
          wait: (_) async {},
        );
        await expectLater(
          other.generateJson('p', {}),
          throwsA(isA<GeminiFailure>()),
          reason: 'another 400 is not asked again',
        );
      },
    );

    test('a 429 or a busy server is tried once more, a minute later', () async {
      var calls = 0;
      final waits = <Duration>[];
      final client = GeminiClient(
        apiKey: 'k',
        httpClient: MockClient((r) async {
          calls++;
          return calls == 1
              ? http.Response('busy', 503)
              : http.Response(_answer({'ok': true}), 200);
        }),
        wait: (d) async => waits.add(d),
      );
      expect(await client.generateJson('p', {}), {'ok': true});
      expect(calls, 2);
      expect(waits, [const Duration(seconds: 60)]);
    });

    test('a second refusal or another error fails with its message', () async {
      var calls = 0;
      final client = GeminiClient(
        apiKey: 'k',
        httpClient: MockClient((r) async {
          calls++;
          return http.Response(
            jsonEncode({
              'error': {'message': 'Quota exceeded\n for model'},
            }),
            429,
          );
        }),
        wait: (_) async {},
      );
      await expectLater(
        client.generateJson('p', {}),
        throwsA(
          isA<GeminiFailure>().having(
            (e) => e.toString(),
            'text',
            'Gemini: HTTP 429: Quota exceeded for model',
          ),
        ),
      );
      expect(calls, 2);
      final notFound = GeminiClient(
        apiKey: 'k',
        httpClient: MockClient((r) async => http.Response('x' * 300, 404)),
        wait: (_) async {},
      );
      await expectLater(
        notFound.generateJson('p', {}),
        throwsA(
          isA<GeminiFailure>().having(
            (e) => e.message,
            'message',
            'HTTP 404: ${'x' * 200}…',
          ),
        ),
      );
    });

    test('a dropped request or no answer in time fails', () async {
      final dropped = GeminiClient(
        apiKey: 'k',
        httpClient: MockClient(
          (r) async => throw http.ClientException('reset'),
        ),
      );
      await expectLater(
        dropped.generateJson('p', {}),
        throwsA(
          isA<GeminiFailure>().having(
            (e) => e.message,
            'm',
            'request failed: reset',
          ),
        ),
      );
      final slow = GeminiClient(
        apiKey: 'k',
        httpClient: MockClient((r) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        slow.generateJson('p', {}),
        throwsA(
          isA<GeminiFailure>().having(
            (e) => e.message,
            'm',
            'no answer in time',
          ),
        ),
      );
    });
  });

  group('answerJson', () {
    test('the first candidate\'s text, a code fence tolerated', () {
      expect(answerJson(_answer({'a': 1})), {'a': 1});
      final fenced = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': '```json\n[1]\n```'},
              ],
            },
          },
        ],
      });
      expect(answerJson(fenced), [1]);
    });

    test('anything else fails with why', () {
      Matcher fails(String message) =>
          throwsA(isA<GeminiFailure>().having((e) => e.message, 'm', message));
      expect(() => answerJson('<html>'), fails('the answer is not JSON'));
      expect(
        () => answerJson(
          jsonEncode({
            'candidates': [
              {'finishReason': 'SAFETY'},
            ],
          }),
        ),
        fails('no text (finish reason SAFETY)'),
      );
      expect(() => answerJson('{}'), fails('no text in the answer'));
      expect(
        () => answerJson(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Sure! Here it is'},
                  ],
                },
              },
            ],
          }),
        ),
        fails('the text is not JSON'),
      );
    });
  });
}
