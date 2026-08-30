import 'dart:math' as math;

const String _dash = '—';

const List<String> _superscriptDigits = <String>[
  '⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹',
];

String formatMeasurement(
  num? value, {
  int maxSignificantDigits = 4,
  String? unit,
}) {
  if (value == null) return _dash;
  final d = value.toDouble();
  if (d.isNaN || d.isInfinite) return _dash;
  if (d == 0) return '0';

  final negative = d.isNegative;
  final abs = d.abs();
  var body = (abs >= 1e6 || abs < 1e-4)
      ? _formatScientific(abs, maxSignificantDigits)
      : _formatFixed(abs, maxSignificantDigits);
  if (negative) body = '-$body';
  if (unit == null || unit.isEmpty) return body;
  return '$body\u2009$unit';
}

String formatList(List<double> values) {
  return values.map((v) => formatMeasurement(v)).join(', ');
}

String _formatFixed(double abs, int sigDigits) {
  final magnitude = _magnitudeOf(abs);
  var decimals = sigDigits - 1 - magnitude;
  String out;
  if (decimals > 0) {
    out = abs.toStringAsFixed(math.min(decimals, 20));
  } else {
    final factor = math.pow(10.0, -decimals).toDouble();
    out = ((abs / factor).roundToDouble() * factor).toStringAsFixed(0);
  }
  return _stripTrailingZeros(out);
}

String _formatScientific(double abs, int sigDigits) {
  var exp = _magnitudeOf(abs);
  var mantissa = abs / math.pow(10.0, exp).toDouble();
  var mantissaText = _stripTrailingZeros(mantissa.toStringAsPrecision(sigDigits));
  final mantissaValue = double.tryParse(mantissaText) ?? mantissa;
  if (mantissaValue >= 10 || mantissaValue < 1) {
    mantissa /= mantissaValue;
    exp += _magnitudeOf(mantissaValue);
    mantissaText =
        _stripTrailingZeros(mantissa.toStringAsPrecision(sigDigits));
  }
  return '$mantissaText×10${_superscript(exp)}';
}

int _magnitudeOf(double v) {
  var m = (math.log(v) / math.ln10).floor();
  while (m > -400 && v < math.pow(10.0, m).toDouble()) {
    m--;
  }
  while (m < 308 && v >= math.pow(10.0, m + 1).toDouble()) {
    m++;
  }
  return m;
}

String _stripTrailingZeros(String text) {
  if (!text.contains('.')) return text;
  return text
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _superscript(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value.isNegative ? '⁻' : '');
  for (var i = 0; i < digits.length; i++) {
    buffer.write(_superscriptDigits[int.parse(digits[i])]);
  }
  return buffer.toString();
}
