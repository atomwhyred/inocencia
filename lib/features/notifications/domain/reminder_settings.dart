import 'package:equatable/equatable.dart';

/// Un aviso diario que invita al nino a estudiar, con su propio interruptor.
class Reminder extends Equatable {
  const Reminder({required this.id, this.enabled = true, this.minutesOfDay = defaultMinutes});

  /// 08:00.
  static const defaultMinutes = 8 * 60;

  /// Los ids de alarma y de notificacion de Android son `alarmBase + id`. El
  /// aviso 1 conserva el 7001 que ya tenia el aviso unico: asi una alarma
  /// programada antes de actualizar sigue siendo la suya.
  static const alarmBase = 7000;

  /// Estable mientras exista el aviso (no se reutiliza al borrar otro).
  final int id;
  final bool enabled;

  /// Hora del aviso en minutos desde medianoche (hora local).
  final int minutesOfDay;

  int get hour => minutesOfDay ~/ 60;
  int get minute => minutesOfDay % 60;

  int get alarmId => alarmBase + id;

  /// El aviso al que pertenece una alarma o notificacion, o `null` si no es de un aviso.
  static int? idFromAlarm(int alarmId) => alarmId > alarmBase ? alarmId - alarmBase : null;

  Reminder copyWith({bool? enabled, int? minutesOfDay}) => Reminder(
        id: id,
        enabled: enabled ?? this.enabled,
        minutesOfDay: minutesOfDay ?? this.minutesOfDay,
      );

  Map<String, Object> toJson() => {'id': id, 'enabled': enabled, 'minutes': minutesOfDay};

  /// `null` si el dato esta roto (se ignora ese aviso).
  static Reminder? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final enabled = json['enabled'];
    final minutes = json['minutes'];
    if (id is! int || id < 1 || enabled is! bool || minutes is! int) return null;
    if (minutes < 0 || minutes >= 24 * 60) return null;
    return Reminder(id: id, enabled: enabled, minutesOfDay: minutes);
  }

  @override
  List<Object?> get props => [id, enabled, minutesOfDay];
}

/// Los avisos del padre. Mientras no toque nada hay uno activo a las 08:00.
class ReminderSettings extends Equatable {
  const ReminderSettings(this.reminders);

  /// Un aviso activo a las 08:00 (instalacion nueva).
  static const initial = ReminderSettings([Reminder(id: 1)]);

  /// Tope razonable: mas avisos al dia dejarian de ser amables.
  static const maxReminders = 5;

  final List<Reminder> reminders;

  bool get anyEnabled => reminders.any((r) => r.enabled);
  bool get canAdd => reminders.length < maxReminders;

  Reminder? byId(int id) => reminders.where((r) => r.id == id).firstOrNull;

  /// Id para un aviso nuevo: mayor que cualquiera usado, para no heredar la
  /// alarma de uno borrado.
  int nextId(int lastUsed) {
    final highest = reminders.fold<int>(lastUsed, (m, r) => r.id > m ? r.id : m);
    return highest + 1;
  }

  ReminderSettings replace(Reminder changed) =>
      ReminderSettings([for (final r in reminders) r.id == changed.id ? changed : r]);

  ReminderSettings without(int id) =>
      ReminderSettings([for (final r in reminders) if (r.id != id) r]);

  ReminderSettings added(Reminder r) => ReminderSettings([...reminders, r]);

  @override
  List<Object?> get props => [reminders];
}

/// El aviso que debe sonar cuando salta la alarma [alarmId]: `null` si ya no
/// existe o esta desactivado (se borro o apago desde que se programo).
Reminder? reminderToRun(ReminderSettings settings, int alarmId) {
  final id = Reminder.idFromAlarm(alarmId);
  if (id == null) return null;
  final r = settings.byId(id);
  return r != null && r.enabled ? r : null;
}

/// Proxima ejecucion del aviso diario, en hora local y estrictamente posterior
/// a [now].
DateTime nextDailyRun({required int minutesOfDay, required DateTime now}) {
  DateTime at(int year, int month, int day) =>
      DateTime(year, month, day, minutesOfDay ~/ 60, minutesOfDay % 60);
  final today = at(now.year, now.month, now.day);
  return today.isAfter(now) ? today : at(now.year, now.month, now.day + 1);
}
