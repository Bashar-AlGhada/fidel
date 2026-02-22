import '../../domain/units/unit_types.dart';
import '../../domain/units/units_formatter.dart';

class UnitsFormatterImpl implements UnitsFormatter {
  @override
  String formatTemperature({
    required double celsius,
    required TemperatureUnit unit,
  }) {
    return switch (unit) {
      TemperatureUnit.celsius => '${celsius.toStringAsFixed(1)}°C',
      TemperatureUnit.fahrenheit =>
        '${(celsius * 9 / 5 + 32).toStringAsFixed(1)}°F',
    };
  }

  @override
  String formatBytes({required int bytes, required DataSizeBase base}) {
    if (bytes < 0) return '0 B';
    if (bytes < 1024) return '$bytes B';

    final k = base == DataSizeBase.base2 ? 1024.0 : 1000.0;
    final units = base == DataSizeBase.base2
        ? const ['KiB', 'MiB', 'GiB', 'TiB']
        : const ['kB', 'MB', 'GB', 'TB'];

    var value = bytes.toDouble();
    var idx = -1;
    while (value >= k && idx < units.length - 1) {
      value /= k;
      idx++;
    }
    final decimals = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
    return '${value.toStringAsFixed(decimals)} ${units[idx]}';
  }

  @override
  String formatRate({
    required double bytesPerSecond,
    required RateUnit unit,
    required DataSizeBase base,
  }) {
    final isBits = unit == RateUnit.bitsPerSecond;
    final raw = isBits ? bytesPerSecond * 8.0 : bytesPerSecond;
    final suffix = isBits ? 'bps' : 'B/s';

    final k = base == DataSizeBase.base2 ? 1024.0 : 1000.0;
    final units = base == DataSizeBase.base2
        ? const ['K', 'M', 'G', 'T']
        : const ['k', 'M', 'G', 'T'];

    var value = raw;
    var idx = -1;
    while (value >= k && idx < units.length - 1) {
      value /= k;
      idx++;
    }
    final decimals = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
    final prefix = idx >= 0 ? units[idx] : '';
    return '${value.toStringAsFixed(decimals)} $prefix$suffix';
  }
}
