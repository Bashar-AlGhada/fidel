import '../entities/sensors/sensor_entity.dart';
import '../repositories/sections_repository.dart';

class WatchSensors {
  const WatchSensors(this._repo);

  final SectionsRepository _repo;

  Stream<List<SensorEntity>> call({
    int maxSamples = 128,
    int samplingPeriodUs = 200000,
  }) {
    return _repo.watchSensors(
      maxSamples: maxSamples,
      samplingPeriodUs: samplingPeriodUs,
    );
  }
}
