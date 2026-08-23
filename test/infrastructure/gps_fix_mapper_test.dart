import 'package:flutter_test/flutter_test.dart';
import 'package:fidel/infrastructure/mappers/gps_fix_mapper.dart';

void main() {
  const mapper = GpsFixMapper();

  test('non-fix kinds return null', () {
    expect(mapper.fromMap(const {'kind': 'satellites'}), isNull);
    expect(
      mapper.fromMap(const {'kind': 'error', 'message': 'denied'}),
      isNull,
    );
    expect(mapper.fromMap(const {}), isNull);
  });

  test('fix maps numeric and string lat/lon', () {
    final e = mapper.fromMap(const {
      'kind': 'fix',
      'latitude': 52.52,
      'longitude': '13.405',
    });
    expect(e, isNotNull);
    expect(e!.latitude, 52.52);
    expect(e.longitude, 13.405);
    // Optional fields absent on the frame stay null.
    expect(e.altitudeM, isNull);
    expect(e.speedMps, isNull);
    expect(e.accuracyM, isNull);
    expect(e.bearingDeg, isNull);
  });

  test('satellite counts fall back to threaded-in status values', () {
    const frame = {'kind': 'fix', 'latitude': 0.0, 'longitude': 0.0};
    final e = mapper.fromMap(frame, satellitesUsed: 9, satellitesTotal: 24);
    expect(e!.satellitesUsed, 9);
    expect(e.satellitesTotal, 24);

    // Frame-provided counts take precedence over the threaded ones.
    final withCounts = mapper.fromMap(
      const {...frame, 'satellitesUsed': 11},
      satellitesUsed: 9,
      satellitesTotal: 24,
    );
    expect(withCounts!.satellitesUsed, 11);
    expect(withCounts.satellitesTotal, 24);

    // Absent everywhere -> null (the -1 sentinel never leaks).
    final bare = mapper.fromMap(frame);
    expect(bare!.satellitesUsed, isNull);
    expect(bare.satellitesTotal, isNull);
  });

  test("string 'NaN' altitude (and NaN numerics) become null fields", () {
    // double.tryParse('NaN') yields double.nan; the mapper's finite()
    // guard must turn that into a null field.
    final e = mapper.fromMap(const {
      'kind': 'fix',
      'latitude': 1.0,
      'longitude': 2.0,
      'altitudeM': 'NaN',
      'speedMps': double.nan,
      'accuracyM': 'Infinity',
    });
    expect(e!.altitudeM, isNull);
    expect(e.speedMps, isNull);
    expect(e.accuracyM, isNull);
  });
}
