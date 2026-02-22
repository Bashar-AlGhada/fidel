import '../entities/info/info_section_entity.dart';
import '../repositories/sections_repository.dart';

class GetSectionMetadata {
  const GetSectionMetadata(this._repo);

  final SectionsRepository _repo;

  Future<InfoSectionEntity> call(
    String sectionId, {
    bool forceRefresh = false,
  }) {
    return _repo.getSectionMetadata(sectionId, forceRefresh: forceRefresh);
  }
}
