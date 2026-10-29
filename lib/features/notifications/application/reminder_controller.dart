import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/notifier.dart';
import '../data/reminder_scheduler.dart';
import '../data/reminder_settings_store.dart';
import '../domain/reminder_settings.dart';

final reminderSettingsStoreProvider = Provider<ReminderSettingsStore>(
  (ref) => ReminderSettingsStore(ref.watch(sharedPreferencesProvider)),
);

/// Permisos y notificaciones de Android. Se sobrescribe en las pruebas: el
/// plugin solo existe en Android.
final reminderNotifierProvider = Provider<ReminderNotifier>((ref) => ReminderNotifier());

/// Se sobrescribe en las pruebas (la alarma solo existe en Android).
final reminderSchedulerProvider =
    Provider<ReminderScheduler>((ref) => AlarmReminderScheduler());

/// Los avisos del padre. Cada cambio se guarda y reprograma la alarma de ese aviso.
class ReminderController extends Notifier<ReminderSettings> {
  @override
  ReminderSettings build() => ref.watch(reminderSettingsStoreProvider).load();

  ReminderScheduler get _scheduler => ref.read(reminderSchedulerProvider);
  ReminderSettingsStore get _store => ref.read(reminderSettingsStoreProvider);

  Future<void> setEnabled(int id, bool enabled) => _change(id, (r) => r.copyWith(enabled: enabled));

  Future<void> setMinutes(int id, int minutesOfDay) =>
      _change(id, (r) => r.copyWith(minutesOfDay: minutesOfDay));

  Future<void> _change(int id, Reminder Function(Reminder) edit) async {
    final current = state.byId(id);
    if (current == null) return;
    final changed = edit(current);
    final next = state.replace(changed);
    await _store.save(next);
    state = next;
    await _scheduler.schedule(changed);
  }

  /// Anade un aviso activo a [minutesOfDay]. `null` si ya hay el maximo.
  Future<Reminder?> add(int minutesOfDay) async {
    if (!state.canAdd) return null;
    final reminder = Reminder(id: state.nextId(_store.lastId), minutesOfDay: minutesOfDay);
    final next = state.added(reminder);
    await _store.save(next);
    state = next;
    await _scheduler.schedule(reminder);
    return reminder;
  }

  /// Borra el aviso y cancela su alarma.
  Future<void> remove(int id) async {
    if (state.byId(id) == null) return;
    final next = state.without(id);
    await _store.save(next);
    state = next;
    await _scheduler.cancel(id);
  }

  /// Reprograma las alarmas con los avisos guardados (se llama al arrancar):
  /// programa los activos y cancela los apagados.
  Future<void> reschedule() async {
    for (final r in state.reminders) {
      await _scheduler.schedule(r);
    }
  }
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
