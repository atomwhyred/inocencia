import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import '../domain/reminder_settings.dart';
import 'notifier.dart';
import 'reminder_runner.dart';

/// Programa el proximo aviso diario de cada aviso.
abstract class ReminderScheduler {
  /// Programa [reminder] (o cancela su alarma si esta desactivado).
  Future<void> schedule(Reminder reminder, {DateTime? now});

  /// Cancela la alarma del aviso [reminderId].
  Future<void> cancel(int reminderId);
}

/// Alarma de Android (AlarmManager) en vez de WorkManager: WorkManager es
/// inexacto y en reposo (Doze) puede retrasar un aviso muchos minutos. Cada
/// ejecucion programa la siguiente (ver [reminderAlarmCallback]);
/// `rescheduleOnReboot` la recupera tras reiniciar el telefono. Cada aviso tiene
/// su propia alarma (`Reminder.alarmId`).
class AlarmReminderScheduler implements ReminderScheduler {
  @override
  Future<void> schedule(Reminder reminder, {DateTime? now}) async {
    if (!reminder.enabled) return cancel(reminder.id);
    final next = nextDailyRun(
      minutesOfDay: reminder.minutesOfDay,
      now: now ?? DateTime.now(),
    );
    // Sin permiso de alarmas exactas Android sigue avisando, con algo de margen.
    final exact = await ReminderNotifier().canScheduleExact();
    await AndroidAlarmManager.oneShotAt(
      next,
      reminder.alarmId,
      reminderAlarmCallback,
      exact: exact,
      allowWhileIdle: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  @override
  Future<void> cancel(int reminderId) async {
    await AndroidAlarmManager.cancel(Reminder.alarmBase + reminderId);
  }
}
