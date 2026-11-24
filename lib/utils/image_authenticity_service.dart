import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Outcome of running the fake-property-image model over a set of images.
enum AuthenticityVerdict { authentic, fake, error }

class AuthenticityResult {
  final AuthenticityVerdict verdict;

  /// Fake probability for each image, in the same order as the input list.
  final List<double> fakeScores;
  final double threshold;
  final String? errorMessage;

  const AuthenticityResult._({
    required this.verdict,
    this.fakeScores = const [],
    required this.threshold,
    this.errorMessage,
  });

  /// Verdict for a set of per-image fake probabilities: fake if any image
  /// scores above [threshold].
  factory AuthenticityResult.fromScores(
    List<double> scores, {
    double threshold = ImageAuthenticityService.fakeThreshold,
  }) {
    final anyFake = scores.any((s) => s > threshold);
    return AuthenticityResult._(
      verdict: anyFake ? AuthenticityVerdict.fake : AuthenticityVerdict.authentic,
      fakeScores: scores,
      threshold: threshold,
    );
  }

  bool get isAuthentic => verdict == AuthenticityVerdict.authentic;

  double get maxFakeScore =>
      fakeScores.isEmpty ? 0 : fakeScores.reduce((a, b) => a > b ? a : b);

  /// Zero-based indexes of the images the model flagged as fake.
  List<int> get flaggedIndexes => [
        for (var i = 0; i < fakeScores.length; i++)
          if (fakeScores[i] > threshold) i,
      ];

  /// Shape stored on the ad document in Firestore.
  Map<String, dynamic> toFirestore() => {
        'verdict': verdict.name,
        'maxFakeScore': maxFakeScore,
        'fakeScores': fakeScores,
        'threshold': threshold,
        'modelVersion': ImageAuthenticityService.modelVersion,
      };
}

/// Runs the on-device TFLite model trained in
/// `E:\AIML\Fake Property Image Detection (tflite)` (EfficientNetB0, 2 classes:
/// index 0 = real, index 1 = fake).
///
/// The model was trained on raw 0–255 pixel values: Keras' EfficientNetB0 does
/// its own rescaling internally, so images must NOT be divided by 255 here.
class ImageAuthenticityService {
  ImageAuthenticityService._();
  static final ImageAuthenticityService instance = ImageAuthenticityService._();

  static const String modelAsset = 'assets/false_property_detector.tflite';
  static const String modelVersion = 'efficientnet_b0-v1';

  /// Chosen during training for >= 90% recall on the fake class
  /// (exports/threshold.json).
  static const double fakeThreshold = 0.5980272889137268;

  Interpreter? _interpreter;
  Future<Interpreter>? _loading;
  int _inputHeight = 224;
  int _inputWidth = 224;

  /// Serialises inference so two checks never use the interpreter at once.
  Future<void> _queue = Future.value();

  Future<Interpreter> _ensureLoaded() {
    final existing = _interpreter;
    if (existing != null) return Future.value(existing);
    return _loading ??= _load();
  }

  Future<Interpreter> _load() async {
    try {
      final interpreter = await Interpreter.fromAsset(modelAsset);
      final inputTensor = interpreter.getInputTensor(0);
      final shape = inputTensor.shape; // [1, H, W, 3]
      if (inputTensor.type != TensorType.float32 ||
          shape.length != 4 ||
          shape[3] != 3) {
        interpreter.close();
        throw StateError(
          'Unexpected model input: ${inputTensor.type} $shape '
          '(expected float32 [1, H, W, 3]).',
        );
      }
      _inputHeight = shape[1];
      _inputWidth = shape[2];
      _interpreter = interpreter;
      debugPrint('[AI] Model loaded, input shape $shape');
      return interpreter;
    } catch (e) {
      _loading = null; // allow a retry on the next call
      rethrow;
    }
  }

  /// Loads the model ahead of time so the first check is quick.
  Future<void> warmUp() async {
    try {
      await _ensureLoaded();
    } catch (e) {
      debugPrint('[AI] Model warm-up failed: $e');
    }
  }

  /// Checks every image. The result is [AuthenticityVerdict.fake] if any image
  /// scores above [fakeThreshold], and [AuthenticityVerdict.error] if the check
  /// could not run (the caller must not treat that as authentic).
  Future<AuthenticityResult> checkImages(List<File> images) {
    final run = _queue.then((_) => _check(images));
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<AuthenticityResult> _check(List<File> images) async {
    if (images.isEmpty) {
      return const AuthenticityResult._(
        verdict: AuthenticityVerdict.error,
        threshold: fakeThreshold,
        errorMessage: 'No images to check.',
      );
    }
    try {
      final interpreter = await _ensureLoaded();
      final scores = await _scoreInBackground(
        interpreter.address,
        images.map((f) => f.path).toList(),
        _inputHeight,
        _inputWidth,
      );

      debugPrint('[AI] Fake scores: $scores');
      return AuthenticityResult.fromScores(scores);
    } catch (e) {
      debugPrint('[AI] Authenticity check failed: $e');
      return AuthenticityResult._(
        verdict: AuthenticityVerdict.error,
        threshold: fakeThreshold,
        errorMessage: e.toString(),
      );
    }
  }
}

/// Top-level (not async, not a method) so the closure sent to the isolate
/// captures only these four sendable values.
Future<List<double>> _scoreInBackground(
  int interpreterAddress,
  List<String> paths,
  int height,
  int width,
) {
  return Isolate.run(
    () => _scoreImages(interpreterAddress, paths, height, width),
    debugName: 'roofinity-ai-check',
  );
}

/// Runs in a background isolate: decodes, resizes and scores each image.
List<double> _scoreImages(
  int interpreterAddress,
  List<String> paths,
  int height,
  int width,
) {
  final interpreter =
      Interpreter.fromAddress(interpreterAddress, allocated: true);
  final scores = <double>[];

  for (final path in paths) {
    final decoded = img.decodeImage(File(path).readAsBytesSync());
    if (decoded == null) {
      throw FormatException('Unsupported image format: $path');
    }

    // 8-bit RGB (expands palettes, drops alpha), then bilinear resize, the
    // same as tf.keras image_dataset_from_directory used during training.
    // Phone photos are often stored sideways with an EXIF rotation tag;
    // rotate them upright like the training images.
    final upright = img.bakeOrientation(decoded);
    final rgb = upright.convert(format: img.Format.uint8, numChannels: 3);
    final resized = img.copyResize(
      rgb,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );

    // Raw RGB values in 0–255 (no normalisation, see class docs).
    final input = Float32List(height * width * 3);
    var i = 0;
    for (final pixel in resized) {
      input[i++] = pixel.r.toDouble();
      input[i++] = pixel.g.toDouble();
      input[i++] = pixel.b.toDouble();
    }

    final output = [List<double>.filled(2, 0)];
    interpreter.run(input.buffer, output);
    scores.add(output[0][1]); // probability of class "fake"
  }
  return scores;
}
