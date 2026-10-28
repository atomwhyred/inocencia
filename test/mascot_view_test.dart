import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/theme/app_theme.dart';
import 'package:inocencia/features/mascot/application/mascot_atlas.dart';
import 'package:inocencia/features/mascot/application/mascot_settings.dart';
import 'package:inocencia/features/mascot/domain/mascot_mood.dart';
import 'package:inocencia/features/mascot/presentation/mascot_painter.dart';
import 'package:inocencia/features/mascot/presentation/mascot_view.dart';

final allMoods = [
  for (final a in MascotActivity.values)
    for (final e in MascotEmotion.values) MascotMood(a, e),
];

/// Pantalla de prueba con Toco grande y pequeno, como iria en el chat.
Widget host(
  List<MascotMood> moods, {
  bool animate = false,
  bool fallback = true,
  bool dark = false,
  bool disableAnimations = false,
  bool tickers = true,
}) {
  return ProviderScope(
    overrides: [
      mascotAnimateProvider.overrideWithValue(animate),
      if (fallback) mascotAtlasProvider.overrideWith((ref) async => null),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
        child: TickerMode(enabled: tickers, child: child!),
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Wrap(
            children: [
              for (final m in moods) ...[
                MascotView(mood: m, height: 220),
                MascotView(mood: m, height: 64, size: MascotSize.small),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

MascotPainter painterOf(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.descendant(of: find.byType(MascotView), matching: find.byType(CustomPaint)))
    .map((c) => c.painter)
    .whereType<MascotPainter>()
    .first;

void main() {
  for (final dark in [false, true]) {
    testWidgets('pinta los 18 estados con el respaldo (${dark ? 'oscuro' : 'claro'})', (tester) async {
      await tester.pumpWidget(host(allMoods, dark: dark));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MascotView), findsNWidgets(allMoods.length * 2));
      expect(painterOf(tester).atlas, isNull);
    });
  }

  for (final (name, size, inset) in [
    ('telefono', const Size(420, 900), 0.0),
    ('tablet', const Size(1000, 700), 0.0),
    ('teclado abierto', const Size(420, 900), 320.0),
  ]) {
    testWidgets('sin desbordes en $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      addTearDown(tester.view.reset);
      for (final dark in [false, true]) {
        await tester.pumpWidget(host(allMoods.take(6).toList(), dark: dark));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final big = tester.getSize(find.byType(MascotView).first);
      expect(big.height, 220);
      expect(big.width, closeTo(220 * MascotPainter.aspectFor(MascotSize.large), 0.01));
      final small = tester.getSize(find.byType(MascotView).at(1));
      expect(small.height, 64);
      expect(small.width / small.height, inInclusiveRange(0.75, 1.0)); // cuasi cuadrado
    });
  }

  testWidgets('pinta todos los estados con el atlas real', (tester) async {
    await tester.pumpWidget(host(allMoods, fallback: false));
    // La carga hace E/S real: varias vueltas cortas fuera del reloj falso.
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump(const Duration(milliseconds: 15));
      if (painterOf(tester).atlas != null) break;
    }
    expect(painterOf(tester).atlas, isA<MascotAtlas>());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final dark in [false, true]) {
      await tester.pumpWidget(host(allMoods, fallback: false, dark: dark));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sin animacion: un fotograma fijo y sin Ticker', (tester) async {
    await tester.pumpWidget(host(allMoods.take(3).toList()));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    final t0 = painterOf(tester).clock.value;
    await tester.pump(const Duration(seconds: 2));
    expect(painterOf(tester).clock.value, t0);
  });

  testWidgets('respeta "quitar animaciones" de Android', (tester) async {
    await tester.pumpWidget(host(allMoods.take(3).toList(), animate: true, disableAnimations: true));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('con animacion avanza el tiempo y repinta a ~30 fps', (tester) async {
    await tester.pumpWidget(host(const [MascotMood(MascotActivity.talking)], animate: true));
    final t0 = painterOf(tester).clock.value;
    var changes = 0;
    final clock = painterOf(tester).clock;
    void count() => changes++;
    clock.addListener(count);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    clock.removeListener(count);
    final t1 = painterOf(tester).clock.value;
    expect(t1, greaterThan(t0 + 0.8));
    // 60 fotogramas de 16 ms: unos 30 repintados, no 60.
    expect(changes, inInclusiveRange(20, 34));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    // Al cambiar de mood, la pintura sabe de donde viene.
    await tester.pumpWidget(host(const [MascotMood(MascotActivity.idle, MascotEmotion.happy)], animate: true));
    await tester.pump(const Duration(milliseconds: 100));
    final p = painterOf(tester);
    expect(p.previousMood, const MascotMood(MascotActivity.talking));
    expect(p.moodSince, closeTo(t1, 0.1));
    expect(tester.takeException(), isNull);

    // Dispose limpio: no queda ningun Ticker.
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con TickerMode apagado no avanza', (tester) async {
    await tester.pumpWidget(host(const [MascotMood(MascotActivity.idle)], animate: true, tickers: false));
    final t0 = painterOf(tester).clock.value;
    await tester.pump(const Duration(seconds: 1));
    expect(painterOf(tester).clock.value, t0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('etiqueta para lectores de pantalla y nada que se pueda tocar', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(const [MascotMood(MascotActivity.thinking)]));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Toco, tu tutor, está pensando'), findsWidgets);
    expect(
      MascotView.semanticsLabel(const MascotMood(MascotActivity.idle, MascotEmotion.happy)),
      'Toco, tu tutor, está listo y está contento',
    );
    for (final m in allMoods) {
      expect(MascotView.semanticsLabel(m), startsWith('Toco, tu tutor, '));
    }
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byIcon(Icons.send_rounded), findsNothing);
    expect(find.byIcon(Icons.touch_app_rounded), findsNothing);
    semantics.dispose();
  });
}
