import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inocencia/core/di/providers.dart';
import 'package:inocencia/core/security/pin_hasher.dart';
import 'package:inocencia/core/storage/app_database.dart';
import 'package:inocencia/features/auth/application/session.dart';
import 'package:inocencia/features/flashcards/data/flashcard_repository_impl.dart';
import 'package:inocencia/features/flashcards/domain/flashcard.dart';
import 'package:inocencia/features/flashcards/presentation/flashcards_page.dart';
import 'package:inocencia/features/flashcards/presentation/study_page.dart';
import 'package:inocencia/features/profiles/data/child_profile_repository_impl.dart';
import 'package:inocencia/features/profiles/domain/child_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late int leo;

  Future<void> boot(WidgetTester tester, {List<FlashcardDraft> deck = const []}) async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    leo = await ChildProfileRepositoryImpl(
      db,
      const PinHasher(iterations: 10),
    ).create(ChildProfileInput(name: 'Leo', avatar: 'emoji:🦊', birthDate: DateTime(2015, 3, 1)));
    await FlashcardRepositoryImpl(db).addAll(leo, deck, DateTime(2026, 10, 30));
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    c.read(sessionProvider.notifier).selectChild(leo);
    final router = GoRouter(
      initialLocation: '/flashcards',
      routes: [
        GoRoute(
          path: '/flashcards',
          builder: (_, _) => const FlashcardsPage(),
          routes: [GoRoute(path: 'study', builder: (_, _) => const StudyPage())],
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.runAsync(db.close);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  const two = [
    FlashcardDraft(front: '¿Qué es un sustantivo?', back: 'Un nombre de cosas.'),
    FlashcardDraft(
      front: '¿Qué dice el adjetivo?',
      back: 'Cómo es algo.',
      source: 'Español · pág. 3',
    ),
  ];

  testWidgets('sin tarjetas explica como crearlas y no ofrece estudiar', (tester) async {
    await boot(tester);
    expect(find.text('Aún no tienes tarjetas'), findsOneWidget);
    expect(find.textContaining('Estudiar'), findsNothing);
  });

  testWidgets('el mazo lista las tarjetas y se pueden borrar', (tester) async {
    await boot(tester, deck: two);
    expect(find.text('Estudiar (2)'), findsOneWidget);
    expect(find.text('¿Qué es un sustantivo?'), findsOneWidget);
    expect(find.text('Sin repasar'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Borrar tarjeta').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Estudiar (1)'), findsOneWidget);
  });

  testWidgets('repaso: se voltea la tarjeta, se contesta y al final salen los resultados', (
    tester,
  ) async {
    await boot(tester, deck: two);
    await tester.tap(find.text('Estudiar (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Tarjeta 1 de 2'), findsOneWidget);
    expect(find.text('Pregunta'), findsOneWidget);
    expect(find.text('La sabía'), findsNothing, reason: 'primero hay que ver la respuesta');

    // Primera: la sabia. Segunda: la falla una vez y luego la sabe.
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();
    expect(find.text('Respuesta'), findsOneWidget);
    await tester.tap(find.text('La sabía'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('A repasar'));
    await tester.pumpAndSettle();
    expect(find.text('Pregunta'), findsOneWidget, reason: 'la fallada vuelve');

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('La sabía'));
    await tester.pumpAndSettle();

    expect(find.text('Sabías 1 de 2 tarjetas a la primera.'), findsOneWidget);
    await tester.tap(find.text('Terminar'));
    await tester.pumpAndSettle();
    expect(find.text('Mis tarjetas'), findsOneWidget);
  });

  testWidgets('en el repaso queda anotado cuantas veces la sabia', (tester) async {
    await boot(
      tester,
      deck: const [FlashcardDraft(front: 'a?', back: 'b')],
    );
    await tester.tap(find.text('Estudiar (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('La sabía'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.tap(find.text('Terminar'));
    await tester.pumpAndSettle();
    expect(find.text('La sabías 1 de 1 veces'), findsOneWidget);
  });
}
