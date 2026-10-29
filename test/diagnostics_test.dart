import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/features/external_data/presentation/files_section.dart';
import 'package:inocencia/features/tutor/application/tutor_diagnostics_provider.dart';
import 'package:inocencia/features/tutor/domain/tutor_diagnostics.dart';

const _loaded = TutorDiagnostics(
  model: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
  modelGb: 1.12,
  threads: 4,
  cores: 8,
  coreFreqsKhz: [2700000, 3500000, 4210000],
  variants: ['libggml-cpu-android_armv8.0_1.so'],
  cpuFeatures: 'CPU : NEON = 1 | DOTPROD = 1',
);

void main() {
  group('TutorDiagnostics', () {
    test('sin modelo cargado esta vacio y el informe lo dice', () {
      const d = TutorDiagnostics();
      expect(d.isEmpty, isTrue);
      expect(d.toReport(), contains('aun no hay ninguna'));
    });

    test('el informe incluye modelo, hilos, CPU y la ultima respuesta, sin datos personales', () {
      final d = _loaded.withAnswer(
        firstPieceSeconds: 12,
        pieces: 80,
        totalSeconds: 20,
        piecesPerSecond: 8.5,
      );
      final r = d.toReport();
      expect(r, contains('qwen2.5-1.5b-instruct-q4_k_m.gguf (1.12 GB)'));
      expect(r, contains('Hilos: 4 de 8'));
      expect(r, contains('2700, 3500, 4210'));
      expect(r, contains('DOTPROD = 1'));
      expect(r, contains('primera pieza a los 12 s, 80 piezas en 20 s (8.5 piezas/s)'));
    });

    test('el notificador guarda la carga y solo anota respuestas si hay modelo', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(tutorDiagnosticsProvider.notifier);
      n.answered(firstPieceSeconds: 1, pieces: 2, totalSeconds: 3, piecesPerSecond: 1);
      expect(c.read(tutorDiagnosticsProvider).isEmpty, isTrue);
      n.loaded(_loaded);
      n.answered(firstPieceSeconds: 1, pieces: 2, totalSeconds: 3, piecesPerSecond: 1);
      expect(c.read(tutorDiagnosticsProvider).pieces, 2);
    });
  });

  group('tarjeta de diagnostico', () {
    Future<ProviderContainer> show(WidgetTester tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: DiagnosticsCard())),
          ),
        ),
      );
      return c;
    }

    testWidgets('vacia pide abrir el tutor; con datos muestra el informe y lo copia', (
      tester,
    ) async {
      final c = await show(tester);
      expect(find.textContaining('Abre el tutor y haz una pregunta'), findsOneWidget);
      expect(find.text('Copiar'), findsNothing);

      c.read(tutorDiagnosticsProvider.notifier).loaded(_loaded);
      await tester.pump();
      expect(find.textContaining('Hilos: 4 de 8'), findsOneWidget);

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.text('Copiar'));
      await tester.pump();
      expect(copied, contains('Hilos: 4 de 8'));
      expect(find.text('Diagnóstico copiado'), findsOneWidget);
    });
  });
}
