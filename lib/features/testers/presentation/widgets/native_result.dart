/// Shared decoding for method-channel results whose native payload is
/// `{ok: bool, reason: String?}`.
///
/// [AndroidBridge] wraps successful invocations as
/// `{ok: true, data: <payload>}`, so the native verdict lives one level
/// deeper than the transport-level ok. When the invocation itself fails
/// (missing plugin, non-Android platform) the error code is surfaced as
/// the reason so callers can still show something specific.
({bool ok, String? reason}) decodeNativeResult(
  Map<String, dynamic> result,
) {
  if (result['ok'] != true) {
    final error = result['error'];
    final code = error is Map ? error['code']?.toString() : null;
    return (ok: false, reason: code);
  }
  final data = result['data'];
  if (data is Map) {
    return (ok: data['ok'] == true, reason: data['reason']?.toString());
  }
  return (ok: false, reason: null);
}
