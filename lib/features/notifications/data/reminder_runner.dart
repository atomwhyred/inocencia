import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/app_database.dart';
import '../domain/reminder_settings.dart';
import 'notifier.dart';
import 'reminder_scheduler.dart';
import 'reminder_settings_store.dart';
import 'reminder_texts.dart';

/// Id de la notificacion del aviso de prueba (distinto de los de los avisos reales).
const testNotificationId = 7000;

/// Muestra el aviso (con el nombre de un nino al azar, si hay perfiles) y
/// guarda el resultado para que el padre lo vea en Zona de padres > Avisos.
/// [force]: aviso de prueba (ignora si esta activado). [notificationId] es el
/// del aviso que suena (`Reminder.alarmId`); la prueba usa uno propio.
Future<String> runReminder(
  ReminderSettingsStore store,
  AppDatabase db, {
  bool force = false,
  int notificationId = testNotificationId,
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
    await ReminderNotifier().show(id: notificationId, title: text.title, body: text.body);
    status = force ? 'Aviso de prueba enviado' : 'Aviso enviado';
  } catch (e) {
    status = 'Error: $e';
  }
  await store.recordRun(status);
  return status;
}

/// Punto de entrada de la alarma [id] (el `alarmId` de un aviso). Corre sin
/// interfaz: carga solo SU aviso, programa el siguiente y notifica. Si el aviso se
/// borro o apago desde que se programo la alarma, no hace nada y la cadena acaba.
@pragma('vm:entry-point')
Future<void> reminderAlarmCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final store = ReminderSettingsStore(await SharedPreferences.getInstance());
  await store.reload();
  final reminder = reminderToRun(store.load(), id);
  if (reminder == null) return;
  try {
    // Primero la siguiente: asi la cadena no se rompe si falla el aviso.
    await AlarmReminderScheduler().schedule(reminder);
  } catch (_) {}
  final db = AppDatabase();
  try {
    await runReminder(store, db, notificationId: reminder.alarmId);
  } finally {
    await db.close();
  }
}
