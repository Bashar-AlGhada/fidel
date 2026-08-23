/// Shared field-coercion helpers for loosely-typed platform payloads.
///
/// Platform channels deliver loosely-typed JSON maps; these helpers give
/// every mapper the same lenient int/double/String semantics in one place.
library;

int coerceInt(Object? raw, {required int fallback}) {
  return switch (raw) {
    int v => v,
    num v => v.toInt(),
    String v => int.tryParse(v) ?? fallback,
    _ => fallback,
  };
}

double coerceDouble(Object? raw, {required double fallback}) {
  return switch (raw) {
    num v => v.toDouble(),
    String v => double.tryParse(v) ?? fallback,
    _ => fallback,
  };
}

Map<String, dynamic> coerceMap(Object? raw) {
  if (raw is Map) return raw.cast<String, dynamic>();
  return const {};
}
