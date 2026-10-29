import 'package:equatable/equatable.dart';

/// Lo que se sabe de la bateria del dispositivo.
class BatteryStatus extends Equatable {
  const BatteryStatus({required this.level, required this.charging, this.systemSaver = false});

  /// 0 a 100.
  final int level;
  final bool charging;

  /// El "ahorro de bateria" del propio Android esta activado.
  final bool systemSaver;

  /// Por debajo de esto (y sin cargar) se sugiere el modo ahorro.
  static const lowLevel = 20;

  /// Conviene ahorrar: poca bateria sin cargador, o el ahorro de Android activo.
  bool get shouldSave => (!charging && level < lowLevel) || (!charging && systemSaver);

  @override
  List<Object?> get props => [level, charging, systemSaver];
}

abstract class BatteryInfo {
  /// `null` si no se puede saber (sin bateria, o plataforma sin soporte).
  Future<BatteryStatus?> read();
}
