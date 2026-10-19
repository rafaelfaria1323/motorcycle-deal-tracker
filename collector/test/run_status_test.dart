import 'package:collector/collector.dart';
import 'package:test/test.dart';

void main() {
  test('exit code 0 is ok whatever the log says', () {
    expect(runStatus(0, 'Stopped, the site pushed back'), 'ok');
  });

  test('a push-back, a pause or the daily cap is a block', () {
    expect(runStatus(2, 'Stopped, the site pushed back: HTTP 429'), 'blocked');
    expect(runStatus(2, 'Not fetched: paused until 2026-10-20'), 'blocked');
    expect(runStatus(2, 'Not fetched: daily limit of 120 requests'), 'blocked');
  });

  test('anything else is a failure', () {
    expect(runStatus(2, 'Database error: timeout'), 'failed');
  });

  test('the tail keeps the last lines', () {
    final log = List.generate(100, (i) => 'line $i').join('\n');
    final tail = logTail(log, lines: 3);

    expect(tail, 'line 97\nline 98\nline 99');
  });

  test('the tail of a short or empty log is all of it', () {
    expect(logTail(''), '');
    expect(logTail('one\ntwo\n\n'), 'one\ntwo');
  });

  test('the tail is cut to the last characters', () {
    final log = List.generate(5, (i) => 'line $i').join('\n');

    expect(logTail(log, maxChars: 6), 'line 4');
  });

  test('reads the requests each site used', () {
    const log =
        'Requests used: standvirtual=15 (limit 20)\n'
        'Scored 89 listing(s).\n'
        'Requests used: olx=9 (limit 20)\n';

    expect(requestsUsed(log), {'standvirtual': 15, 'olx': 9});
    expect(requestsUsed('no counts here'), isEmpty);
  });
}
