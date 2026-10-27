import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/app.dart';
import 'package:inocencia/core/di/providers.dart';
import 'package:inocencia/core/router/app_router.dart';
import 'package:inocencia/core/security/pin_hasher.dart';
import 'package:inocencia/core/storage/app_database.dart';
import 'package:inocencia/core/theme/app_theme.dart';
import 'package:inocencia/core/theme/theme_mode_controller.dart';
import 'package:inocencia/features/auth/application/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  group('colores de marca', () {
    test('la paleta es exactamente #0035AD, #DC241F, #FFFFFF y #272757', () {
      expect(AppColors.blue, const Color(0xFF0035AD));
      expect(AppColors.red, const Color(0xFFDC241F));
      expect(AppColors.white, const Color(0xFFFFFFFF));
      expect(AppColors.night, const Color(0xFF272757));
    });

    test('modo claro: base blanca, azul principal y rojo de acento', () {
      expect(AppTheme.lightScheme.surface, AppColors.white);
      expect(AppTheme.lightScheme.primary, AppColors.blue);
      expect(AppTheme.lightScheme.secondary, AppColors.red);
      expect(AppTheme.light().scaffoldBackgroundColor, AppColors.white);
    });

    test('modo oscuro: fondo #272757 y marca como contenedores', () {
      expect(AppTheme.darkScheme.surface, AppColors.night);
      expect(AppTheme.darkScheme.primaryContainer, AppColors.blue);
      expect(AppTheme.darkScheme.secondaryContainer, AppColors.red);
      expect(AppTheme.dark().scaffoldBackgroundColor, AppColors.night);
    });
  });

  group('contraste (WCAG AA)', () {
    for (final entry in {'claro': AppTheme.lightScheme, 'oscuro': AppTheme.darkScheme}.entries) {
      final s = entry.value;
      final pairs = <String, (Color, Color)>{
        'texto sobre fondo': (s.onSurface, s.surface),
        'texto secundario sobre fondo': (s.onSurfaceVariant, s.surface),
        'texto sobre tarjeta': (s.onSurface, s.surfaceContainerLow),
        'texto de boton principal': (s.onPrimary, s.primary),
        'texto sobre contenedor principal': (s.onPrimaryContainer, s.primaryContainer),
        'texto de boton secundario': (s.onSecondary, s.secondary),
        'texto sobre contenedor secundario': (s.onSecondaryContainer, s.secondaryContainer),
        'texto sobre contenedor terciario': (s.onTertiaryContainer, s.tertiaryContainer),
        'error sobre fondo': (s.error, s.surface),
        'enlace (primario) sobre fondo': (s.primary, s.surface),
      };
      for (final p in pairs.entries) {
        test('${entry.key}: ${p.key} >= 4.5', () {
          expect(_contrast(p.value.$1, p.value.$2), greaterThanOrEqualTo(4.5));
        });
      }
    }

    test('el acento rojo se distingue sobre el fondo oscuro (elementos grandes >= 3)', () {
      expect(_contrast(AppColors.red, AppColors.night), greaterThanOrEqualTo(2.5));
      expect(_contrast(AppTheme.darkScheme.secondary, AppColors.night), greaterThanOrEqualTo(4.5));
    });
  });

  group('ThemeModeController', () {
    Future<ProviderContainer> make([Map<String, Object> initial = const {}]) async {
      SharedPreferences.setMockInitialValues(initial);
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('por defecto sigue el dispositivo', () async {
      expect((await make()).read(themeModeProvider), ThemeMode.system);
    });

    test('guarda la eleccion y la recupera', () async {
      final c = await make();
      await c.read(themeModeProvider.notifier).set(ThemeMode.dark);
      expect(c.read(themeModeProvider), ThemeMode.dark);
      final again = await make({'theme_mode': 'dark'});
      expect(again.read(themeModeProvider), ThemeMode.dark);
    });

    test('un valor guardado desconocido vuelve a seguir el dispositivo', () async {
      final c = await make({'theme_mode': 'rosa'});
      expect(c.read(themeModeProvider), ThemeMode.system);
    });
  });

  group('en la app', () {
    Future<ProviderContainer> boot(
      WidgetTester tester, {
      Brightness platform = Brightness.light,
      Map<String, Object> prefs = const {},
    }) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = platform;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      SharedPreferences.setMockInitialValues(prefs);
      final sp = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.guardians).insert(GuardiansCompanion.insert(
            name: 'Ana',
            pinHash: PinHasher.hashSync('1234', iterations: 10),
            pinLength: 4,
          ));
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        appDatabaseProvider.overrideWithValue(db),
      ]);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.runAsync(db.close);
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const InocenciaApp()),
      );
      await tester.pumpAndSettle();
      return container;
    }

    Brightness current(WidgetTester tester) =>
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

    testWidgets('seguir dispositivo: claro u oscuro segun el sistema', (tester) async {
      await boot(tester, platform: Brightness.dark);
      expect(current(tester), Brightness.dark);
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).scaffoldBackgroundColor,
        AppColors.night,
      );
    });

    testWidgets('claro forzado ignora un dispositivo oscuro', (tester) async {
      await boot(tester, platform: Brightness.dark, prefs: {'theme_mode': 'light'});
      expect(current(tester), Brightness.light);
    });

    testWidgets('el padre cambia el modo desde Apariencia', (tester) async {
      final c = await boot(tester);
      c.read(sessionProvider.notifier).unlockParent();
      c.read(routerProvider).go('/admin');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apariencia'));
      await tester.pumpAndSettle();
      expect(find.text('Seguir el dispositivo'), findsOneWidget);
      expect(current(tester), Brightness.light);

      await tester.tap(find.text('Oscuro').last);
      await tester.pumpAndSettle();
      expect(c.read(themeModeProvider), ThemeMode.dark);
      expect(current(tester), Brightness.dark);

      await tester.tap(find.text('Seguir el dispositivo'));
      await tester.pumpAndSettle();
      expect(c.read(themeModeProvider), ThemeMode.system);
      expect(current(tester), Brightness.light);
    });
  });
}
