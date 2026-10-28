import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// What the image model saw in one photo (P.2): the share of each code
/// (`crashed`, `fallen`, `scratches`, ..., and the alternatives `ok` and
/// `other`) and the photo's embedding (base64), kept for a classifier
/// trained later on Rafael's marks (P.3).
typedef PhotoExamination = ({Map<String, double> scores, String features});

/// The examiner stopped answering (it died, or took too long): no more
/// photos are given to it this run.
class PhotoExaminerFailed implements Exception {
  const PhotoExaminerFailed(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Examines photos already downloaded for their fingerprints, so the hints
/// cost no request.
abstract interface class PhotoExaminer {
  /// The model's name, stored with its answers.
  String get model;

  /// The model's answer, or null when it could not read this photo.
  /// Throws [PhotoExaminerFailed] when the examiner itself failed.
  Future<PhotoExamination?> examine(List<int> photo);

  Future<void> close();
}

/// tool/photo_examine.py in its own process, one JSON line per photo each
/// way. The photos go through its stdin and are never written to disk.
class ProcessPhotoExaminer implements PhotoExaminer {
  ProcessPhotoExaminer._(this._process, this._lines, this.model, this._timeout);

  final Process _process;
  final StreamIterator<String> _lines;
  final Duration _timeout;
  var _failed = false;

  @override
  final String model;

  /// Starts [script] with [python] on [modelDir] and waits for its ready
  /// line; null (with the reason in [log]) when it can't start, so the
  /// photos are still fingerprinted without hints.
  static Future<ProcessPhotoExaminer?> start({
    required String python,
    required String script,
    required String modelDir,
    required StringSink log,
    Duration startTimeout = const Duration(minutes: 2),
    Duration photoTimeout = const Duration(seconds: 30),
  }) async {
    for (final name in ['vision_model.onnx', 'text_model.onnx']) {
      if (!File('$modelDir/$name').existsSync()) {
        log.writeln('Photo hints off: $modelDir/$name is missing.');
        return null;
      }
    }
    if (!File(script).existsSync()) {
      log.writeln('Photo hints off: $script is missing.');
      return null;
    }
    final Process process;
    try {
      process = await Process.start(python, [script, modelDir]);
    } on ProcessException catch (e) {
      log.writeln('Photo hints off: $python did not start ($e).');
      return null;
    }
    // Its warnings go to the log, never into the answers.
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => log.writeln('  examiner: $line'));
    final lines = StreamIterator(
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    );
    try {
      if (await lines.moveNext().timeout(startTimeout)) {
        final ready = jsonDecode(lines.current);
        if (ready case {'ready': final String model}) {
          log.writeln('Photo hints on: $model.');
          return ProcessPhotoExaminer._(process, lines, model, photoTimeout);
        }
      }
      log.writeln('Photo hints off: the examiner did not say it was ready.');
    } on TimeoutException {
      log.writeln('Photo hints off: the examiner took too long to start.');
    } on FormatException {
      log.writeln('Photo hints off: the examiner did not say it was ready.');
    }
    process.kill();
    return null;
  }

  @override
  Future<PhotoExamination?> examine(List<int> photo) async {
    if (_failed) throw const PhotoExaminerFailed('the examiner failed');
    try {
      _process.stdin.writeln(jsonEncode({'image': base64Encode(photo)}));
      await _process.stdin.flush();
      if (!await _lines.moveNext().timeout(_timeout)) {
        throw const PhotoExaminerFailed('the examiner stopped');
      }
      return switch (jsonDecode(_lines.current)) {
        {'scores': final Map<String, dynamic> s, 'features': final String f} =>
          (
            scores: {
              for (final e in s.entries) e.key: (e.value as num).toDouble(),
            },
            features: f,
          ),
        _ => null,
      };
    } on TimeoutException {
      _fail();
      throw const PhotoExaminerFailed('the examiner took too long');
    } on PhotoExaminerFailed {
      _fail();
      rethrow;
    } on Object catch (e) {
      // A broken pipe or an answer that isn't JSON: the process is no use.
      _fail();
      throw PhotoExaminerFailed('the examiner failed ($e)');
    }
  }

  void _fail() {
    _failed = true;
    _process.kill();
  }

  @override
  Future<void> close() async {
    if (!_failed) {
      await _process.stdin.close();
      await _process.exitCode.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _process.kill();
          return -1;
        },
      );
    }
    await _lines.cancel();
  }
}
