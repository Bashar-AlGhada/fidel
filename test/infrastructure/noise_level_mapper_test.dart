import 'package:flutter_test/flutter_test.dart';
import 'package:fidel/infrastructure/mappers/noise_level_mapper.dart';

void main() {
  const mapper = NoiseLevelMapper();

  test('level frame maps dbfs, spl and peak', () {
    final e = mapper.fromMap(const {
      'kind': 'level',
      'dbfs': -23.5,
      'spl': 76.5,
      'peakDbfs': -10.25,
    });
    expect(e, isNotNull);
    expect(e!.dbfs, -23.5);
    expect(e.splApprox, 76.5);
    expect(e.peakDbfs, -10.25);
  });

  test('error frames return null so callers keep the previous sample', () {
    expect(
      mapper.fromMap(const {'kind': 'error', 'message': 'mic busy'}),
      isNull,
    );
  });

  test('kind mismatch (missing/unknown kind) returns null', () {
    expect(mapper.fromMap(const {'dbfs': -3.0}), isNull);
    expect(mapper.fromMap(const {'kind': 'future-kind'}), isNull);
  });
}
