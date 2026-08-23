import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fidel/application/providers/sensor_derived_providers.dart';

void main() {
  group('headingFromRotationVector', () {
    test('identity quaternion points north (azimuth 0)', () {
      expect(headingFromRotationVector(const [0, 0, 0, 1]), 0.0);
    });

    test('east yields 90 degrees', () {
      // Rotation of -90° about the vertical (z) axis:
      // yawNum = -2zw = 1, yawDen = 1 - 2z² = 0 -> atan2(1, 0) = +90°.
      const s = math.sqrt1_2;
      final east = headingFromRotationVector([0, 0, -s, s]);
      expect(east, closeTo(90, 1e-9));
    });

    test('negative azimuth normalizes into [0, 360)', () {
      // +1° rotation about z produces a raw azimuth of -1°; the caller
      // contract guarantees wrap normalization to 359°.
      const halfRad = math.pi / 360;
      final wrapped = headingFromRotationVector([
        0,
        0,
        math.sin(halfRad),
        math.cos(halfRad),
      ]);
      expect(wrapped, isNotNull);
      expect(wrapped!, closeTo(359, 1e-9));
      expect(wrapped, greaterThanOrEqualTo(0));
      expect(wrapped, lessThan(360));
    });

    test('NaN-bearing garbage input returns null', () {
      expect(headingFromRotationVector([double.nan, 0, 0]), isNull);
      expect(headingFromRotationVector([double.nan, 0, 0, 1]), isNull);
    });

    test('fewer than three values returns null', () {
      expect(headingFromRotationVector(const []), isNull);
      expect(headingFromRotationVector(const [0.5]), isNull);
      expect(headingFromRotationVector(const [0.5, 0.5]), isNull);
    });

    test('three-value vector infers w', () {
      // [0, 0, 0] infers w = sqrt(max(0, 1)) = 1 -> north.
      expect(headingFromRotationVector(const [0, 0, 0]), 0.0);

      // Inferred w must match the explicitly-provided counterpart:
      // [0, 0, 0.5] -> w = sqrt(1 - 0.25), azimuth -60° -> 300°.
      const z = 0.5;
      final inferred = headingFromRotationVector([0, 0, z]);
      final explicit = headingFromRotationVector([
        0,
        0,
        z,
        math.sqrt(math.max(0, 1 - z * z)),
      ]);
      expect(inferred, closeTo(300, 1e-9));
      expect(inferred, explicit);
    });
  });
}
