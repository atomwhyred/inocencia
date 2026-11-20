import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/app.dart';
import 'package:inocencia/core/di/providers.dart';
import 'package:inocencia/core/router/app_router.dart';
import 'package:inocencia/core/security/pin_hasher.dart';
import 'package:inocencia/core/storage/app_database.dart';
import 'package:inocencia/core/widgets/pin_pad.dart';
import 'package:inocencia/features/auth/application/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fastHasher = PinHasher(iterations: 10);

Future<({ProviderContainer container, AppDatabase db})> _boot(
  WidgetTester tester, {
  required Size size,
  bool withGuardian = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  if (withGuardian) {
    await db.into(db.guardians).insert(
          GuardiansCompanion.insert(
            name: 'Ana',
            pinHash: PinHasher.hashSync('1234', iterations: 10),
            pinLength: 4,
          ),
        );
  }
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    appDatabaseProvider.overrideWithValue(db),
    pinHasherProvider.overrideWithValue(_fastHasher),
  ]);
  addTearDown(() async {
    // Desmonta el arbol antes de cerrar la BD para cancelar los streams.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.runAsync(db.close);
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const InocenciaApp()),
  );
  await tester.pumpAndSettle();
  return (container: container, db: db);
}

void main() {
  const phone = Size(400, 800);
  const tablet = Size(1200, 800);

  testWidgets('primer arranque: sin administrador se muestra el setup', (tester) async {
    await _boot(tester, size: phone);
    expect(find.text('¡Bienvenido a inocencIA!'), findsOneWidget);
    expect(find.text('Funciona sin internet'), findsOneWidget);
  });

  testWidgets('el setup exige nombre antes de continuar', (tester) async {
    await _boot(tester, size: phone);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe tu nombre'), findsOneWidget);
  });

  testWidgets('setup completo: nombre, PIN, confirmacion y llega al inicio', (tester) async {
    await _boot(tester, size: phone);
    await tester.enterText(find.byType(TextFormField), 'Ana');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu PIN'), findsOneWidget);

    Future<void> typePin(String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.text(d));
        await tester.pump();
      }
    }

    await typePin('1234');
    await tester.pumpAndSettle();
    expect(find.textContaining('fácil de adivinar'), findsOneWidget, reason: 'PIN débil rechazado');
    expect(find.text('Crea tu PIN'), findsOneWidget);
    await typePin('4829');
    await tester.pumpAndSettle();
    expect(find.text('Repite tu PIN'), findsOneWidget);
    await typePin('4829');
    // El hash se calcula en un isolate: hay que dejar correr tiempo real.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();

    expect(find.text('¡Hola!'), findsOneWidget);
  });

  testWidgets('PINs que no coinciden vuelven a pedir el PIN', (tester) async {
    await _boot(tester, size: phone);
    await tester.enterText(find.byType(TextFormField), 'Ana');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    for (final d in '4829'.split('')) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    for (final d in '4828'.split('')) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Los PIN no coinciden. Prueba de nuevo.'), findsOneWidget);
    expect(find.text('Crea tu PIN'), findsOneWidget);
  });

  testWidgets('con administrador, el inicio invita a crear perfiles', (tester) async {
    await _boot(tester, size: phone, withGuardian: true);
    expect(find.text('¡Hola!'), findsOneWidget);
    expect(find.textContaining('Todavía no hay perfiles'), findsOneWidget);
  });

  testWidgets('el panel de padres no se abre sin PIN', (tester) async {
    final app = await _boot(tester, size: phone, withGuardian: true);
    app.container.read(routerProvider).go('/admin');
    await tester.pumpAndSettle();
    expect(find.text('Introduce tu PIN'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('PIN del padre: incorrecto rechaza, correcto abre el panel', (tester) async {
    await _boot(tester, size: phone, withGuardian: true);
    await tester.tap(find.byTooltip('Zona de padres'));
    await tester.pumpAndSettle();

    Future<void> typePin(String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.text(d));
        await tester.pump();
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pumpAndSettle();
    }

    await typePin('9999');
    expect(find.text('PIN incorrecto'), findsOneWidget);
    await typePin('1234');
    expect(find.text('Zona de padres'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('panel en telefono: barra inferior, sin riel ni dos paneles', (tester) async {
    final app = await _boot(tester, size: phone, withGuardian: true);
    app.container.read(sessionProvider.notifier).unlockParent();
    app.container.read(routerProvider).go('/admin');
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Elige un perfil o crea uno nuevo'), findsNothing);
  });

  testWidgets('panel en tablet horizontal: riel lateral y dos paneles', (tester) async {
    final app = await _boot(tester, size: tablet, withGuardian: true);
    app.container.read(sessionProvider.notifier).unlockParent();
    app.container.read(routerProvider).go('/admin');
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Elige un perfil o crea uno nuevo'), findsOneWidget);
  });

  testWidgets('PinPad entrega el PIN al completarse y se reinicia con resetToken', (tester) async {
    String? got;
    var token = 0;
    late StateSetter setOuter;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          setOuter = setState;
          return PinPad(length: 4, resetToken: token, onCompleted: (p) => got = p);
        }),
      ),
    ));
    for (final d in ['1', '2', '3']) {
      await tester.tap(find.text(d));
    }
    expect(got, isNull);
    await tester.tap(find.text('4'));
    expect(got, '1234');

    got = null;
    setOuter(() => token++);
    await tester.pump();
    for (final d in ['9', '8', '7', '6']) {
      await tester.tap(find.text(d));
    }
    expect(got, '9876');
  });
}
