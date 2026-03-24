import 'unit_types.dart';

abstract class UnitsFormatter {
  String formatTemperature({
    required double celsius,
    required TemperatureUnit unit,
  });

  String formatBytes({required int bytes, required DataSizeBase base});

  String formatRate({
    required double bytesPerSecond,
    required RateUnit unit,
    required DataSizeBase base,
  });

  String formatElectricCurrent({required double microAmps});
}
