import 'dart:math' as math;

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'system_providers.dart';

/// Heading (0-360°, 0 = magnetic north) derived live from the device's
/// rotation-vector sensor via the standard sensors feed. No extra
/// permissions or native code required.
final headingProvider = Provider.autoDispose<double?>((ref) {
  final sensors =
      ref
          .watch(sensorsStreamProvider(ref.watch(sensorsConfigProvider)))
          .asData
          ?.value ??
      const [];
  // 11 = Sensor.TYPE_ROTATION_VECTOR; deliberately excludes the game
  // variant (type 15), which is not north-referenced.
  final rv = sensors.where((s) => s.capability.type == 11);
  if (rv.isEmpty) return null;
  final samples = rv.first.samples.samples;
  if (samples.isEmpty) return null;
  return headingFromRotationVector(samples.last.values);
});

/// Derives a compass heading in degrees (0 inclusive, 360 exclusive,
/// 0 = magnetic north) from one rotation-vector sample. Accepts either
/// the full `[x, y, z, w]` quaternion or the compact `[x, y, z]` form,
/// where w is inferred as sqrt(max(0, 1 - x² - y² - z²)). Returns null
/// for fewer than three values or undefined (NaN) input.
double? headingFromRotationVector(List<double> values) {
  if (values.length < 3) return null;

  final x = values[0], y = values[1], z = values[2];
  final w = values.length >= 4
      ? values[3]
      : math.sqrt(math.max(0, 1 - x * x - y * y - z * z));

  // Quaternion -> device-to-world rotation -> azimuth per Android's
  // getOrientation(): atan2(R[0][1], R[1][1]) with
  //   R[0][1] = 2(xy - zw),  R[1][1] = 1 - 2(x^2 + z^2).
  // Valid in portrait; other orientations would need
  // remapCoordinateSystem.
  final yawNum = 2 * (x * y - z * w);
  final yawDen = 1 - 2 * (x * x + z * z);
  final azimuth = math.atan2(yawNum, yawDen);

  if (azimuth.isNaN) return null;
  var deg = azimuth * 180 / math.pi;
  deg = (deg % 360 + 360) % 360;
  return deg;
}
