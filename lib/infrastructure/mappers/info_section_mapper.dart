import 'dart:convert';

import '../../domain/entities/info/info_availability.dart';
import '../../domain/entities/info/info_item_entity.dart';
import '../../domain/entities/info/info_section_entity.dart';

class InfoSectionMapper {
  InfoSectionEntity deviceAndBuild({
    required Map<String, dynamic> device,
    required Map<String, dynamic> build,
  }) {
    return InfoSectionEntity(
      id: 'device-build',
      titleKey: 'section.deviceBuild',
      items: [
        _item('device.manufacturer', device['manufacturer']),
        _item('device.model', device['model']),
        _item('device.brand', device['brand']),
        _item('device.device', device['device']),
        _item('device.product', device['product']),
        _item('device.hardware', device['hardware']),
        _item('device.board', device['board']),
        _item('device.supportedAbis', device['supportedAbis']),
        _item('build.sdkInt', build['sdkInt']),
        _item('build.release', build['release']),
        _item('build.incremental', build['incremental']),
        _item('build.codename', build['codename']),
        _item('build.securityPatch', build['securityPatch']),
        _item('build.fingerprint', build['fingerprint']),
        _item('build.id', build['id']),
        _item('build.tags', build['tags']),
        _item('build.type', build['type']),
        _item('build.time', build['time']),
      ],
    );
  }

  InfoSectionEntity display(Map<String, dynamic> data) {
    return InfoSectionEntity(
      id: 'display',
      titleKey: 'section.display',
      items: [
        _item('display.widthPx', data['widthPx']),
        _item('display.heightPx', data['heightPx']),
        _item('display.density', data['density']),
        _item('display.densityDpi', data['densityDpi']),
        _item('display.scaledDensity', data['scaledDensity']),
        _item('display.xdpi', data['xdpi']),
        _item('display.ydpi', data['ydpi']),
        _item('display.refreshRatesHz', data['refreshRatesHz']),
      ],
    );
  }

  InfoSectionEntity memoryStorage(Map<String, dynamic> data) {
    final ram = _coerceMap(data['ram']);
    final heap = _coerceMap(data['heap']);

    return InfoSectionEntity(
      id: 'memory-storage',
      titleKey: 'section.memoryStorage',
      items: [
        _item('memory.ramTotalBytes', ram['totalBytes']),
        _item('memory.ramAvailBytes', ram['availBytes']),
        _item('memory.ramLowMemory', ram['lowMemory']),
        _item('memory.heapMaxBytes', heap['maxBytes']),
        _item('memory.heapTotalBytes', heap['totalBytes']),
        _item('memory.heapFreeBytes', heap['freeBytes']),
        _item('storage.volumes', data['storage']),
      ],
    );
  }

  InfoSectionEntity batteryDetailed(Map<String, dynamic> data) {
    return InfoSectionEntity(
      id: 'battery',
      titleKey: 'section.batteryDetailed',
      items: [
        _item('battery.percent', data['percent']),
        _item('battery.status', data['status']),
        _item('battery.health', data['health']),
        _item('battery.plugged', data['plugged']),
        _item('battery.voltageMv', data['voltageMv']),
        _item('battery.temperatureC', data['temperatureC']),
        _item('battery.chargeCounterUah', data['chargeCounterUah']),
        _item('battery.currentNowUa', data['currentNowUa']),
        _item('battery.currentAverageUa', data['currentAverageUa']),
        _item('battery.energyCounterNwh', data['energyCounterNwh']),
      ],
    );
  }

  InfoSectionEntity cameras(Map<String, dynamic> data) {
    return InfoSectionEntity(
      id: 'cameras',
      titleKey: 'section.cameras',
      items: [_item('cameras.cameras', data['cameras'])],
    );
  }

  InfoSectionEntity cellularSim(Map<String, dynamic> data) {
    final telephony = _coerceMap(data['telephony']);
    return InfoSectionEntity(
      id: 'cellular-sim',
      titleKey: 'section.cellularSim',
      items: [
        _item('cellular.networkOperatorName', telephony['networkOperatorName']),
        _item('cellular.simOperatorName', telephony['simOperatorName']),
        _item('cellular.dataNetworkType', telephony['dataNetworkType']),
        _item('cellular.isNetworkRoaming', telephony['isNetworkRoaming']),
        _item('cellular.phoneCount', telephony['phoneCount']),
        _item('cellular.mcc', telephony['mcc']),
        _item('cellular.mnc', telephony['mnc']),
        _item('cellular.signalLevel', data['signalLevel']),
      ],
    );
  }

  InfoSectionEntity securityDrm(Map<String, dynamic> data) {
    return InfoSectionEntity(
      id: 'security-drm',
      titleKey: 'section.securityDrm',
      items: [
        _item('security.securityPatch', data['securityPatch']),
        _item('security.isDeviceSecure', data['isDeviceSecure']),
        _item('security.isStrongBoxAvailable', data['isStrongBoxAvailable']),
        _item('security.widevine', data['widevine']),
        _item('security.telephony', data['telephony']),
        _item('security.currentThermalStatus', data['currentThermalStatus']),
      ],
    );
  }

  InfoSectionEntity codecs(Map<String, dynamic> data) {
    return InfoSectionEntity(
      id: 'codecs',
      titleKey: 'section.codecs',
      items: [_item('codecs.codecs', data['codecs'])],
    );
  }

  InfoSectionEntity widiMiracast(Map<String, dynamic> data) {
    return InfoSectionEntity(
      id: 'widi-miracast',
      titleKey: 'section.widiMiracast',
      items: [
        _item('cast.wifiDirect', data['wifiDirect']),
        _item('cast.wifiDisplayFeature', data['wifiDisplayFeature']),
        _item('cast.castSettingsAvailable', data['castSettingsAvailable']),
      ],
    );
  }

  InfoSectionEntity thermal(Map<String, dynamic> data) {
    return InfoSectionEntity(
      id: 'thermal',
      titleKey: 'section.thermal',
      items: [
        _item('thermal.timestampMs', data['timestampMs']),
        _item('thermal.thermalStatus', data['thermalStatus']),
        _item('thermal.temperatures', data['temperatures']),
      ],
    );
  }

  InfoSectionEntity unavailable({
    required String id,
    required String titleKey,
    InfoAvailability availability = InfoAvailability.notSupported,
  }) {
    return InfoSectionEntity(
      id: id,
      titleKey: titleKey,
      items: const [],
      availability: availability,
    );
  }

  InfoItemEntity _item(String labelKey, Object? value) {
    if (value == null) return InfoItemEntity.unavailable(labelKey: labelKey);
    final text = _stringify(value);
    if (text == null || text.isEmpty) {
      return InfoItemEntity.unavailable(labelKey: labelKey);
    }
    return InfoItemEntity.text(labelKey: labelKey, value: text);
  }

  String? _stringify(Object value) {
    return switch (value) {
      String v => v.trim().isEmpty ? null : v,
      bool v => v.toString(),
      int v => v.toString(),
      num v => v.toString(),
      List v => jsonEncode(v),
      Map v => jsonEncode(v),
      _ => value.toString(),
    };
  }

  Map<String, dynamic> _coerceMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return const {};
  }
}
