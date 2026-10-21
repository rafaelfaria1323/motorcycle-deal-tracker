import 'package:collector/collector.dart';
import 'package:test/test.dart';

void main() {
  group('runHealthMessage', () {
    const log =
        '== standvirtual ==\n'
        'Stopped, the site pushed back: HTTP 429\n'
        '== olx ==\n'
        'Database error: timeout\n';

    test('the same status as last time sends nothing', () {
      for (final s in ['ok', 'blocked', 'failed']) {
        expect(runHealthMessage(previous: s, current: s, log: log), isNull);
      }
    });

    test('the first run ever is news only when it went wrong', () {
      expect(runHealthMessage(previous: null, current: 'ok', log: ''), isNull);
      expect(
        runHealthMessage(previous: null, current: 'failed', log: log)?['title'],
        '⚠️ A recolha de anúncios falhou.',
      );
    });

    test('a failure says what went wrong on which site', () {
      expect(runHealthMessage(previous: 'ok', current: 'failed', log: log), {
        'title': '⚠️ A recolha de anúncios falhou.',
        'body':
            'standvirtual: Stopped, the site pushed back: HTTP 429\n'
            'olx: Database error: timeout\n'
            'Os preços na app podem ficar desatualizados até a recolha voltar '
            'a funcionar.',
        'url': '/#/collection-status',
        'tag': 'run-health',
      });
    });

    test('a block says the site waits 24 hours', () {
      expect(
        runHealthMessage(previous: 'failed', current: 'blocked', log: log),
        containsPair(
          'title',
          '⛔ Um site recusou os pedidos da recolha de anúncios.',
        ),
      );
      expect(
        runHealthMessage(previous: 'ok', current: 'blocked', log: '')?['body'],
        'A recolha desse site fica em pausa durante 24 h e volta a tentar '
        'automaticamente.',
      );
    });

    test('the recovery is told once', () {
      for (final s in ['blocked', 'failed']) {
        final message = runHealthMessage(previous: s, current: 'ok', log: log);
        expect(
          message?['title'],
          '✅ A recolha de anúncios voltou a funcionar.',
        );
        expect(message?['body'], '');
      }
    });
  });

  group('runProblems', () {
    test('error lines with their site; other lines and Skipped ignored', () {
      const log =
          '== standvirtual ==\n'
          '  search: Yamaha MT-07\n'
          'Skipped: Honda CB650R has no standvirtual search\n'
          'Not fetched: daily limit of 120 requests\n'
          '== olx ==\n'
          '  Failed: HTTP 500\n'
          'Not a search results page: == no state ==\n'
          'Cannot read the saved pages: gone (samples/olx)\n'
          '== all sites ==\n'
          'Database error: scores\n'
          'Refresh finished in 90 s, 2 site(s) failed.\n'
          'make: *** [Makefile:88: refresh] Error 70\n';

      expect(runProblems(log), [
        'standvirtual: Not fetched: daily limit of 120 requests',
        'olx: Failed: HTTP 500',
        'olx: Not a search results page: == no state ==',
        'olx: Cannot read the saved pages: gone (samples/olx)',
        'Database error: scores',
      ]);
    });

    test('without error lines, the last line that is not make\'s', () {
      const log =
          'Missing SUPABASE_URL\n'
          'Refresh finished in 0 s.\n'
          'make: *** [Makefile:88: refresh] Error 1\n\n';

      expect(runProblems(log), ['Missing SUPABASE_URL']);
      expect(runProblems('make: *** Error 1'), isEmpty);
      expect(runProblems(''), isEmpty);
    });

    test('at most max lines, each cut to maxChars', () {
      final log = List.generate(8, (i) => 'Failed: $i ${'x' * 30}').join('\n');
      final problems = runProblems(log, max: 3, maxChars: 12);

      expect(problems, ['Failed: 0 x…', 'Failed: 1 x…', 'Failed: 2 x…']);
      expect(runProblems('Failed: short', maxChars: 13), ['Failed: short']);
    });
  });
}
