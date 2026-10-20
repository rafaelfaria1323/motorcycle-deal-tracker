import 'dart:io';

import 'package:collector/src/adapters/saved_pages.dart';
import 'package:test/test.dart';

void main() {
  group('listHtmlFiles', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('saved_pages'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('keeps only .html files (any case), sorted by path', () async {
      for (final name in ['b.html', 'a.HTML', 'c.json', 'd.txt']) {
        File('${dir.path}/$name').writeAsStringSync('x');
      }
      Directory('${dir.path}/e.html').createSync();

      final files = await listHtmlFiles(dir.path);

      expect(files.map((f) => f.uri.pathSegments.last), ['a.HTML', 'b.html']);
    });

    test('throws when the folder is missing', () {
      expect(
        listHtmlFiles('${dir.path}/missing'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('staleIssue', () {
    const maxAge = Duration(hours: 6);

    test('is null up to the maximum age', () {
      expect(staleIssue(0, 'a.html', maxAge, maxAge), isNull);
    });

    test('reports an older file with its message and search', () {
      final issue = staleIssue(
        2,
        'a.html',
        const Duration(hours: 30),
        maxAge,
        search: 's',
      )!;
      expect(issue.index, 2);
      expect(issue.search, 's');
      expect(
        issue.message,
        'a.html: saved 30 h ago (older than 6 h), so it may be out of date',
      );
    });
  });
}
