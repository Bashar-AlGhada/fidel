import 'dart:convert';

String _pretty(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);

/// Human-readable multi-line JSON rendering of a raw platform payload.
String prettyJson(Object? value) => _pretty(value);

/// Lowercased serialization used for case-insensitive payload search.
String searchablePayload(Map<String, dynamic> payload) =>
    _pretty(payload).toLowerCase();
