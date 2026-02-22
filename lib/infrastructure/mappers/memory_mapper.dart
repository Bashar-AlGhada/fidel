import '../../domain/entities/memory_entity.dart';

class MemoryMapper {
  MemoryEntity fromMap(Map<String, dynamic> map) {
    final avail = map['availBytes'];
    final total = map['totalBytes'];

    return MemoryEntity(
      availBytes: switch (avail) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v) ?? 0,
        _ => 0,
      },
      totalBytes: switch (total) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v) ?? 0,
        _ => 0,
      },
    );
  }
}
