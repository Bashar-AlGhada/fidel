import '../entities/testers/gps_fix_entity.dart';
import '../entities/testers/network_status_entity.dart';
import '../entities/testers/noise_level_entity.dart';

/// Live feeds backing the tester tools (noise meter, network monitor,
/// GNSS).
abstract class TesterFeedsRepository {
  Stream<NoiseLevelEntity> watchNoiseLevel();

  Stream<NetworkStatusEntity> watchNetworkStatus();

  Stream<GpsFixEntity> watchGpsFix();

  void dispose();
}
