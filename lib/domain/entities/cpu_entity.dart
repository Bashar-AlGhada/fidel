import '../value_objects/percentage.dart';

class CpuEntity {
  const CpuEntity({
    required this.usage,
    required this.cores,
    this.coreUsages = const [],
    this.coreFreqsMhz = const [],
  });

  final Percentage usage;
  final int cores;

  /// Per-core utilization ratios (0..1), padded/truncated to [cores]
  /// by the mapper.
  final List<double> coreUsages;

  /// Per-core clock speeds in MHz; a null entry means the platform did
  /// not report a frequency for that core. Same length as [cores].
  final List<double?> coreFreqsMhz;
}
