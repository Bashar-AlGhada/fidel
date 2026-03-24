import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fidel/infrastructure/cache/local_cache_store.dart';
import 'package:fidel/infrastructure/datasources/android_system_datasource.dart';
import 'package:fidel/infrastructure/mappers/info_section_mapper.dart';
import 'package:fidel/infrastructure/mappers/sensor_event_mapper.dart';
import 'package:fidel/infrastructure/repositories_impl/sections_repository_impl.dart';

class FakeCacheStore extends LocalCacheStore {
  @override
  Future<Map<String, dynamic>?> readMap(String key) async {
    return null;
  }

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {}
}

class FakeAndroidSystemDatasource extends AndroidSystemDatasource {
  FakeAndroidSystemDatasource({
    required StreamController<Map<String, dynamic>> controller,
  }) : _controller = controller;

  final StreamController<Map<String, dynamic>> _controller;

  @override
  Stream<Map<String, dynamic>> sensorEventsRaw({int? samplingPeriodUs}) {
    return _controller.stream;
  }
}

void main() {
  test('watchSensors starts feed on listen and stops on cancel', () async {
    var listenCount = 0;
    var cancelCount = 0;

    final controller = StreamController<Map<String, dynamic>>(
      onListen: () => listenCount += 1,
      onCancel: () => cancelCount += 1,
    );
    addTearDown(controller.close);

    final repo = SectionsRepositoryImpl(
      datasource: FakeAndroidSystemDatasource(controller: controller),
      infoSectionMapper: InfoSectionMapper(),
      sensorEventMapper: SensorEventMapper(),
      cacheStore: FakeCacheStore(),
    );

    final stream = repo.watchSensors(maxSamples: 32, samplingPeriodUs: 200000);
    expect(listenCount, 0);

    final sub = stream.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(listenCount, 1);

    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(cancelCount, 1);
  });
}
