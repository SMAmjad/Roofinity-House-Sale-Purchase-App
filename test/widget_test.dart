import 'package:flutter_test/flutter_test.dart';
import 'package:roofinity/utils/image_authenticity_service.dart';

void main() {
  group('AuthenticityResult.fromScores', () {
    const threshold = ImageAuthenticityService.fakeThreshold;

    test('all images below the threshold are authentic', () {
      final result = AuthenticityResult.fromScores([0.01, 0.2, 0.59]);
      expect(result.verdict, AuthenticityVerdict.authentic);
      expect(result.flaggedIndexes, isEmpty);
      expect(result.maxFakeScore, 0.59);
    });

    test('one image above the threshold makes the set fake', () {
      final result = AuthenticityResult.fromScores([0.1, 0.95, 0.3, 0.7]);
      expect(result.verdict, AuthenticityVerdict.fake);
      expect(result.flaggedIndexes, [1, 3]);
      expect(result.maxFakeScore, 0.95);
    });

    test('Firestore map carries the verdict and model details', () {
      final map = AuthenticityResult.fromScores([0.2]).toFirestore();
      expect(map['verdict'], 'authentic');
      expect(map['threshold'], threshold);
      expect(map['modelVersion'], ImageAuthenticityService.modelVersion);
    });
  });
}
