import 'info_availability.dart';
import 'info_item_entity.dart';

class InfoSectionEntity {
  const InfoSectionEntity({
    required this.id,
    required this.titleKey,
    required this.items,
    this.availability = InfoAvailability.available,
  });

  final String id;
  final String titleKey;
  final List<InfoItemEntity> items;
  final InfoAvailability availability;
}
