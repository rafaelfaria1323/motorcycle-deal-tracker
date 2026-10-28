import 'dart:io';

import 'package:collector/collector.dart';
import 'package:test/test.dart';

/// Stands in for tool/photo_examine.py: the same line protocol, with
/// behaviour chosen by the first byte of each photo.
const _script = r'''
import base64, json, sys, time
mode = sys.argv[2] if len(sys.argv) > 2 else ''
if mode == 'silent':
    time.sleep(30)
if mode == 'garbage':
    print('hello', flush=True)
    sys.exit()
print(json.dumps({'ready': 'fake-clip'}), flush=True)
for line in sys.stdin:
    photo = base64.b64decode(json.loads(line)['image'])
    if photo[0] == 1:
        print(json.dumps({'error': 'unreadable'}), flush=True)
    elif photo[0] == 2:
        sys.exit(1)
    elif photo[0] == 3:
        time.sleep(30)
    else:
        print(json.dumps({'scores': {'fallen': 0.75, 'ok': 0.25},
                          'features': 'AQI='}), flush=True)
''';

void main() {
  late Directory dir;
  late String script;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('examiner');
    File('${dir.path}/vision_model.onnx').writeAsStringSync('');
    File('${dir.path}/text_model.onnx').writeAsStringSync('');
    script = '${dir.path}/examine.py';
    File(script).writeAsStringSync(_script);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<ProcessPhotoExaminer?> start(
    StringSink log, {
    String? modelDir,
    String? path,
    String python = 'python3',
    Duration startTimeout = const Duration(seconds: 20),
    Duration photoTimeout = const Duration(seconds: 20),
  }) => ProcessPhotoExaminer.start(
    python: python,
    script: path ?? script,
    modelDir: modelDir ?? dir.path,
    log: log,
    startTimeout: startTimeout,
    photoTimeout: photoTimeout,
  );

  test('answers each photo; one it cannot read is null', () async {
    final log = StringBuffer();
    final examiner = (await start(log))!;
    expect(examiner.model, 'fake-clip');
    expect('$log', contains('Photo hints on: fake-clip.'));

    final answer = await examiner.examine([0, 9]);
    expect(answer!.scores, {'fallen': 0.75, 'ok': 0.25});
    expect(answer.features, 'AQI=');
    expect(await examiner.examine([1]), isNull);
    expect((await examiner.examine([0]))!.scores['fallen'], 0.75);
    await examiner.close();
  });

  test('a process that dies, or takes too long, fails for good', () async {
    final examiner = (await start(
      StringBuffer(),
      photoTimeout: const Duration(seconds: 2),
    ))!;
    await expectLater(
      examiner.examine([3]),
      throwsA(isA<PhotoExaminerFailed>()),
    );
    // Never asked again once failed.
    await expectLater(
      examiner.examine([0]),
      throwsA(isA<PhotoExaminerFailed>()),
    );
    await examiner.close();

    final dying = (await start(StringBuffer()))!;
    await expectLater(dying.examine([2]), throwsA(isA<PhotoExaminerFailed>()));
    await dying.close();
  });

  test('off, with the reason, when it cannot start', () async {
    final missing = StringBuffer();
    expect(await start(missing, modelDir: '${dir.path}/none'), isNull);
    expect('$missing', contains('vision_model.onnx is missing'));

    final noScript = StringBuffer();
    expect(await start(noScript, path: '${dir.path}/none.py'), isNull);
    expect('$noScript', contains('none.py is missing'));

    final noPython = StringBuffer();
    expect(await start(noPython, python: '${dir.path}/no-python'), isNull);
    expect('$noPython', contains('did not start'));
  });

  test('off when it never says it is ready', () async {
    File(script).writeAsStringSync(
      _script.replaceFirst(
        "mode = sys.argv[2] if len(sys.argv) > 2 else ''",
        "mode = 'garbage'",
      ),
    );
    final garbage = StringBuffer();
    expect(await start(garbage), isNull);
    expect('$garbage', contains('did not say it was ready'));

    File(script).writeAsStringSync(
      _script.replaceFirst(
        "mode = sys.argv[2] if len(sys.argv) > 2 else ''",
        "mode = 'silent'",
      ),
    );
    final silent = StringBuffer();
    expect(
      await start(silent, startTimeout: const Duration(seconds: 1)),
      isNull,
    );
    expect('$silent', contains('took too long to start'));
  });
}
