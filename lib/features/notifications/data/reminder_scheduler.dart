import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import '../domain/reminder_settings.dart';
import 'notifier.dart';
import 'reminder_runner.dart';

/// Programa el proximo aviso diario.
abstract class ReminderScheduler {
  Future<void> schedule(ReminderSettings settings, {DateTime? now});
  Future<void> cancel();
}

/// Alarma de Android (AlarmManager) en vez de WorkManager: WorkManager es
/// inexacto y en reposo (Doze) puede retrasar un aviso muchos minutos. Cada
/// ejecucion programa la siguiente (ver [reminderAlarmCallback]);
/// `rescheduleOnReboot` la recupera tras reiniciar el telefono.
class AlarmReminderScheduler implements ReminderScheduler {
  static const alarmId = 7001;

  @override
  Future<void> schedule(ReminderSettings settings, {DateTime? now}) async {
    if (!settings.enabled) return cancel();
    final next = nextDailyRun(
      minutesOfDay: settings.minutesOfDay,
      now: now ?? DateTime.now(),
    );
    // Sin permiso de alarmas exactas Android sigue avisando, con algo de margen.
    final exact = await ReminderNotifier().canScheduleExact();
    await AndroidAlarmManager.oneShotAt(
      next,
      alarmId,
      reminderAlarmCallback,
      exact: exact,
      allowWhileIdle: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  @override
  Future<void> cancel() async {
    await AndroidAlarmManager.cancel(alarmId);
  }
}
