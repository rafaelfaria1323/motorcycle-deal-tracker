import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../store/listing_store.dart';

/// Fewest marked photos of each kind (problem, fine) before a classifier is
/// trained: fewer and it learns the few photos, not what they show.
const minMarksPerClass = 10;

/// One marked photo: its embedding as numbers (P.2's signed bytes / 127)
/// and whether an admin marked it as a problem.
typedef PhotoSample = ({List<double> features, bool problem});

/// The admins' marks for one image model, as `photo_training_set` returns
/// them: the photos, the marks' state now ([marksKey]) and the state the
/// stored classifier was trained on ([trainedKey], null: none).
typedef PhotoTrainingSet = ({
  List<PhotoSample> samples,
  String marksKey,
  String? trainedKey,
});

/// A logistic regression over an image model's embedding (P.3): the
/// probability that a photo is like the ones marked as a problem is
/// sigmoid(bias + weights · features). The database applies it as the hint
/// `learned` (`photo_learned_share`).
class PhotoClassifier {
  const PhotoClassifier({
    required this.weights,
    required this.bias,
    required this.samples,
    required this.problems,
    required this.accuracy,
  });

  final List<double> weights;
  final double bias;

  /// What it learned from: marked photos, of which problems.
  final int samples;
  final int problems;

  /// Balanced accuracy on photos it did not learn from (k-fold), null when
  /// there are too few for that.
  final double? accuracy;

  /// The share for one photo, as `photo_learned_share`.
  double share(List<double> features) =>
      _sigmoid(_logit(weights, bias, features));
}

/// The signed bytes of a stored embedding (base64) as numbers in [-1, 1],
/// as the database reads them.
List<double> featuresFromBase64(String encoded) => [
  for (final byte in base64Decode(encoded))
    (byte > 127 ? byte - 256 : byte) / 127,
];

/// Trains on [samples] (all the same length), or null when either kind has
/// fewer than [minPerClass] photos. Deterministic: the same marks give the
/// same classifier.
///
/// The features are standardised to train (CLIP's embeddings share a large
/// common part) and the scaling is folded back into the weights and the
/// bias, so the database applies it to the stored bytes as they are. Each
/// kind weighs the same however many photos it has, so 0.5 stays the line
/// between them, and L2 keeps a few hundred weights from learning the
/// photos one by one. Each step is [rate] / the number of features: the
/// standardised features' spread adds up to that number, so the descent
/// can't overshoot whatever the photos.
PhotoClassifier? trainPhotoClassifier(
  List<PhotoSample> samples, {
  int minPerClass = minMarksPerClass,
  int folds = 5,
  int epochs = 1000,
  double rate = 4,
  double l2 = 0.01,
}) {
  final problems = samples.where((s) => s.problem).length;
  if (problems < minPerClass || samples.length - problems < minPerClass) {
    return null;
  }
  final model = _fit(samples, epochs: epochs, rate: rate, l2: l2);
  return PhotoClassifier(
    weights: model.weights,
    bias: model.bias,
    samples: samples.length,
    problems: problems,
    accuracy: _crossValidated(
      samples,
      folds: folds,
      fit: (train) => _fit(train, epochs: epochs, rate: rate, l2: l2),
    ),
  );
}

/// Balanced accuracy over [folds] folds (photo i in fold i % folds), each
/// predicted by a classifier trained on the others; null when a fold would
/// leave a kind out of its training.
double? _crossValidated(
  List<PhotoSample> samples, {
  required int folds,
  required ({List<double> weights, double bias}) Function(List<PhotoSample>)
  fit,
}) {
  final problems = samples.where((s) => s.problem).length;
  final fine = samples.length - problems;
  if (folds < 2 || problems < folds || fine < folds) return null;
  var problemsRight = 0;
  var fineRight = 0;
  for (var f = 0; f < folds; f++) {
    final train = [
      for (final (i, s) in samples.indexed)
        if (i % folds != f) s,
    ];
    if (train.every((s) => s.problem) || !train.any((s) => s.problem)) {
      return null;
    }
    final model = fit(train);
    for (final (i, s) in samples.indexed) {
      if (i % folds != f) continue;
      final saysProblem = _logit(model.weights, model.bias, s.features) >= 0;
      if (s.problem && saysProblem) problemsRight++;
      if (!s.problem && !saysProblem) fineRight++;
    }
  }
  return (problemsRight / problems + fineRight / fine) / 2;
}

({List<double> weights, double bias}) _fit(
  List<PhotoSample> samples, {
  required int epochs,
  required double rate,
  required double l2,
}) {
  final n = samples.length;
  final d = samples.first.features.length;

  // Mean and spread of each feature (a constant one keeps spread 1).
  final mean = List<double>.filled(d, 0);
  for (final s in samples) {
    for (var j = 0; j < d; j++) {
      mean[j] += s.features[j] / n;
    }
  }
  final spread = List<double>.filled(d, 0);
  for (final s in samples) {
    for (var j = 0; j < d; j++) {
      final x = s.features[j] - mean[j];
      spread[j] += x * x / n;
    }
  }
  for (var j = 0; j < d; j++) {
    spread[j] = spread[j] > 1e-12 ? math.sqrt(spread[j]) : 1;
  }
  final xs = [
    for (final s in samples)
      [for (var j = 0; j < d; j++) (s.features[j] - mean[j]) / spread[j]],
  ];

  // Each kind weighs half.
  final problems = samples.where((s) => s.problem).length;
  final sampleWeight = [
    for (final s in samples) s.problem ? 0.5 / problems : 0.5 / (n - problems),
  ];

  final step = rate / d;
  final w = List<double>.filled(d, 0);
  var b = 0.0;
  final gradient = List<double>.filled(d, 0);
  for (var epoch = 0; epoch < epochs; epoch++) {
    gradient.fillRange(0, d, 0);
    var gradientB = 0.0;
    for (var i = 0; i < n; i++) {
      final x = xs[i];
      final error =
          (_sigmoid(_logit(w, b, x)) - (samples[i].problem ? 1 : 0)) *
          sampleWeight[i];
      for (var j = 0; j < d; j++) {
        gradient[j] += error * x[j];
      }
      gradientB += error;
    }
    for (var j = 0; j < d; j++) {
      w[j] -= step * (gradient[j] + l2 * w[j]);
    }
    b -= step * gradientB;
  }

  // Back to the raw features: w·(x - mean)/spread + b.
  final weights = [for (var j = 0; j < d; j++) w[j] / spread[j]];
  var bias = b;
  for (var j = 0; j < d; j++) {
    bias -= weights[j] * mean[j];
  }
  return (weights: weights, bias: bias);
}

double _logit(List<double> weights, double bias, List<double> features) {
  var z = bias;
  for (var j = 0; j < weights.length; j++) {
    z += weights[j] * features[j];
  }
  return z;
}

double _sigmoid(double z) => 1 / (1 + math.exp(-z.clamp(-50, 50)));

/// Trains [model]'s classifier on the admins' marks when they changed
/// since the stored one, and stores it (the database then refreshes every
/// examined listing's hints). Returns how many listings were refreshed; 0
/// when nothing changed or there are still too few marks.
Future<int> trainOnPhotoMarks(
  ListingStore store,
  String model, {
  StringSink? out,
}) async {
  final log = out ?? stdout;
  final set = await store.photoTrainingSet(model);
  if (set.marksKey == set.trainedKey) return 0;
  final problems = set.samples.where((s) => s.problem).length;
  final classifier = trainPhotoClassifier(set.samples);
  if (classifier == null) {
    log.writeln(
      'Photo marks: $problems problem(s), ${set.samples.length - problems} '
      'fine; $minMarksPerClass of each before learning from them.',
    );
    return 0;
  }
  final refreshed = await store.storePhotoClassifier(
    model,
    classifier,
    marksKey: set.marksKey,
  );
  final accuracy = classifier.accuracy;
  log.writeln(
    'Photo classifier trained on ${classifier.samples} mark(s) '
    '(${classifier.problems} problem(s))'
    '${accuracy == null ? '' : ', ${(accuracy * 100).round()} % right on '
              'photos it did not learn from'}'
    '; hints refreshed for $refreshed listing(s).',
  );
  return refreshed;
}
