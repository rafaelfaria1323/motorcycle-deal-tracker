import 'dart:io';

import 'package:collector/collector.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('manifest_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('writes and reads back the same manifest', () async {
    await const SearchManifest(
      planned: ['a', 'b'],
      files: {'p1.html': 'a', 'p2.html': 'a'},
    ).writeTo(dir.path);
    final read = (await SearchManifest.readFrom(dir.path))!;
    expect(read.planned, ['a', 'b']);
    expect(read.files, {'p1.html': 'a', 'p2.html': 'a'});
    expect(read.fetched, {'a'});
  });

  test('a folder without a manifest gives null', () async {
    expect(await SearchManifest.readFrom(dir.path), isNull);
  });

  test('invalid JSON or a wrong shape is a FormatException', () async {
    final file = File('${dir.path}/${SearchManifest.fileName}');
    file.writeAsStringSync('not json');
    await expectLater(SearchManifest.readFrom(dir.path), throwsFormatException);
    file.writeAsStringSync('{"planned": [], "files": []}');
    await expectLater(SearchManifest.readFrom(dir.path), throwsFormatException);
    file.writeAsStringSync('[]');
    await expectLater(SearchManifest.readFrom(dir.path), throwsFormatException);
  });
}
