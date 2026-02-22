import '../entities/battery_entity.dart';
import '../repositories/system_repository.dart';

class StreamBattery {
  const StreamBattery(this._repo);

  final SystemRepository _repo;

  Stream<BatteryEntity> call() => _repo.watchBattery();
}
