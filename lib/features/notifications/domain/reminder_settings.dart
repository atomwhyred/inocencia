import 'package:equatable/equatable.dart';

/// Configuracion del aviso diario que invita al nino a estudiar.
class ReminderSettings extends Equatable {
  const ReminderSettings({this.enabled = false, this.minutesOfDay = defaultMinutes});

  /// 08:00.
  static const defaultMinutes = 8 * 60;

  final bool enabled;

  /// Hora del aviso en minutos desde medianoche (hora local).
  final int minutesOfDay;

  int get hour => minutesOfDay ~/ 60;
  int get minute => minutesOfDay % 60;

  ReminderSettings copyWith({bool? enabled, int? minutesOfDay}) => ReminderSettings(
        enabled: enabled ?? this.enabled,
        minutesOfDay: minutesOfDay ?? this.minutesOfDay,
      );

  @override
  List<Object?> get props => [enabled, minutesOfDay];
}

/// Proxima ejecucion del aviso diario, en hora local y estrictamente posterior
/// a [now].
DateTime nextDailyRun({required int minutesOfDay, required DateTime now}) {
  DateTime at(int year, int month, int day) =>
      DateTime(year, month, day, minutesOfDay ~/ 60, minutesOfDay % 60);
  final today = at(now.year, now.month, now.day);
  return today.isAfter(now) ? today : at(now.year, now.month, now.day + 1);
}
