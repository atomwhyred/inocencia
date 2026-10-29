import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reminder_settings.dart';

/// Guarda los avisos en `shared_preferences`: tambien los lee la alarma, que
/// corre en un isolate sin interfaz.
class ReminderSettingsStore {
  const ReminderSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _remindersKey = 'reminders_v1';
  static const _lastIdKey = 'reminder_last_id';
  static const _lastRunKey = 'reminder_last_run';

  // Claves del aviso unico de versiones anteriores.
  static const _legacyEnabledKey = 'reminder_enabled';
  static const _legacyMinutesKey = 'reminder_minutes';

  /// Los avisos guardados. Si nunca se guardo una lista:
  /// - con los ajustes del aviso unico anterior, se conservan como el aviso 1;
  /// - en una instalacion nueva, un aviso activo a las 08:00.
  ReminderSettings load() {
    final raw = _prefs.getString(_remindersKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<Object?>;
        final parsed = [for (final e in list) Reminder.fromJson(e)].whereType<Reminder>().toList();
        return ReminderSettings(parsed);
      } catch (_) {
        return ReminderSettings.initial;
      }
    }
    final hadLegacy = _prefs.containsKey(_legacyEnabledKey) || _prefs.containsKey(_legacyMinutesKey);
    if (!hadLegacy) return ReminderSettings.initial;
    return ReminderSettings([
      Reminder(
        id: 1,
        enabled: _prefs.getBool(_legacyEnabledKey) ?? false,
        minutesOfDay: _prefs.getInt(_legacyMinutesKey) ?? Reminder.defaultMinutes,
      ),
    ]);
  }

  /// Mayor id usado alguna vez (aunque ese aviso se borrara).
  int get lastId => _prefs.getInt(_lastIdKey) ?? 1;

  Future<void> save(ReminderSettings s) async {
    await _prefs.setString(_remindersKey, jsonEncode([for (final r in s.reminders) r.toJson()]));
    final highest = s.reminders.fold<int>(lastId, (m, r) => r.id > m ? r.id : m);
    await _prefs.setInt(_lastIdKey, highest);
  }

  /// Resultado de la ultima ejecucion ("Aviso enviado", "Error: ..."), para
  /// que el padre vea si funciona.
  String? get lastRun => _prefs.getString(_lastRunKey);

  Future<void> recordRun(String status) => _prefs.setString(_lastRunKey, status);

  /// La alarma corre en otro isolate con su propia copia en memoria: antes de
  /// leer hay que recargar lo que escribio la app.
  Future<void> reload() => _prefs.reload();
}
