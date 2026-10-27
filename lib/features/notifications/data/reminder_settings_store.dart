import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reminder_settings.dart';

/// Guarda el aviso diario en `shared_preferences`: tambien lo lee la alarma,
/// que corre en un isolate sin interfaz.
class ReminderSettingsStore {
  const ReminderSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _enabledKey = 'reminder_enabled';
  static const _minutesKey = 'reminder_minutes';
  static const _lastRunKey = 'reminder_last_run';

  ReminderSettings load() => ReminderSettings(
        enabled: _prefs.getBool(_enabledKey) ?? false,
        minutesOfDay: _prefs.getInt(_minutesKey) ?? ReminderSettings.defaultMinutes,
      );

  Future<void> save(ReminderSettings s) async {
    await _prefs.setBool(_enabledKey, s.enabled);
    await _prefs.setInt(_minutesKey, s.minutesOfDay);
  }

  /// Resultado de la ultima ejecucion ("Aviso enviado", "Error: ..."), para
  /// que el padre vea si funciona.
  String? get lastRun => _prefs.getString(_lastRunKey);

  Future<void> recordRun(String status) =>
      _prefs.setString(_lastRunKey, status);

  /// La alarma corre en otro isolate con su propia copia en memoria: antes de
  /// leer hay que recargar lo que escribio la app.
  Future<void> reload() => _prefs.reload();
}
