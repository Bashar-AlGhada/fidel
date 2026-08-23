import '../../domain/entities/memory_entity.dart';
import '../../core/utils/map_coercion.dart';

class MemoryMapper {
  MemoryEntity fromMap(Map<String, dynamic> map) {
    return MemoryEntity(
      availBytes: coerceInt(map['availBytes'], fallback: 0),
      totalBytes: coerceInt(map['totalBytes'], fallback: 0),
    );
  }
}
