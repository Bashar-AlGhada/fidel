import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/info/info_item_value.dart';
import '../../domain/entities/info/info_section_entity.dart';
import '../../domain/entities/sensors/sensor_entity.dart';
import '../../domain/export/export_format.dart';

class ExportService {
  static Object? sanitizeForExport(Object? value) {
    return ExportService()._sanitizeObject(value);
  }

  static String csvEncode(List<List<String>> rows) {
    return ExportService()._csv(rows);
  }

  Future<File> exportSection(
    InfoSectionEntity section, {
    required ExportFormat format,
    required String fileBaseName,
  }) async {
    return switch (format) {
      ExportFormat.json => _write(
        fileBaseName: fileBaseName,
        ext: 'json',
        content: const JsonEncoder.withIndent(
          '  ',
        ).convert(sanitizeForExport(_sectionToJson(section))),
      ),
      ExportFormat.csv => _write(
        fileBaseName: fileBaseName,
        ext: 'csv',
        content: _sectionToCsv(section),
      ),
    };
  }

  Future<File> exportSensors(
    List<SensorEntity> sensors, {
    required ExportFormat format,
    required String fileBaseName,
  }) async {
    return switch (format) {
      ExportFormat.json => _write(
        fileBaseName: fileBaseName,
        ext: 'json',
        content: const JsonEncoder.withIndent(
          '  ',
        ).convert(sanitizeForExport(_sensorsToJson(sensors))),
      ),
      ExportFormat.csv => _write(
        fileBaseName: fileBaseName,
        ext: 'csv',
        content: _sensorsToCsv(sensors),
      ),
    };
  }

  Future<File> exportSnapshot(
    Map<String, dynamic> snapshot, {
    required ExportFormat format,
    required String fileBaseName,
  }) async {
    final sanitized = sanitizeForExport(snapshot);
    return switch (format) {
      ExportFormat.json => _write(
        fileBaseName: fileBaseName,
        ext: 'json',
        content: const JsonEncoder.withIndent('  ').convert(sanitized),
      ),
      ExportFormat.csv => _write(
        fileBaseName: fileBaseName,
        ext: 'csv',
        content: _snapshotToCsv(sanitized),
      ),
    };
  }

  Future<void> share(File file) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  Map<String, dynamic> _sectionToJson(InfoSectionEntity section) {
    return <String, dynamic>{
      'sectionId': section.id,
      'titleKey': section.titleKey,
      'availability': section.availability.name,
      'items': section.items
          .map(
            (i) => <String, dynamic>{
              'labelKey': i.labelKey,
              'availability': i.availability.name,
              'sensitivity': i.sensitivity.name,
              'valueKind': i.value?.kind.name,
              'value': i.value?.kind == InfoItemValueKind.text
                  ? i.value?.text
                  : null,
            },
          )
          .toList(growable: false),
    };
  }

  String _sectionToCsv(InfoSectionEntity section) {
    final rows = <List<String>>[
      const ['labelKey', 'value', 'availability', 'sensitivity', 'valueKind'],
    ];
    for (final i in section.items) {
      final value = switch (i.value?.kind) {
        InfoItemValueKind.text => i.value?.text ?? '',
        InfoItemValueKind.redacted => 'redacted',
        InfoItemValueKind.hidden => 'hidden',
        _ => '',
      };
      rows.add([
        i.labelKey,
        value,
        i.availability.name,
        i.sensitivity.name,
        i.value?.kind.name ?? '',
      ]);
    }
    return _csv(rows);
  }

  Map<String, dynamic> _sensorsToJson(List<SensorEntity> sensors) {
    return <String, dynamic>{
      'sensors': sensors
          .map(
            (s) => <String, dynamic>{
              'capability': <String, dynamic>{
                'key': s.capability.key,
                'name': s.capability.name,
                'vendor': s.capability.vendor,
                'type': s.capability.type,
                'maxRange': s.capability.maxRange,
                'resolution': s.capability.resolution,
                'powerMilliAmp': s.capability.powerMilliAmp,
                'minDelayUs': s.capability.minDelay.inMicroseconds,
              },
              'samples': s.samples.samples
                  .map(
                    (r) => <String, dynamic>{
                      'timestampMs': r.timestamp.millisecondsSinceEpoch,
                      'values': r.values,
                      'accuracy': r.accuracy?.name,
                    },
                  )
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
    };
  }

  String _sensorsToCsv(List<SensorEntity> sensors) {
    final rows = <List<String>>[
      const [
        'key',
        'name',
        'vendor',
        'type',
        'timestampMs',
        'values',
        'accuracy',
      ],
    ];

    for (final s in sensors) {
      for (final r in s.samples.samples) {
        rows.add([
          s.capability.key,
          s.capability.name,
          s.capability.vendor,
          s.capability.type.toString(),
          r.timestamp.millisecondsSinceEpoch.toString(),
          jsonEncode(r.values),
          r.accuracy?.name ?? '',
        ]);
      }
    }

    return _csv(rows);
  }

  String _snapshotToCsv(Object? snapshot) {
    final rows = <List<String>>[
      const ['path', 'value'],
    ];
    _flatten(snapshot, path: '', out: rows);
    return _csv(rows);
  }

  void _flatten(
    Object? value, {
    required String path,
    required List<List<String>> out,
  }) {
    if (value == null) {
      out.add([path, '']);
      return;
    }
    if (value is Map) {
      final map = value.cast<String, dynamic>();
      for (final e in map.entries) {
        final nextPath = path.isEmpty ? e.key : '$path.${e.key}';
        _flatten(e.value, path: nextPath, out: out);
      }
      return;
    }
    if (value is List) {
      for (var i = 0; i < value.length; i++) {
        final nextPath = '$path[$i]';
        _flatten(value[i], path: nextPath, out: out);
      }
      return;
    }
    out.add([path, value.toString()]);
  }

  Future<File> _write({
    required String fileBaseName,
    required String ext,
    required String content,
  }) async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final safeBase = fileBaseName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File('${dir.path}${Platform.pathSeparator}$safeBase-$ts.$ext');
    await file.writeAsString(content, flush: true);
    return file;
  }

  Object? _sanitizeObject(Object? value) {
    if (value == null) return null;
    if (value is bool || value is num || value is String) return value;
    if (value is List) {
      return value.map(_sanitizeObject).toList(growable: false);
    }
    if (value is Map) {
      final map = value.cast<String, dynamic>();
      final out = <String, dynamic>{};
      for (final e in map.entries) {
        final key = e.key;
        if (_isSensitiveKey(key)) {
          out[key] = '<redacted>';
        } else {
          out[key] = _sanitizeObject(e.value);
        }
      }
      return out;
    }
    return value.toString();
  }

  bool _isSensitiveKey(String key) {
    final k = key.toLowerCase();
    const patterns = [
      'imei',
      'meid',
      'imsi',
      'iccid',
      'serial',
      'androidid',
      'android_id',
      'advertising',
      'adid',
      'mac',
      'bssid',
      'ssid',
      'fingerprint',
    ];
    for (final p in patterns) {
      if (k.contains(p)) return true;
    }
    return false;
  }

  String _csv(List<List<String>> rows) {
    final buf = StringBuffer();
    for (final row in rows) {
      buf.writeln(row.map(_csvCell).join(','));
    }
    return buf.toString();
  }

  String _csvCell(String value) {
    final needsQuotes =
        value.contains(',') ||
        value.contains('\n') ||
        value.contains('\r') ||
        value.contains('"');
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
