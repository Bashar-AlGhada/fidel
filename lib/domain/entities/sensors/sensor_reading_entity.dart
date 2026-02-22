import 'sensor_accuracy.dart';

class SensorReadingEntity {
  const SensorReadingEntity({
    required this.timestamp,
    required this.values,
    this.accuracy,
  });

  final DateTime timestamp;
  final List<double> values;
  final SensorAccuracy? accuracy;
}
