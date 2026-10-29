import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';

import '../domain/battery_info.dart';

/// Bateria del telefono con `battery_plus` (sin permisos).
class BatteryPlusInfo implements BatteryInfo {
  BatteryPlusInfo([Battery? battery]) : _battery = battery ?? Battery();

  final Battery _battery;

  @override
  Future<BatteryStatus?> read() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      var saver = false;
      try {
        saver = await _battery.isInBatterySaveMode;
      } catch (_) {}
      if (kDebugMode) debugPrint('[bateria] nivel $level, estado $state, ahorro del sistema $saver');
      return BatteryStatus(
        level: level,
        charging: state == BatteryState.charging || state == BatteryState.full,
        systemSaver: saver,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[bateria] no se pudo leer: $e');
      return null;
    }
  }
}
