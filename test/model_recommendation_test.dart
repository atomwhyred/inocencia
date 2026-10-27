import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/theme/app_theme.dart';
import 'package:inocencia/features/external_data/domain/model_recommendation.dart';
import 'package:inocencia/features/external_data/presentation/files_section.dart';

const _gb = 1024 * 1024 * 1024;

void main() {
  group('ModelRecommendation', () {
    test('un movil de 8 GB (Android informa ~7,4 GB) recibe el modelo grande', () {
      expect(ModelRecommendation.forRam((7.4 * _gb).round()), ModelRecommendation.large);
    });

    test('con menos de 7 GB se recomienda el pequeno', () {
      expect(ModelRecommendation.forRam(6 * _gb), ModelRecommendation.small);
      expect(ModelRecommendation.forRam(2 * _gb), ModelRecommendation.small);
    });

    test('avisa de poca memoria por debajo de 3 GB', () {
      expect(ModelRecommendation.isLowRam(2 * _gb), isTrue);
      expect(ModelRecommendation.isLowRam(4 * _gb), isFalse);
    });

    test('reconoce el modelo vinculado por el nombre del archivo', () {
      expect(
        ModelRecommendation.identify('/sd/Android/data/x/Qwen2.5-3B-Instruct-Q4_K_M.gguf'),
        ModelRecommendation.large,
      );
      expect(ModelRecommendation.identify('/a/otro.gguf'), isNull);
      expect(ModelRecommendation.identify(null), isNull);
    });
  });

  group('ModelAdviceCard', () {
    Future<void> pump(WidgetTester t, int ram, {String? linked}) => t.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: SingleChildScrollView(child: ModelAdviceCard(ramBytes: ram, linkedPath: linked))),
          ),
        );

    testWidgets('movil de 8 GB: recomienda Qwen2.5-3B y ofrece el 1.5B', (t) async {
      await pump(t, 8 * _gb);
      expect(find.textContaining('8,0 GB'), findsOneWidget);
      expect(find.textContaining('Qwen2.5-3B (2,1 GB)'), findsOneWidget);
      expect(find.textContaining('Alternativa: Qwen2.5-1.5B'), findsOneWidget);
      expect(find.textContaining('poca memoria'), findsNothing);
    });

    testWidgets('movil de 2 GB: avisa de poca memoria', (t) async {
      await pump(t, 2 * _gb);
      expect(find.textContaining('poca memoria'), findsOneWidget);
      expect(find.textContaining('Qwen2.5-1.5B (1,1 GB)'), findsOneWidget);
    });

    testWidgets('indica si el modelo vinculado es el recomendado', (t) async {
      await pump(t, 8 * _gb, linked: '/x/qwen2.5-3b-instruct-q4_k_m.gguf');
      expect(find.text('Ya tienes vinculado el modelo recomendado.'), findsOneWidget);
    });

    testWidgets('si el vinculado es el otro, lo dice', (t) async {
      await pump(t, 8 * _gb, linked: '/x/qwen2.5-1.5b-instruct-q4_k_m.gguf');
      expect(find.text('Tienes vinculado Qwen2.5-1.5B.'), findsOneWidget);
    });
  });
}
