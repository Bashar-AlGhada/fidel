import '../entities/info/info_section_entity.dart';
import '../repositories/sections_repository.dart';

class WatchSectionMetadata {
  const WatchSectionMetadata(this._repo);

  final SectionsRepository _repo;

  Stream<InfoSectionEntity> call(String sectionId) {
    return _repo.watchSectionMetadata(sectionId);
  }
}
