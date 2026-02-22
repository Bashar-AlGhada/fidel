import '../entities/cpu_entity.dart';
import '../repositories/system_repository.dart';

class StreamCpu {
  const StreamCpu(this._repo);

  final SystemRepository _repo;

  Stream<CpuEntity> call() => _repo.watchCpu();
}
