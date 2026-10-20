import 'dart:io';

import 'package:collector/collector.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

void main() {
  test('each expected failure has its message and exit code', () {
    final cases = <Object, (String, int)>{
      ConfigException('SUPABASE_URL is not set'): ('Configuration error: ', 78),
      const FetchBlocked('HTTP 429'): ('Stopped, the site pushed back: ', 75),
      const FetchLimitReached('20 requests this run'): ('Not fetched: ', 75),
      const FetchRefused('paused until 2026-10-21'): ('Not fetched: ', 75),
      const FetchFailed('HTTP 500'): ('Failed: ', 75),
      const PostgrestException(message: 'timeout'): (
        'Database error: timeout',
        70,
      ),
      const FileSystemException('Folder not found', 'pages'): (
        'Cannot read input: Folder not found (pages)',
        66,
      ),
      const FormatException('bad JSON'): ('Invalid input: bad JSON', 65),
      const NotifyFailed('HTTP 502'): ('Not sent: ', 69),
    };
    for (final MapEntry(key: error, value: (prefix, code)) in cases.entries) {
      final failure = describeFailure(error);
      expect(failure?.message, startsWith(prefix), reason: '$error');
      expect(failure?.code, code, reason: '$error');
    }
  });

  test('the wording runStatus reads in the log is kept', () {
    final blocked = describeFailure(const FetchBlocked('HTTP 429'))!;
    expect(runStatus(75, blocked.message), 'blocked');
  });

  test('anything unexpected is not described, so it crashes loudly', () {
    expect(describeFailure(StateError('bug')), isNull);
    expect(describeFailure(ArgumentError('bug')), isNull);
  });
}
