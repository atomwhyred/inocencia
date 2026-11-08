import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/di/providers.dart';
import 'package:inocencia/features/external_data/presentation/files_section.dart';
import 'package:inocencia/features/tutor/application/tutor_diagnostics_provider.dart';
import 'package:inocencia/features/tutor/domain/tutor_diagnostics.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    test('el informe da los hilos del prompt y su velocidad en tokens/s', () {
      final d = const TutorDiagnostics(
        model: 'qwen2.5-3b-instruct-q4_0.gguf',
        threads: 4,
        batchThreads: 8,
        cores: 8,
      ).withAnswer(
        firstPieceSeconds: 10,
        pieces: 80,
        totalSeconds: 20,
        piecesPerSecond: 8,
        promptChars: 2000,
        promptTokens: 600,
      );
      final r = d.toReport();
      expect(r, contains('Hilos: 4 de 8 nucleos (8 para el prompt)'));
      expect(r, contains('prompt de 2000 caracteres (600 tokens, 60.0 tokens/s)'));
    });

    test('se guarda y se lee en JSON sin perder nada', () {
      final d = _loaded.withAnswer(
        firstPieceSeconds: 12,
        pieces: 80,
        totalSeconds: 20,
        piecesPerSecond: 8.5,
        promptChars: 1900,
        promptTokens: 550,
      );
      final json = jsonDecode(jsonEncode(d.toJson())) as Map<String, Object?>;
      expect(TutorDiagnostics.fromJson(json), d);
      expect(TutorDiagnostics.fromJson(const {'threads': 'x'}).isEmpty, isTrue);
    });

    test('el notificador recuerda el ultimo diagnostico tras reiniciar la app', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ProviderContainer make() {
        final c = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(c.dispose);
        return c;
      }

      make().read(tutorDiagnosticsProvider.notifier)
        ..loaded(_loaded)
        ..answered(
          firstPieceSeconds: 5,
          pieces: 9,
          totalSeconds: 7,
          piecesPerSecond: 4,
          promptTokens: 300,
        );
      final again = make().read(tutorDiagnosticsProvider);
      expect(again.model, _loaded.model);
      expect(again.promptTokens, 300);
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

  group('valoracion', () {
    TutorDiagnostics answered(String model, {int first = 10, double rate = 8}) =>
        TutorDiagnostics(model: model).withAnswer(
          firstPieceSeconds: first,
          pieces: 80,
          totalSeconds: 30,
          piecesPerSecond: rate,
          promptChars: 2900,
        );

    test('el 7B avisa de que es muy lento', () {
      expect(answered('qwen2.5-7b-instruct-q4_k_m.gguf').verdict(), contains('7B es muy lento'));
    });

    test('generar despacio sugiere un modelo menor; tardar en empezar se explica', () {
      expect(
        answered('qwen2.5-3b-instruct-q4_k_m.gguf', rate: 2).verdict(),
        contains('menos de 3 piezas/s'),
      );
      expect(
        answered('qwen2.5-3b-instruct-q4_k_m.gguf', first: 40).verdict(),
        contains('tarda en empezar'),
      );
      expect(answered('qwen2.5-3b-instruct-q4_k_m.gguf').verdict(), 'Velocidad normal.');
    });

    test('el informe lleva la RAM y el tamano del prompt', () {
      final r = answered('qwen2.5-3b-instruct-q4_k_m.gguf')
          .toReport(ramBytes: 12 * 1024 * 1024 * 1024);
      expect(r, contains('RAM del dispositivo: 12.0 GB'));
      expect(r, contains('prompt de 2900 caracteres'));
      expect(r, contains('Valoracion: Velocidad normal.'));
    });
  });

  group('tarjeta de diagnostico', () {
    Future<ProviderContainer> show(WidgetTester tester) async {
      final c = ProviderContainer(
        overrides: [deviceRamProvider.overrideWith((ref) async => 12 * 1024 * 1024 * 1024)],
      );
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
      expect(find.text('Hacer la prueba'), findsOneWidget);

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
      await tester.ensureVisible(find.text('Copiar'));
      await tester.tap(find.text('Copiar'));
      await tester.pump();
      expect(copied, contains('Hilos: 4 de 8'));
      expect(copied, contains('Hilos: automaticos'));
      expect(find.text('Diagnóstico copiado'), findsOneWidget);
    });
  });
}
