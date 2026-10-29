import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/app.dart';
import 'package:inocencia/core/di/providers.dart';
import 'package:inocencia/core/router/app_router.dart';
import 'package:inocencia/core/security/pin_hasher.dart';
import 'package:inocencia/core/storage/app_database.dart';
import 'package:inocencia/features/auth/application/session.dart';
import 'package:inocencia/features/external_data/domain/external_files_repository.dart';
import 'package:inocencia/features/library/data/reading_progress_repository_impl.dart';
import 'package:inocencia/features/library/presentation/book_viewer.dart';
import 'package:inocencia/features/external_data/domain/linked_file_status.dart';
import 'package:inocencia/features/knowledge/domain/knowledge_chunk.dart';
import 'package:inocencia/features/tutor/application/tutor_controller.dart';
import 'package:inocencia/features/tutor/data/tutor_history_repository_impl.dart';
import 'package:inocencia/features/tutor/domain/tutor_engine.dart';
import 'package:inocencia/features/tutor/domain/tutor_prompt.dart';
import 'package:inocencia/features/tutor/domain/tutor_history_repository.dart';
import 'package:inocencia/features/tutor/domain/tutor_source.dart';
import 'package:inocencia/features/mascot/application/mascot_atlas.dart';
import 'package:inocencia/features/mascot/application/mascot_settings.dart';
import 'package:inocencia/features/achievements/data/achievement_repository_impl.dart';
import 'package:inocencia/features/profiles/data/child_profile_repository_impl.dart';
import 'package:inocencia/features/profiles/domain/child_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

/// Visor falso: PDFium no se puede cargar en las pruebas de widgets. Hace lo que
/// el real: avisa de la pagina inicial y de cada salto.
class _FakeViewer implements BookViewerFactory {
  _FakeController? last;

  @override
  BookViewerController createController() => last = _FakeController();

  @override
  Widget build(BuildContext context, BookViewerRequest request) {
    final c = request.controller as _FakeController;
    c
      ..total = 3
      ..onPageChanged = request.onPageChanged;
    // Solo la primera vez: reconstruir el visor no devuelve a la pagina inicial.
    if (!c.started) {
      c.started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => c.show(request.initialPage));
    }
    return ColoredBox(color: request.background, child: Center(child: Text('PDF ${request.path}')));
  }
}

class _FakeController implements BookViewerController {
  int total = 0;
  int page = 0;
  bool started = false;
  ValueChanged<int?>? onPageChanged;

  void show(int p) {
    page = p;
    onPageChanged?.call(p);
  }

  @override
  bool get isReady => total > 0;

  @override
  int get pageCount => total;

  @override
  Future<void> goToPage(int p) async => show(p);
}

/// Motor y base de libros vacios: solo hacen falta para que el tutor quede listo.
class _IdleEngine implements TutorEngine {
  bool loaded = false;

  @override
  bool get isLoaded => loaded;

  @override
  Future<void> load(String modelPath, {bool lowPower = false}) async => loaded = true;

  @override
  Stream<String> generate(List<ChatTurn> turns, {int? maxTokens}) => const Stream.empty();

  @override
  Future<void> dispose() async => loaded = false;
}

class _EmptyKnowledge implements KnowledgeRepository {
  @override
  Future<List<KnowledgeChunk>> search(String question,
          {required int grade, String? subject, int limit = 3}) async =>
      const [];

  @override
  Future<List<String>> subjectsForGrade(int grade) async => const [];

  @override
  Future<void> close() async {}
}

class _Files implements ExternalFilesRepository {
  _Files(this.knowledgePath, this.dir);

  @override
  final String? knowledgePath;
  @override
  String? get booksFolder => null;
  final String dir;

  @override
  Future<LinkedFilesStatus> check() async => LinkedFilesStatus(
        model: const LinkedFileStatus(state: LinkState.ready, path: '/fake/model.gguf'),
        knowledge: KnowledgeDbStatus(state: LinkState.ready, path: knowledgePath),
      );

  @override
  Future<List<String>> appStorageDirs() async => [dir];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory tmp;
  late AppDatabase db;
  late int leo;
  late ProviderContainer container;
  late _FakeViewer viewer;

  Future<void> boot(WidgetTester tester, {Size size = const Size(420, 900), bool withPdf = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    tmp = Directory.systemTemp.createTempSync('inocencia_flujo_');
    final files = Directory('${tmp.path}/files/libros')..createSync(recursive: true);
    if (withPdf) File('test/fixtures/tres_paginas.pdf').copySync('${files.path}/6to_matematica.pdf');

    final kb = sql.sqlite3.open('${tmp.path}/knowledge.db');
    kb.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
    kb.execute("INSERT INTO meta VALUES ('books', ?)", [
      jsonEncode([
        {'file': '6to_matematica.pdf', 'subject': 'Matemática', 'grades': [6], 'kind': 'Libro', 'pages': 3},
        {'file': '6to_historia.pdf', 'subject': 'Historia', 'grades': [6], 'kind': 'Libro', 'pages': 90},
      ]),
    ]);
    kb.close();

    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.guardians).insert(GuardiansCompanion.insert(
          name: 'Ana',
          pinHash: PinHasher.hashSync('1234', iterations: 10),
          pinLength: 4,
        ));
    leo = await ChildProfileRepositoryImpl(db, const PinHasher(iterations: 10)).create(
      ChildProfileInput(
        name: 'Leo',
        avatar: 'emoji:🦊',
        birthDate: DateTime(2015, 3, 1),
        gradeOverride: 6,
      ),
    );

    viewer = _FakeViewer();
    container = ProviderContainer(overrides: [
      bookViewerFactoryProvider.overrideWithValue(viewer),
      mascotAnimateProvider.overrideWithValue(false),
      mascotAtlasProvider.overrideWith((ref) async => null),
      tutorEngineProvider.overrideWithValue(_IdleEngine()),
      knowledgeRepositoryFactoryProvider.overrideWithValue((_) => _EmptyKnowledge()),
      sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
      appDatabaseProvider.overrideWithValue(db),
      externalFilesRepositoryProvider
          .overrideWithValue(_Files('${tmp.path}/knowledge.db', '${tmp.path}/files')),
    ]);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.runAsync(db.close);
      tmp.deleteSync(recursive: true);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const InocenciaApp()),
    );
    await tester.pumpAndSettle();
  }

  /// Termina la transicion de ruta y deja correr tiempo real (lectura de
  /// archivos, PDFium). Cada paso de E/S real necesita un `pump` para que su
  /// continuacion corra en la zona del test, por eso son muchas vueltas cortas.
  /// No se usa `pumpAndSettle`: un indicador de carga que gira nunca se asienta.
  Future<void> settle(WidgetTester tester, [int ms = 600]) async {
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < ms ~/ 15; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump(const Duration(milliseconds: 15));
    }
  }

  testWidgets('elegir perfil lleva al inicio con el tutor y los libros', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Leo'));
    await tester.pumpAndSettle();

    expect(find.text('¡Hola, Leo!'), findsOneWidget);
    expect(find.text('6.º grado'), findsOneWidget);
    expect(find.text('Mi tutor'), findsOneWidget);
    expect(find.text('Mis libros'), findsOneWidget);
  });

  testWidgets('en una tablet las dos tarjetas van en una fila', (tester) async {
    await boot(tester, size: const Size(1200, 800));
    await tester.tap(find.text('Leo'));
    await tester.pumpAndSettle();
    final tutor = tester.getTopLeft(find.text('Mi tutor'));
    final books = tester.getTopLeft(find.text('Mis libros'));
    expect(books.dy, tutor.dy);
    expect(books.dx, greaterThan(tutor.dx));
  });

  testWidgets('Mis libros separa los que están en el teléfono de los que faltan', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Leo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis libros'));
    await tester.pump();
    await settle(tester);

    expect(find.text('Matemática'), findsOneWidget);
    expect(find.text('3 páginas'), findsOneWidget);
    expect(find.text('Aún no están en este teléfono'), findsOneWidget);
    expect(find.text('Historia'), findsOneWidget);
    expect(find.text('No está en este teléfono'), findsOneWidget);
  });

  testWidgets('un libro que no está copiado no se puede abrir', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Leo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis libros'));
    await tester.pump();
    await settle(tester);

    await tester.tap(find.text('Historia'));
    await tester.pumpAndSettle();
    expect(find.text('Mis libros'), findsOneWidget); // sigue en la lista
    expect(find.textContaining('Página'), findsNothing);
  });

  testWidgets('sin ningún PDF avisa de que hay que copiarlos', (tester) async {
    await boot(tester, withPdf: false);
    await tester.tap(find.text('Leo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis libros'));
    await tester.pump();
    await settle(tester);
    expect(find.text('Todavía no hay libros en este teléfono.'), findsOneWidget);
  });

  testWidgets('abre el libro en la página guardada y la actualiza al pasar de página', (tester) async {
    await boot(tester);
    await ReadingProgressRepositoryImpl(db).save(leo, '6to_matematica', 2);
    container.read(sessionProvider.notifier).selectChild(leo);
    container.read(routerProvider).go('/books/6to_matematica');
    await tester.pump();
    await settle(tester, 1500);

    expect(find.text('Matemática'), findsWidgets); // titulo del lector
    expect(find.text('Página 2 de 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pump();
    await settle(tester, 1500);
    expect(find.text('Página 3 de 3'), findsOneWidget);
    // El boton siguiente se desactiva en la ultima pagina.
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right_rounded)).onPressed,
        isNull);

    // Al salir se vuelca la página a la base.
    container.read(routerProvider).go('/home');
    await tester.pumpAndSettle();
    expect(await ReadingProgressRepositoryImpl(db).get(leo, '6to_matematica'), 3);
  });

  testWidgets('una página pedida (fuente del tutor) gana a la guardada', (tester) async {
    await boot(tester);
    await ReadingProgressRepositoryImpl(db).save(leo, '6to_matematica', 3);
    container.read(sessionProvider.notifier).selectChild(leo);
    container.read(routerProvider).go('/books/6to_matematica?page=1');
    await tester.pump();
    await settle(tester, 1500);
    expect(find.text('Página 1 de 3'), findsOneWidget);
  });

  testWidgets('una página fuera del libro se ajusta al rango', (tester) async {
    await boot(tester);
    container.read(sessionProvider.notifier).selectChild(leo);
    container.read(routerProvider).go('/books/6to_matematica?page=999');
    await tester.pump();
    await settle(tester, 1500);
    expect(find.text('Página 3 de 3'), findsOneWidget);
  });

  testWidgets('en la pantalla de perfiles cada niño muestra su grado bajo el nombre', (tester) async {
    await boot(tester);
    await tester.pumpAndSettle();
    expect(find.text('Leo'), findsOneWidget);
    expect(find.textContaining(RegExp(r'grado$')), findsOneWidget);
  });

  testWidgets('Mis medallas: el inicio resume el progreso y la pantalla muestra ganadas y por ganar',
      (tester) async {
    await boot(tester);
    final repo = AchievementRepositoryImpl(db);
    await tester.runAsync(() async {
      await repo.award(leo, 'first_topic', DateTime(2026, 10, 29));
      await repo.addToCounter(leo, 'correct', 4);
    });
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.tap(find.text('Leo'));
    await settle(tester, 300);

    expect(find.text('Mis medallas'), findsOneWidget);
    expect(find.text('1 medalla · 4 estrellas'), findsOneWidget);

    await tester.tap(find.text('Mis medallas'));
    await settle(tester, 300);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Primer tema'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Primer tema\.\s*Ganada')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Quiz perfecto\.\s*Por ganar')), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
  });

  testWidgets('el lector y los libros exigen haber elegido perfil', (tester) async {
    await boot(tester);
    container.read(routerProvider).go('/books/6to_matematica');
    await tester.pumpAndSettle();
    expect(find.text('¿Quién va a aprender hoy?'), findsOneWidget);
    container.read(routerProvider).go('/home');
    await tester.pumpAndSettle();
    expect(find.text('¿Quién va a aprender hoy?'), findsOneWidget);
  });

  testWidgets('tocar una fuente del tutor abre ese libro en esa página', (tester) async {
    await boot(tester);
    // Una conversacion guardada cuyas fuentes citan dos libros.
    await TutorHistoryRepositoryImpl(db).add(
      leo,
      const StoredTutorMessage(
        fromUser: false,
        text: 'Las fracciones parten un entero. ¿Cuántas partes tiene?',
        sources: [
          TutorSource(subject: 'Matemática', book: '6to_matematica', page: 2),
          TutorSource(subject: 'Historia', book: '6to_historia', page: 40),
        ],
      ),
    );
    container.read(sessionProvider.notifier).selectChild(leo);
    container.read(routerProvider).go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Mi tutor'));
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester, 900);

    expect(find.text('Matemática · 6to_matematica · pág. 2'), findsOneWidget);
    await tester.tap(find.text('Matemática · 6to_matematica · pág. 2'));
    await settle(tester, 900);
    expect(container.read(routerProvider).state.uri.toString(), '/books/6to_matematica?page=2');
    expect(find.text('Página 2 de 3'), findsOneWidget);
  });


  testWidgets('"Ir a la página" lleva a la página escrita, se ajusta al rango y se puede cancelar', (tester) async {
    await boot(tester);
    container.read(sessionProvider.notifier).selectChild(leo);
    container.read(routerProvider).go('/books/6to_matematica');
    await tester.pump();
    await settle(tester, 900);
    expect(find.text('Página 1 de 3'), findsOneWidget);

    Future<void> goTo(String text) async {
      await tester.tap(find.text('Página ${viewer.last!.page} de 3'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Ir a la página'), findsOneWidget);
      expect(find.text('Del 1 al 3'), findsOneWidget);
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.text('Ir'));
      // Deja terminar la animacion de salida del dialogo (aqui fallaba).
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
    }

    await goTo('3');
    expect(tester.takeException(), isNull);
    expect(find.text('Página 3 de 3'), findsOneWidget);

    await goTo('999'); // fuera del libro: se queda en la ultima
    expect(find.text('Página 3 de 3'), findsOneWidget);

    await goTo('2');
    expect(find.text('Página 2 de 3'), findsOneWidget);

    // Cancelar no cambia nada.
    await tester.tap(find.text('Página 2 de 3'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Cancelar'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.text('Página 2 de 3'), findsOneWidget);
  });

}
