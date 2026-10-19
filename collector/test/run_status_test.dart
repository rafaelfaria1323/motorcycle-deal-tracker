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
}
