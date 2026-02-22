import 'package:flutter/material.dart';

import 'presentation/cameras_section_page.dart';
import 'presentation/codecs_section_page.dart';
import 'presentation/sensors_section_page.dart';
import 'presentation/section_detail_page.dart';
import 'presentation/thermal_section_page.dart';

class SectionDefinition {
  const SectionDefinition({
    required this.id,
    required this.pathSegment,
    required this.titleKey,
    required this.icon,
  });

  final String id;
  final String pathSegment;
  final String titleKey;
  final IconData icon;
}

const sectionDefinitions = <SectionDefinition>[
  SectionDefinition(
    id: 'device-build',
    pathSegment: 'device-build',
    titleKey: 'section.deviceBuild',
    icon: Icons.devices,
  ),
  SectionDefinition(
    id: 'display',
    pathSegment: 'display',
    titleKey: 'section.display',
    icon: Icons.display_settings,
  ),
  SectionDefinition(
    id: 'memory-storage',
    pathSegment: 'memory-storage',
    titleKey: 'section.memoryStorage',
    icon: Icons.sd_storage,
  ),
  SectionDefinition(
    id: 'battery',
    pathSegment: 'battery',
    titleKey: 'section.batteryDetailed',
    icon: Icons.battery_full,
  ),
  SectionDefinition(
    id: 'thermal',
    pathSegment: 'thermal',
    titleKey: 'section.thermal',
    icon: Icons.thermostat,
  ),
  SectionDefinition(
    id: 'cameras',
    pathSegment: 'cameras',
    titleKey: 'section.cameras',
    icon: Icons.photo_camera,
  ),
  SectionDefinition(
    id: 'cellular-sim',
    pathSegment: 'cellular-sim',
    titleKey: 'section.cellularSim',
    icon: Icons.sim_card,
  ),
  SectionDefinition(
    id: 'security-drm',
    pathSegment: 'security-drm',
    titleKey: 'section.securityDrm',
    icon: Icons.security,
  ),
  SectionDefinition(
    id: 'codecs',
    pathSegment: 'codecs',
    titleKey: 'section.codecs',
    icon: Icons.video_settings,
  ),
  SectionDefinition(
    id: 'widi-miracast',
    pathSegment: 'widi-miracast',
    titleKey: 'section.widiMiracast',
    icon: Icons.cast,
  ),
  SectionDefinition(
    id: 'sensors',
    pathSegment: 'sensors',
    titleKey: 'section.sensors',
    icon: Icons.sensors,
  ),
];

Widget buildSectionPage(SectionDefinition def) {
  return switch (def.id) {
    'thermal' => const ThermalSectionPage(),
    'cameras' => const CamerasSectionPage(),
    'codecs' => const CodecsSectionPage(),
    'sensors' => const SensorsSectionPage(),
    _ => SectionDetailPage(sectionId: def.id, fallbackTitleKey: def.titleKey),
  };
}
