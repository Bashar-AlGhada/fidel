import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/entities/testers/gps_fix_entity.dart';
import '../../domain/entities/testers/network_status_entity.dart';
import '../../domain/entities/testers/noise_level_entity.dart';
import '../../domain/repositories/tester_feeds_repository.dart';
import '../../infrastructure/mappers/gps_fix_mapper.dart';
import '../../infrastructure/mappers/network_status_mapper.dart';
import '../../infrastructure/mappers/noise_level_mapper.dart';
import '../../infrastructure/repositories_impl/tester_feeds_repository_impl.dart';
import 'system_providers.dart';

final testerFeedsRepositoryProvider = Provider<TesterFeedsRepository>((ref) {
  final repository = TesterFeedsRepositoryImpl(
    datasource: ref.read(androidSystemDatasourceProvider),
    networkStatusMapper: const NetworkStatusMapper(),
    noiseLevelMapper: const NoiseLevelMapper(),
    gpsFixMapper: const GpsFixMapper(),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final noiseLevelStreamProvider = StreamProvider.autoDispose<NoiseLevelEntity>(
  (ref) => ref.watch(testerFeedsRepositoryProvider).watchNoiseLevel(),
);

final networkStatusStreamProvider =
    StreamProvider.autoDispose<NetworkStatusEntity>(
      (ref) => ref.watch(testerFeedsRepositoryProvider).watchNetworkStatus(),
    );

final gpsFixStreamProvider = StreamProvider.autoDispose<GpsFixEntity>(
  (ref) => ref.watch(testerFeedsRepositoryProvider).watchGpsFix(),
);

/// Toggles the privacy-safe aggregate BLE scan. Returns true when the
/// platform accepted it, so the UI can revert its switch on failure.
final setBleScanningProvider = Provider<Future<bool> Function(bool)>((ref) {
  return (enabled) async {
    final result = await ref
        .read(androidSystemDatasourceProvider)
        .setBleScanningResult(enabled: enabled);
    return result['ok'] == true;
  };
});
