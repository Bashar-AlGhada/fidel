import '../entities/memory_entity.dart';
import '../repositories/system_repository.dart';

class StreamMemory {
  const StreamMemory(this._repo);

  final SystemRepository _repo;

  Stream<MemoryEntity> call() => _repo.watchMemory();
}
