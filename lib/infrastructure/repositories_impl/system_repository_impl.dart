import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;

import '../../domain/entities/battery_entity.dart';
import '../../domain/entities/cpu_entity.dart';
import '../../domain/entities/memory_entity.dart';
import '../../domain/repositories/system_repository.dart';
import '../datasources/android_system_datasource.dart';
import '../mappers/battery_mapper.dart';
import '../mappers/cpu_mapper.dart';
import '../mappers/memory_mapper.dart';

class SystemRepositoryImpl implements SystemRepository {
  SystemRepositoryImpl({
    required AndroidSystemDatasource datasource,
    required BatteryMapper batteryMapper,
    required MemoryMapper memoryMapper,
    required CpuMapper cpuMapper,
  }) : _datasource = datasource,
       _batteryMapper = batteryMapper,
       _memoryMapper = memoryMapper,
       _cpuMapper = cpuMapper;

  final AndroidSystemDatasource _datasource;
  final BatteryMapper _batteryMapper;
  final MemoryMapper _memoryMapper;
  final CpuMapper _cpuMapper;

  /// Cold-start guard: sources that stay silent (dead channel, missing
  /// native side) surface as a `feed_timeout` error instead of leaving
  /// consumers in Loading forever.
  static const Duration _feedTimeout = Duration(seconds: 5);

  /// The sink-based [Stream.timeout] callback keeps the stream open and
  /// resets its countdown on every event, so late data still flows after
  /// a timeout fired.
  Stream<T> _guardFeedTimeout<T>(Stream<T> source) => source.timeout(
    _feedTimeout,
    onTimeout: (EventSink<T> sink) => sink.addError(
      PlatformException(
        code: 'feed_timeout',
        message: 'Native feed did not produce data.',
      ),
    ),
  );

  @override
  Stream<BatteryEntity> watchBattery() =>
      _guardFeedTimeout(_datasource.batteryRaw())
          .map(_batteryMapper.fromMap)
          .transform(StreamTransformer.fromBind(_withEstimatedCurrent));

  @override
  Stream<MemoryEntity> watchMemory() =>
      _guardFeedTimeout(_datasource.memoryRaw()).map(_memoryMapper.fromMap);

  @override
  Stream<CpuEntity> watchCpu() =>
      // No placeholder pre-emission: real data or the timeout guard is
      // the first thing consumers see.
      _guardFeedTimeout(_datasource.cpuRaw()).map(_cpuMapper.fromMap);

  /// Attaches the rolling-window coulomb-count estimate to every event.
  static Stream<BatteryEntity> _withEstimatedCurrent(
    Stream<BatteryEntity> events,
  ) async* {
    final counter = _CoulombCounter();
    await for (final event in events) {
      yield event.copyWith(
        estimatedCurrentMicroAmps: counter.push(
          event.chargeCounterUah,
          DateTime.now(),
        ),
      );
    }
  }
}

/// Rolling-window coulomb counter: derives pack current from the drift
/// of the fuel gauge's reported charge ([BatteryEntity.chargeCounterUah])
/// over time.
///
/// Sign convention matches Android's CURRENT_NOW and therefore
/// [BatteryEntity.currentMicroAmps]: **negative while discharging,
/// positive while charging**. The raw charge delta already carries that
/// polarity (the counter drains while discharging), so no negation is
/// applied.
///
/// Pure Dart with an injected timestamp, hence trivially testable.
class _CoulombCounter {
  final List<_ChargeSample> _samples = [];

  static const Duration window = Duration(seconds: 10);
  static const Duration minSpan = Duration(seconds: 3);

  /// Records a reading and returns the current-window estimate, or null
  /// while fewer than two distinct points span [minSpan]. A null reading
  /// suppresses the estimate for that event but retains the window.
  int? push(int? uah, DateTime timestamp) {
    if (uah == null) return null;

    final last = _samples.isEmpty ? null : _samples.last;
    if (last != null && !timestamp.isAfter(last.at)) {
      // Same-tick re-report: refresh the value so timestamps stay
      // strictly ascending and the window math stays well-defined.
      _samples[_samples.length - 1] = _ChargeSample(uah, timestamp);
    } else {
      _samples.add(_ChargeSample(uah, timestamp));
    }

    // Trim past the window tail but always keep the two most recent
    // distinct points.
    while (_samples.length > 2 &&
        timestamp.difference(_samples.first.at) > window) {
      _samples.removeAt(0);
    }

    return estimate();
  }

  /// Estimate across the oldest/newest window points:
  /// ΔµAh / Δh == µA. Null until the window satisfies [minSpan].
  int? estimate() {
    if (_samples.length < 2) return null;
    final oldest = _samples.first;
    final newest = _samples.last;
    final microseconds = newest.at.difference(oldest.at).inMicroseconds;
    if (microseconds < minSpan.inMicroseconds) return null;
    final hours = microseconds / Duration.microsecondsPerHour;
    return ((newest.uah - oldest.uah) / hours).round();
  }
}

class _ChargeSample {
  const _ChargeSample(this.uah, this.at);

  final int uah;
  final DateTime at;
}
