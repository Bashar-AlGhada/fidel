import '../value_objects/percentage.dart';

class CpuEntity {
  const CpuEntity({required this.usage, required this.cores});

  final Percentage usage;
  final int cores;
}
