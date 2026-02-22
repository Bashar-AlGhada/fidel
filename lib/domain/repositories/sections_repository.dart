import '../entities/info/info_section_entity.dart';
import '../entities/sensors/sensor_entity.dart';

abstract class SectionsRepository {
  Future<InfoSectionEntity> getSectionMetadata(
    String sectionId, {
    bool forceRefresh = false,
  });

  Stream<InfoSectionEntity> watchSectionMetadata(String sectionId);

  Stream<List<SensorEntity>> watchSensors({
    int maxSamples = 128,
    int samplingPeriodUs = 200000,
  });
}
