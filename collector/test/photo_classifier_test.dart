import 'dart:convert';
import 'dart:math' as math;

import 'package:collector/collector.dart';
import 'package:test/test.dart';

/// [count] photos of 6 features: problems lean to +0.3 on the first, fine
/// ones to -0.3, plus a common part and noise (fixed seed).
List<PhotoSample> _samples(int problems, int fine, {int seed = 1}) {
  final random = math.Random(seed);
  PhotoSample one(bool problem) => (
    features: [
      (problem ? 0.3 : -0.3) + (random.nextDouble() - 0.5) * 0.2,
      0.5 + (random.nextDouble() - 0.5) * 0.1,
      for (var j = 0; j < 4; j++) (random.nextDouble() - 0.5) * 0.4,
    ],
    problem: problem,
  );
  return [
    for (var i = 0; i < problems; i++) one(true),
    for (var i = 0; i < fine; i++) one(false),
  ]..shuffle(random);
}

class _Store implements ListingStore {
  _Store(this.set);

  final PhotoTrainingSet set;
  PhotoClassifier? stored;
  String? model;
  String? marksKey;

  @override
  Future<PhotoTrainingSet> photoTrainingSet(String model) async => set;

  @override
  Future<int> storePhotoClassifier(
    String model,
    PhotoClassifier classifier, {
    required String marksKey,
  }) async {
    this.model = model;
    stored = classifier;
    this.marksKey = marksKey;
    return 7;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('trainPhotoClassifier', () {
    test('needs enough photos of each kind', () {
      expect(trainPhotoClassifier(_samples(9, 30)), isNull);
      expect(trainPhotoClassifier(_samples(30, 9)), isNull);
      expect(trainPhotoClassifier(_samples(10, 10)), isNotNull);
    });

    test('learns which side a problem is on, on the raw features', () {
      final classifier = trainPhotoClassifier(_samples(20, 40))!;
      expect(classifier.samples, 60);
      expect(classifier.problems, 20);
      expect(classifier.weights, hasLength(6));
      final problem = <double>[0.35, 0.5, 0, 0, 0, 0];
      final fine = <double>[-0.35, 0.5, 0, 0, 0, 0];
      expect(classifier.share(problem), greaterThan(0.8));
      expect(classifier.share(fine), lessThan(0.2));
      expect(classifier.accuracy, greaterThan(0.9));
    });

    test('fewer problems weigh as much as many fine photos', () {
      final classifier = trainPhotoClassifier(_samples(10, 90))!;
      // Halfway between the two kinds stays near the line.
      expect(classifier.share(<double>[0, 0.5, 0, 0, 0, 0]), closeTo(0.5, 0.2));
    });

    test('the same marks give the same classifier', () {
      final a = trainPhotoClassifier(_samples(12, 15))!;
      final b = trainPhotoClassifier(_samples(12, 15))!;
      expect(a.weights, b.weights);
      expect(a.bias, b.bias);
      expect(a.accuracy, b.accuracy);
    });

    test('photos with nothing to tell apart learn nothing certain', () {
      final random = math.Random(3);
      final samples = [
        for (var i = 0; i < 40; i++)
          (
            features: [for (var j = 0; j < 6; j++) random.nextDouble() - 0.5],
            problem: i.isEven,
          ),
      ];
      final classifier = trainPhotoClassifier(samples)!;
      expect(classifier.accuracy, lessThan(0.75));
    });

    test('a feature the same in every photo does no harm', () {
      final samples = [
        for (final s in _samples(10, 10))
          (features: [...s.features, 0.2], problem: s.problem),
      ];
      final classifier = trainPhotoClassifier(samples)!;
      expect(classifier.weights.every((w) => w.isFinite), isTrue);
      expect(classifier.bias.isFinite, isTrue);
    });

    test('no accuracy when the folds would leave a kind out', () {
      expect(
        trainPhotoClassifier(_samples(3, 3), minPerClass: 3)!.accuracy,
        isNull,
      );
      expect(
        trainPhotoClassifier(_samples(5, 5), minPerClass: 5)!.accuracy,
        isNotNull,
      );
    });
  });

  test('featuresFromBase64 reads signed bytes over 127', () {
    expect(featuresFromBase64(base64Encode([127, 129, 0])), [1, -1, 0]);
  });

  group('trainOnPhotoMarks', () {
    test('nothing when the marks did not change', () async {
      final store = _Store((
        samples: _samples(20, 20),
        marksKey: '40@t',
        trainedKey: '40@t',
      ));
      final log = StringBuffer();
      expect(await trainOnPhotoMarks(store, 'clip', out: log), 0);
      expect(store.stored, isNull);
      expect('$log', isEmpty);
    });

    test('says how many are still missing', () async {
      final store = _Store((
        samples: _samples(4, 12),
        marksKey: '16@t',
        trainedKey: null,
      ));
      final log = StringBuffer();
      expect(await trainOnPhotoMarks(store, 'clip', out: log), 0);
      expect(store.stored, isNull);
      expect(
        '$log',
        'Photo marks: 4 problem(s), 12 fine; 10 of each before learning '
            'from them.\n',
      );
    });

    test('trains and stores it with the marks it learned from', () async {
      final store = _Store((
        samples: _samples(20, 20),
        marksKey: '40@t2',
        trainedKey: '30@t1',
      ));
      final log = StringBuffer();
      expect(await trainOnPhotoMarks(store, 'clip', out: log), 7);
      expect(store.model, 'clip');
      expect(store.marksKey, '40@t2');
      expect(store.stored!.samples, 40);
      expect(
        '$log',
        matches(
          r'^Photo classifier trained on 40 mark\(s\) \(20 problem\(s\)\), '
          r'\d+ % right on photos it did not learn from; hints refreshed '
          r'for 7 listing\(s\)\.\n$',
        ),
      );
    });
  });
}
