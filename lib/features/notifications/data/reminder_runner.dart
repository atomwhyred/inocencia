import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/app_database.dart';
import 'notifier.dart';
import 'reminder_scheduler.dart';
import 'reminder_settings_store.dart';
import 'reminder_texts.dart';

const _notificationId = 7001;

/// Muestra el aviso (con el nombre de un nino al azar, si hay perfiles) y
/// guarda el resultado para que el padre lo vea en Zona de padres > Avisos.
/// [force]: aviso de prueba (ignora si esta activado).
Future<String> runReminder(
  ReminderSettingsStore store,
  AppDatabase db, {
  bool force = false,
  Random? random,
}) async {
  String status;
  try {
    final names = await (db.select(db.childProfiles)).map((r) => r.name).get();
    final r = random ?? Random();
    final text = reminderText(
      childName: names.isEmpty ? null : names[r.nextInt(names.length)],
      random: r,
    );
    await ReminderNotifier().show(id: _notificationId, title: text.title, body: text.body);
    status = force ? 'Aviso de prueba enviado' : 'Aviso enviado';
  } catch (e) {
    status = 'Error: $e';
  }
  await store.recordRun(status);
  return status;
}

/// Punto de entrada de la alarma. Corre sin interfaz: abre su propia base de
/// datos, programa el siguiente aviso y notifica.
@pragma('vm:entry-point')
Future<void> reminderAlarmCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final store = ReminderSettingsStore(await SharedPreferences.getInstance());
  await store.reload();
  final settings = store.load();
  if (!settings.enabled) return;
  try {
    // Primero la siguiente: asi la cadena no se rompe si falla el aviso.
    await AlarmReminderScheduler().schedule(settings);
  } catch (_) {}
  final db = AppDatabase();
  try {
    await runReminder(store, db);
  } finally {
    await db.close();
  }
}
