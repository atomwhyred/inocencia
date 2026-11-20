import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/di/providers.dart';
import 'core/storage/platform_info.dart';
import 'core/splash_phrases.dart';
import 'features/notifications/application/reminder_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final prefs = await SharedPreferences.getInstance();
  // Los versos de la bienvenida se leen antes de abrir la app (si fallan, hay unos de respaldo).
  final phrases = await SplashPhrases.load(rootBundle);
  // Tiempo desde el encendido al abrir la app + lo que lleva abierta = reloj monótono.
  final bootMs = await const PlatformInfo().elapsedRealtimeMs();
  final sinceStart = Stopwatch()..start();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      splashPhrasesProvider.overrideWithValue(phrases),
      if (bootMs != null)
        uptimeProvider.overrideWithValue(
          () => Duration(milliseconds: bootMs) + sinceStart.elapsed,
        ),
    ],
  );
  // Un fallo con las alarmas nunca debe impedir que la app arranque.
  try {
    await AndroidAlarmManager.initialize();
    // Reprograma el aviso en cada arranque (cubre cambios de hora o reinicios).
    await container.read(reminderControllerProvider.notifier).reschedule();
  } catch (e, st) {
    debugPrint('No se pudo programar el aviso diario: $e\n$st');
  }
  runApp(UncontrolledProviderScope(container: container, child: const InocenciaApp()));
}
