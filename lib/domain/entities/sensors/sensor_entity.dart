import 'bounded_sample_window.dart';
import 'sensor_capability_entity.dart';
import 'sensor_reading_entity.dart';

class SensorEntity {
  const SensorEntity({required this.capability, required this.samples});

  final SensorCapabilityEntity capability;
  final BoundedSampleWindow<SensorReadingEntity> samples;
}
