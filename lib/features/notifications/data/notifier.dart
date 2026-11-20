import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// El aviso lleva el nombre del niño: con `private`, la pantalla de bloqueo solo dice
/// que hay un aviso de inocencIA; el texto completo se ve con el teléfono desbloqueado.
const _channel = AndroidNotificationDetails(
  'estudio_diario',
  'Aviso diario de estudio',
  channelDescription: 'Invita al niño a estudiar con su tutor',
  importance: Importance.defaultImportance,
  visibility: NotificationVisibility.private,
);

/// Muestra la notificacion local. Se usa tanto desde la app como desde el
/// isolate de la alarma, asi que inicializa el plugin en cada llamada.
/// Mismo patron que CAJAFACTUR: el plugin solo muestra, la alarma programa.
class ReminderNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> _init() => _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

  Future<void> show({required int id, required String title, required String body}) async {
    await _init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: _channel),
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Android 12+ exige que el usuario permita las alarmas exactas.
  Future<bool> canScheduleExact() async =>
      await _android?.canScheduleExactNotifications() ?? true;

  /// Abre los ajustes de Android para conceder las alarmas exactas.
  Future<void> requestExact() async => _android?.requestExactAlarmsPermission();

  /// Si Android deja a la app mostrar notificaciones (en Android 13+ hay que
  /// concederlo). `true` si no se puede saber.
  Future<bool> notificationsAllowed() async => await _android?.areNotificationsEnabled() ?? true;

  /// Android 13+ exige pedir permiso. Devuelve si quedo concedido.
  Future<bool> requestPermission() async {
    await _init();
    return await _android?.requestNotificationsPermission() ?? true;
  }
}
