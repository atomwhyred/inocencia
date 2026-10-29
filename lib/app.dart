import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'core/di/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'core/widgets/splash_gate.dart';
import 'features/power/application/power_mode.dart';
import 'features/auth/application/session.dart';
import 'features/notifications/application/reminder_controller.dart';

class InocenciaApp extends ConsumerStatefulWidget {
  const InocenciaApp({super.key});

  @override
  ConsumerState<InocenciaApp> createState() => _InocenciaAppState();
}

class _InocenciaAppState extends ConsumerState<InocenciaApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _rescheduleReminder() async {
    try {
      await ref.read(reminderControllerProvider.notifier).reschedule();
    } catch (e) {
      debugPrint('No se pudo reprogramar el aviso diario: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al enviar la app a segundo plano se vuelve a pedir el PIN del padre.
    if (state == AppLifecycleState.paused) {
      ref.read(sessionProvider.notifier).lockParent();
    } else if (state == AppLifecycleState.resumed) {
      // El padre pudo conceder el permiso en Ajustes o copiar archivos por USB.
      ref.invalidate(allFilesAccessProvider);
      ref.invalidate(linkedFilesStatusProvider);
      // El padre pudo conceder las alarmas exactas en Ajustes: reprogramar el
      // aviso para que pase de aproximado a exacto.
      unawaited(_rescheduleReminder());
    }
  }

  @override
  Widget build(BuildContext context) {
    final saver = ref.watch(batterySaverProvider);
    return MaterialApp.router(
      title: appName,
      debugShowCheckedModeBanner: false,
      // Modo Bateria / Apagon: negro puro, sin tocar la eleccion de tema del padre.
      theme: saver ? AppTheme.saver() : AppTheme.light(),
      darkTheme: saver ? AppTheme.saver() : AppTheme.dark(),
      themeMode: saver ? ThemeMode.dark : ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      // Bienvenida con Toco y una frase al azar, encima de la app mientras carga.
      builder: (context, child) => SplashGate(child: child ?? const SizedBox.shrink()),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
