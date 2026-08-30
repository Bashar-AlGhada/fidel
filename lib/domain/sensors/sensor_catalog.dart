import 'package:flutter/material.dart';

class SensorCatalogEntry {
  const SensorCatalogEntry({
    required this.nameKey,
    required this.descriptionKey,
    required this.icon,
    required this.axes,
    required this.unit,
  });

  final String nameKey;
  final String descriptionKey;
  final IconData icon;
  final List<String> axes;
  final String unit;
}

class SensorCatalog {
  const SensorCatalog._();

  static const SensorCatalogEntry unknown = SensorCatalogEntry(
    nameKey: 'sensor.type.unknown',
    descriptionKey: 'sensor.typeDesc.unknown',
    icon: Icons.sensors,
    axes: <String>[],
    unit: '',
  );

  static const Map<int, SensorCatalogEntry> _entries = <int,
      SensorCatalogEntry>{
    1: SensorCatalogEntry(
      nameKey: 'sensor.type.accelerometer',
      descriptionKey: 'sensor.typeDesc.accelerometer',
      icon: Icons.speed,
      axes: <String>['sensor.axis.x', 'sensor.axis.y', 'sensor.axis.z'],
      unit: 'm/s²',
    ),
    2: SensorCatalogEntry(
      nameKey: 'sensor.type.magneticField',
      descriptionKey: 'sensor.typeDesc.magneticField',
      icon: Icons.compass_calibration,
      axes: <String>['sensor.axis.x', 'sensor.axis.y', 'sensor.axis.z'],
      unit: 'µT',
    ),
    3: SensorCatalogEntry(
      nameKey: 'sensor.type.orientation',
      descriptionKey: 'sensor.typeDesc.orientation',
      icon: Icons.explore,
      axes: <String>[
        'sensor.axis.azimuth',
        'sensor.axis.pitch',
        'sensor.axis.roll',
      ],
      unit: '°',
    ),
    4: SensorCatalogEntry(
      nameKey: 'sensor.type.gyroscope',
      descriptionKey: 'sensor.typeDesc.gyroscope',
      icon: Icons.threesixty,
      axes: <String>['sensor.axis.x', 'sensor.axis.y', 'sensor.axis.z'],
      unit: 'rad/s',
    ),
    5: SensorCatalogEntry(
      nameKey: 'sensor.type.light',
      descriptionKey: 'sensor.typeDesc.light',
      icon: Icons.light_mode,
      axes: <String>['sensor.axis.value'],
      unit: 'lx',
    ),
    6: SensorCatalogEntry(
      nameKey: 'sensor.type.pressure',
      descriptionKey: 'sensor.typeDesc.pressure',
      icon: Icons.compress,
      axes: <String>['sensor.axis.value'],
      unit: 'hPa',
    ),
    7: SensorCatalogEntry(
      nameKey: 'sensor.type.temperature',
      descriptionKey: 'sensor.typeDesc.temperature',
      icon: Icons.device_thermostat,
      axes: <String>['sensor.axis.value'],
      unit: '°C',
    ),
    8: SensorCatalogEntry(
      nameKey: 'sensor.type.proximity',
      descriptionKey: 'sensor.typeDesc.proximity',
      icon: Icons.sensors,
      axes: <String>['sensor.axis.value'],
      unit: 'cm',
    ),
    9: SensorCatalogEntry(
      nameKey: 'sensor.type.gravity',
      descriptionKey: 'sensor.typeDesc.gravity',
      icon: Icons.public,
      axes: <String>['sensor.axis.x', 'sensor.axis.y', 'sensor.axis.z'],
      unit: 'm/s²',
    ),
    10: SensorCatalogEntry(
      nameKey: 'sensor.type.linearAcceleration',
      descriptionKey: 'sensor.typeDesc.linearAcceleration',
      icon: Icons.trending_up,
      axes: <String>['sensor.axis.x', 'sensor.axis.y', 'sensor.axis.z'],
      unit: 'm/s²',
    ),
    11: SensorCatalogEntry(
      nameKey: 'sensor.type.rotationVector',
      descriptionKey: 'sensor.typeDesc.rotationVector',
      icon: Icons.rotate_right,
      axes: <String>['sensor.axis.x', 'sensor.axis.y', 'sensor.axis.z'],
      unit: '',
    ),
    12: SensorCatalogEntry(
      nameKey: 'sensor.type.relativeHumidity',
      descriptionKey: 'sensor.typeDesc.relativeHumidity',
      icon: Icons.water_drop,
      axes: <String>['sensor.axis.value'],
      unit: '%',
    ),
    13: SensorCatalogEntry(
      nameKey: 'sensor.type.ambientTemperature',
      descriptionKey: 'sensor.typeDesc.ambientTemperature',
      icon: Icons.thermostat,
      axes: <String>['sensor.axis.value'],
      unit: '°C',
    ),
    14: SensorCatalogEntry(
      nameKey: 'sensor.type.magneticFieldUncalibrated',
      descriptionKey: 'sensor.typeDesc.magneticFieldUncalibrated',
      icon: Icons.travel_explore,
      axes: <String>['sensor.axis.x', 'sensor.axis.y', 'sensor.axis.z'],
      unit: 'µT',
    ),
    15: SensorCatalogEntry(
      nameKey: 'sensor.type.gameRotationVector',
      descriptionKey: 'sensor.typeDesc.gameRotationVector',
      icon: Icons.sports_esports,
      axes: <String>['sensor.axis.x', 'sensor.axis.y', 'sensor.axis.z'],
      unit: '',
    ),
    16: SensorCatalogEntry(
      nameKey: 'sensor.type.gyroscopeUncalibrated',
      descriptionKey: 'sensor.typeDesc.gyroscopeUncalibrated',
      icon: Icons.autorenew,
      axes: <String>['sensor.axis.x', 'sensor.axis.y', 'sensor.axis.z'],
      unit: 'rad/s',
    ),
    17: SensorCatalogEntry(
      nameKey: 'sensor.type.significantMotion',
      descriptionKey: 'sensor.typeDesc.significantMotion',
      icon: Icons.directions_run,
      axes: <String>['sensor.axis.value'],
      unit: '',
    ),
    18: SensorCatalogEntry(
      nameKey: 'sensor.type.stepDetector',
      descriptionKey: 'sensor.typeDesc.stepDetector',
      icon: Icons.directions_walk,
      axes: <String>['sensor.axis.value'],
      unit: '',
    ),
    19: SensorCatalogEntry(
      nameKey: 'sensor.type.stepCounter',
      descriptionKey: 'sensor.typeDesc.stepCounter',
      icon: Icons.directions_walk,
      axes: <String>['sensor.axis.value'],
      unit: 'steps',
    ),
    20: SensorCatalogEntry(
      nameKey: 'sensor.type.geomagneticRotationVector',
      descriptionKey: 'sensor.typeDesc.geomagneticRotationVector',
      icon: Icons.navigation,
      axes: <String>['sensor.axis.x', 'sensor.axis.y', 'sensor.axis.z'],
      unit: '',
    ),
    21: SensorCatalogEntry(
      nameKey: 'sensor.type.heartRate',
      descriptionKey: 'sensor.typeDesc.heartRate',
      icon: Icons.monitor_heart,
      axes: <String>['sensor.axis.value'],
      unit: 'bpm',
    ),
    22: SensorCatalogEntry(
      nameKey: 'sensor.type.tiltDetector',
      descriptionKey: 'sensor.typeDesc.tiltDetector',
      icon: Icons.screen_rotation,
      axes: <String>['sensor.axis.value'],
      unit: '',
    ),
    26: SensorCatalogEntry(
      nameKey: 'sensor.type.wristTiltGesture',
      descriptionKey: 'sensor.typeDesc.wristTiltGesture',
      icon: Icons.watch,
      axes: <String>['sensor.axis.value'],
      unit: '',
    ),
    34: SensorCatalogEntry(
      nameKey: 'sensor.type.accelerometerUncalibrated',
      descriptionKey: 'sensor.typeDesc.accelerometerUncalibrated',
      icon: Icons.vibration,
      axes: <String>['sensor.axis.x', 'sensor.axis.y', 'sensor.axis.z'],
      unit: 'm/s²',
    ),
  };

  static SensorCatalogEntry lookup(int type) => _entries[type] ?? unknown;

  static bool isKnown(int type) => _entries.containsKey(type);
}
