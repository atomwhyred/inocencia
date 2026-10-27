import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/reminder_scheduler.dart';
import '../data/reminder_settings_store.dart';
import '../domain/reminder_settings.dart';

final reminderSettingsStoreProvider = Provider<ReminderSettingsStore>(
  (ref) => ReminderSettingsStore(ref.watch(sharedPreferencesProvider)),
);

/// Se sobrescribe en las pruebas (la alarma solo existe en Android).
final reminderSchedulerProvider =
    Provider<ReminderScheduler>((ref) => AlarmReminderScheduler());

/// Ajustes del aviso diario. Cada cambio se guarda y reprograma la alarma.
class ReminderController extends Notifier<ReminderSettings> {
  @override
  ReminderSettings build() => ref.watch(reminderSettingsStoreProvider).load();

  Future<void> setEnabled(bool enabled) => _apply(state.copyWith(enabled: enabled));

  Future<void> setMinutes(int minutesOfDay) =>
      _apply(state.copyWith(minutesOfDay: minutesOfDay));

  Future<void> _apply(ReminderSettings next) async {
    await ref.read(reminderSettingsStoreProvider).save(next);
    state = next;
    await ref.read(reminderSchedulerProvider).schedule(next);
  }

  /// Reprograma la alarma con los ajustes guardados (se llama al arrancar).
  Future<void> reschedule() =>
      ref.read(reminderSchedulerProvider).schedule(state);
}

final reminderControllerProvider =
    NotifierProvider<ReminderController, ReminderSettings>(ReminderController.new);

/// Resultado de la ultima ejecucion del aviso.
class ReminderLastRun extends Notifier<String?> {
  @override
  String? build() => ref.watch(reminderSettingsStoreProvider).lastRun;

  void set(String status) => state = status;
}

final reminderLastRunProvider =
    NotifierProvider<ReminderLastRun, String?>(ReminderLastRun.new);
