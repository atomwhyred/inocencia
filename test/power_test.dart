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
import 'package:inocencia/features/auth/application/session.dart';
import 'package:inocencia/features/mascot/application/mascot_atlas.dart';
import 'package:inocencia/features/mascot/application/mascot_settings.dart';
import 'package:inocencia/features/power/application/power_mode.dart';
import 'package:inocencia/features/power/domain/battery_info.dart';
import 'package:inocencia/features/profiles/data/child_profile_repository_impl.dart';
import 'package:inocencia/features/profiles/domain/child_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBattery implements BatteryInfo {
  FakeBattery(this.status);
  BatteryStatus? status;

  @override
  Future<BatteryStatus?> read() async => status;
}

void main() {
  group('BatteryStatus.shouldSave', () {
    test('poca batería sin cargador, o ahorro de Android activo sin cargador', () {
      expect(const BatteryStatus(level: 19, charging: false).shouldSave, isTrue);
      expect(const BatteryStatus(level: 20, charging: false).shouldSave, isFalse);
      expect(const BatteryStatus(level: 80, charging: false, systemSaver: true).shouldSave, isTrue);
    });

    test('con el cargador puesto no se sugiere nada', () {
      expect(const BatteryStatus(level: 5, charging: true).shouldSave, isFalse);
      expect(const BatteryStatus(level: 50, charging: true, systemSaver: true).shouldSave, isFalse);
    });
  });

  group('tema de ahorro', () {
    test('es negro puro y de alto contraste, sin salirse de la marca', () {
      final s = AppTheme.saverScheme;
      expect(s.brightness, Brightness.dark);
      expect(s.surface, const Color(0xFF000000));
      expect(AppTheme.saver().scaffoldBackgroundColor, const Color(0xFF000000));
      expect(s.onSurface, const Color(0xFFFFFFFF));
      // El azul y el rojo de la marca siguen en los botones principales.
      expect(s.primary, AppTheme.darkScheme.primary);
    });
  });

  group('BatterySaverController y sugerencia', () {
    late ProviderContainer c;

    Future<ProviderContainer> make(
      BatteryStatus? battery, {
      Map<String, Object> prefs = const {},
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          batteryInfoProvider.overrideWithValue(FakeBattery(battery)),
        ],
      );
      addTearDown(container.dispose);
      container.listen(lowBatterySuggestionProvider, (_, _) {});
      return container;
    }

    test('viene apagado, se recuerda y no cambia el tema elegido por el padre', () async {
      c = await make(null);
      expect(c.read(batterySaverProvider), isFalse);
      await c.read(batterySaverProvider.notifier).toggle();
      expect(c.read(batterySaverProvider), isTrue);
      expect(c.read(sharedPreferencesProvider).getBool('battery_saver'), isTrue);
      expect(c.read(sharedPreferencesProvider).getString('theme_mode'), isNull);

      final again = await make(null, prefs: {'battery_saver': true});
      expect(again.read(batterySaverProvider), isTrue);
    });

    test('las animaciones de Toco se apagan con el modo ahorro', () async {
      c = await make(null);
      expect(c.read(mascotAnimateProvider), isTrue);
      await c.read(batterySaverProvider.notifier).set(true);
      expect(c.read(mascotAnimateProvider), isFalse);
    });

    test('sugiere con poca batería y se calla al descartar o al activar el modo', () async {
      c = await make(const BatteryStatus(level: 15, charging: false));
      await c.read(batteryStatusProvider.future);
      expect(c.read(lowBatterySuggestionProvider), isTrue);

      c.read(suggestionDismissedProvider.notifier).dismiss();
      expect(c.read(lowBatterySuggestionProvider), isFalse);

      final d = await make(const BatteryStatus(level: 15, charging: false));
      await d.read(batteryStatusProvider.future);
      expect(d.read(lowBatterySuggestionProvider), isTrue);
      await d.read(batterySaverProvider.notifier).set(true);
      expect(d.read(lowBatterySuggestionProvider), isFalse);
    });

    test('no sugiere con batería normal, cargando o si no se puede leer', () async {
      for (final s in [
        const BatteryStatus(level: 60, charging: false),
        const BatteryStatus(level: 10, charging: true),
        null,
      ]) {
        final x = await make(s);
        await x.read(batteryStatusProvider.future);
        expect(x.read(lowBatterySuggestionProvider), isFalse, reason: '$s');
      }
    });
  });

  group('en la app', () {
    late int leo;

    Future<ProviderContainer> boot(WidgetTester tester, {BatteryStatus? battery}) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase(NativeDatabase.memory());
      await db
          .into(db.guardians)
          .insert(
            GuardiansCompanion.insert(
              name: 'Ana',
              pinHash: PinHasher.hashSync('1234', iterations: 10),
              pinLength: 4,
            ),
          );
      leo = await ChildProfileRepositoryImpl(
        db,
        const PinHasher(iterations: 10),
      ).create(ChildProfileInput(name: 'Leo', avatar: 'emoji:🦊', birthDate: DateTime(2015, 3, 1)));
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          appDatabaseProvider.overrideWithValue(db),
          batteryInfoProvider.overrideWithValue(FakeBattery(battery)),
          batteryPollProvider.overrideWithValue(null),
          mascotAtlasProvider.overrideWith((ref) async => null),
        ],
      );
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

    Color background(WidgetTester tester) =>
        Theme.of(tester.element(find.byType(Scaffold).first)).scaffoldBackgroundColor;

    testWidgets('el icono de la barra del niño pone el fondo negro y lo quita', (tester) async {
      final c = await boot(tester);
      c.read(sessionProvider.notifier).selectChild(leo);
      c.read(routerProvider).go('/home');
      await tester.pumpAndSettle();
      expect(background(tester), isNot(const Color(0xFF000000)));

      await tester.tap(find.byTooltip('Ahorrar batería'));
      await tester.pumpAndSettle();
      expect(c.read(batterySaverProvider), isTrue);
      expect(background(tester), const Color(0xFF000000));

      await tester.tap(find.byTooltip('Apagar el modo ahorro de batería'));
      await tester.pumpAndSettle();
      expect(c.read(batterySaverProvider), isFalse);
      expect(background(tester), isNot(const Color(0xFF000000)));
    });

    testWidgets('con poca batería el inicio ofrece ahorrar y un toque lo activa', (tester) async {
      final c = await boot(tester, battery: const BatteryStatus(level: 12, charging: false));
      c.read(sessionProvider.notifier).selectChild(leo);
      c.read(routerProvider).go('/home');
      await tester.pumpAndSettle();

      expect(find.text('Queda poca batería. ¿Ahorramos energía?'), findsOneWidget);
      await tester.tap(find.text('Ahorrar'));
      await tester.pumpAndSettle();
      expect(c.read(batterySaverProvider), isTrue);
      expect(find.text('Queda poca batería. ¿Ahorramos energía?'), findsNothing);
      expect(background(tester), const Color(0xFF000000));
    });

    testWidgets('"No, gracias" quita el aviso sin activar el modo', (tester) async {
      final c = await boot(tester, battery: const BatteryStatus(level: 12, charging: false));
      c.read(sessionProvider.notifier).selectChild(leo);
      c.read(routerProvider).go('/home');
      await tester.pumpAndSettle();
      await tester.tap(find.text('No, gracias'));
      await tester.pumpAndSettle();
      expect(find.text('Queda poca batería. ¿Ahorramos energía?'), findsNothing);
      expect(c.read(batterySaverProvider), isFalse);
    });

    testWidgets('el padre lo cambia desde Apariencia y desde el icono de su barra', (tester) async {
      final c = await boot(tester);
      c.read(sessionProvider.notifier).unlockParent();
      c.read(routerProvider).go('/admin');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apariencia'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Modo batería / apagón'));
      await tester.tap(find.text('Modo batería / apagón'));
      await tester.pumpAndSettle();
      expect(c.read(batterySaverProvider), isTrue);
      expect(background(tester), const Color(0xFF000000));

      await tester.tap(find.byTooltip('Apagar el modo ahorro de batería'));
      await tester.pumpAndSettle();
      expect(c.read(batterySaverProvider), isFalse);
    });
  });
}
