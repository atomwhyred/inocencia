import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inocencia/core/di/providers.dart';
import 'package:inocencia/core/security/pin_hasher.dart';
import 'package:inocencia/core/storage/app_database.dart';
import 'package:inocencia/features/achievements/application/achievement_service.dart';
import 'package:inocencia/features/achievements/domain/achievement.dart';
import 'package:inocencia/features/auth/application/session.dart';
import 'package:inocencia/features/flashcards/data/flashcard_repository_impl.dart';
import 'package:inocencia/features/flashcards/domain/flashcard.dart';
import 'package:inocencia/features/game/domain/game_rules.dart';
import 'package:inocencia/features/game/presentation/game_menu_page.dart';
import 'package:inocencia/features/game/presentation/local_game_page.dart';
import 'package:inocencia/features/game/presentation/local_setup_page.dart';
import 'package:inocencia/features/mascot/application/mascot_settings.dart';
import 'package:inocencia/features/profiles/data/child_profile_repository_impl.dart';
import 'package:inocencia/features/profiles/domain/child_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tarjetas de cada niño: pregunta → respuesta (así el test sabe cuál tocar).
const anaCards = {'¿Color del cielo?': 'Azul', '¿Capital de Cuba?': 'La Habana', '¿2 + 2?': 'Cuatro'};
const leoCards = {'¿Qué es un verbo?': 'Una acción', '¿Plural de lápiz?': 'Lápices', '¿Qué es un adjetivo?': 'Describe'};

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late ProviderContainer c;
  late int ana;

  Future<void> boot(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    final profiles = ChildProfileRepositoryImpl(db, const PinHasher(iterations: 10));
    final cards = FlashcardRepositoryImpl(db);
    await tester.runAsync(() async {
      ana = await profiles.create(
        ChildProfileInput(name: 'Ana', avatar: 'emoji:🦊', birthDate: DateTime(2018, 3, 1), gradeOverride: 2),
      );
      final leo = await profiles.create(
        ChildProfileInput(name: 'Leo', avatar: 'emoji:🐼', birthDate: DateTime(2014, 3, 1), gradeOverride: 6),
      );
      Future<void> add(int id, Map<String, String> m) => cards.addAll(
        id,
        [for (final e in m.entries) FlashcardDraft(front: e.key, back: e.value)],
        DateTime(2026, 11, 8),
      );
      await add(ana, anaCards);
      await add(leo, leoCards);
    });
    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        appDatabaseProvider.overrideWithValue(db),
        mascotAnimateProvider.overrideWithValue(false),
      ],
    );
    c.read(sessionProvider.notifier).selectChild(ana);
    final router = GoRouter(
      initialLocation: '/game',
      routes: [
        GoRoute(
          path: '/game',
          builder: (_, _) => const GameMenuPage(),
          routes: [
            GoRoute(
              path: 'local',
              builder: (_, s) => LocalSetupPage(mode: s.extra as GameMode? ?? GameMode.race),
              routes: [
                GoRoute(
                  path: 'play',
                  builder: (_, s) {
                    final (mode, kids) = s.extra! as (GameMode, List<ChildProfile>);
                    return LocalGamePage(mode: mode, kids: kids);
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.runAsync(db.close);
    });
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
  }

  /// Espera a la base (las consultas de Drift van fuera del reloj falso).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('dos niños de grados distintos juegan una carrera en un teléfono hasta el podio', (tester) async {
    await boot(tester);
    expect(find.text('Carrera'), findsOneWidget);
    await tester.tap(find.text('En este teléfono'));
    await settle(tester);

    // Cada niño se ve con su grado; Ana (la del perfil activo) ya viene marcada.
    expect(find.text('2.º grado'), findsOneWidget);
    expect(find.text('6.º grado'), findsOneWidget);
    expect(find.text('Elige al menos 2'), findsOneWidget);
    await tester.tap(find.text('Leo'));
    await tester.pump();
    await tester.tap(find.text('¡A jugar! (2)'));
    await settle(tester);

    // Ana acierta siempre (tarjetas: +2) y Leo falla siempre: Ana llega en 5 rondas.
    for (var round = 0; round < 5; round++) {
      for (final who in ['Ana', 'Leo']) {
        expect(find.text('Le toca a $who'), findsOneWidget, reason: 'ronda ${round + 1}');
        await tester.tap(find.text('¡Estoy listo!'));
        // Sin pumpAndSettle: esperaría a que se vacíe la barra de tiempo (35 s) y se acabaría el tiempo.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Tu tarjeta · vale 2'), findsOneWidget);
        final cards = who == 'Ana' ? anaCards : leoCards;
        final question = cards.keys.firstWhere((q) => find.text(q).evaluate().isNotEmpty);
        final right = cards[question]!;
        final wrong = cards.values.firstWhere((a) => a != right);
        await tester.tap(find.text(who == 'Ana' ? right : wrong));
        await tester.pumpAndSettle();
        expect(find.text(who == 'Ana' ? '+2' : '¡Casi! La buena está en verde.'), findsOneWidget);
        await tester.tap(find.text('Siguiente'));
        await settle(tester);
      }
    }

    expect(find.text('¡Ganó Ana!'), findsOneWidget);
    expect(find.text('10 casillas'), findsOneWidget);
    expect(find.text('⭐ 6'), findsOneWidget, reason: '1 por jugar + 10 ~/ 3 + 2 por ganar');
    final stars = await tester.runAsync(() => c.read(achievementRepositoryProvider).counter(ana, Counters.correct));
    expect(stars, 6);
  });

  testWidgets('salir a mitad de partida pide confirmación', (tester) async {
    await boot(tester);
    await tester.tap(find.text('En este teléfono'));
    await settle(tester);
    await tester.tap(find.text('Leo'));
    await tester.pump();
    await tester.tap(find.text('¡A jugar! (2)'));
    await settle(tester);
    expect(find.text('Le toca a Ana'), findsOneWidget);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('¿Salir de la partida?'), findsOneWidget);
    await tester.tap(find.text('Seguir jugando'));
    await tester.pumpAndSettle();
    expect(find.text('Le toca a Ana'), findsOneWidget);
  });
}
