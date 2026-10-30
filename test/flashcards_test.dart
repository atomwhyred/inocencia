import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/di/providers.dart';
import 'package:inocencia/core/security/pin_hasher.dart';
import 'package:inocencia/core/storage/app_database.dart';
import 'package:inocencia/features/auth/application/session.dart';
import 'package:inocencia/features/flashcards/application/flashcard_providers.dart';
import 'package:inocencia/features/flashcards/application/flashcards_controller.dart';
import 'package:inocencia/features/flashcards/application/study_controller.dart';
import 'package:inocencia/features/flashcards/data/flashcard_repository_impl.dart';
import 'package:inocencia/features/flashcards/data/llama_flashcard_generator.dart';
import 'package:inocencia/features/flashcards/domain/flashcard.dart';
import 'package:inocencia/features/flashcards/domain/flashcard_generator.dart';
import 'package:inocencia/features/flashcards/domain/flashcard_parser.dart';
import 'package:inocencia/features/knowledge/domain/knowledge_chunk.dart';
import 'package:inocencia/features/profiles/data/child_profile_repository_impl.dart';
import 'package:inocencia/features/profiles/domain/child_profile.dart';
import 'package:inocencia/features/tutor/application/tutor_controller.dart';
import 'package:inocencia/features/tutor/domain/tutor_engine.dart';
import 'package:inocencia/features/tutor/domain/tutor_prompt.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

const _chunk = KnowledgeChunk(
  id: 1,
  grade: 2,
  subject: 'Español',
  book: '2do_lengua',
  page: 138,
  text:
      'Un sustantivo es un nombre que se refiere a cosas, lugares o personas. '
      'El adjetivo dice cómo es el sustantivo. Los verbos dicen lo que hacemos.',
);

class _FakeEngine implements TutorEngine {
  final pieces = <String>[];
  var calls = 0;
  int? lastMaxTokens;

  @override
  Future<void> load(String modelPath, {bool lowPower = false}) async {}

  @override
  bool get isLoaded => true;

  @override
  Stream<String> generate(List<ChatTurn> turns, {int? maxTokens}) {
    calls++;
    lastMaxTokens = maxTokens;
    return Stream.fromIterable(pieces);
  }

  @override
  Future<void> dispose() async {}
}

class _FakeGenerator implements FlashcardGenerator {
  final controller = StreamController<FlashcardDraft>();
  var asked = 0;

  @override
  Stream<FlashcardDraft> generate({required int grade, required List<KnowledgeChunk> chunks}) {
    asked++;
    return controller.stream;
  }
}

class _FakeTutor extends TutorController {
  _FakeTutor(this.chunks);
  final List<KnowledgeChunk> chunks;

  @override
  TutorState build() => const TutorState();

  @override
  Future<List<KnowledgeChunk>> quizChunks(int grade) async => chunks;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  group('FlashcardParser', () {
    test('lee tarjetas bien formadas, con ruido de mayusculas y numeracion', () {
      const raw = '''
T1: ¿Qué es un sustantivo?
R: Un nombre de cosas, lugares o personas.
tarjeta 2) ¿Qué dice el adjetivo?
Respuesta: Cómo es el sustantivo.
**3.** ¿Qué dicen los verbos?
r - Lo que hacemos.''';
      final cards = FlashcardParser.parse(raw);
      expect(cards.map((c) => c.front), [
        '¿Qué es un sustantivo?',
        '¿Qué dice el adjetivo?',
        '¿Qué dicen los verbos?',
      ]);
      expect(cards[2].back, 'Lo que hacemos.');
    });

    test('mientras llega el texto deja fuera la ultima tarjeta (puede estar a medias)', () {
      const raw = 'T1: ¿Qué es un sustantivo?\nR: Un nombre.\nT2: ¿Qué dice el adjetivo?\nR: Cómo';
      expect(FlashcardParser.parse(raw, complete: false).length, 1);
      expect(FlashcardParser.parse(raw).length, 2);
    });

    test('descarta las tarjetas sin reverso y el texto suelto', () {
      const raw = 'Aquí tienes:\nT1: ¿Qué es un sustantivo?\nT2: ¿Y el verbo?\nR: Lo que hacemos.';
      final cards = FlashcardParser.parse(raw);
      expect(cards.single.front, '¿Y el verbo?');
    });
  });

  group('FlashcardGrounding', () {
    final book = _chunk.text;
    FlashcardDraft card(String f, String b) => FlashcardDraft(front: f, back: b);

    test('acepta una respuesta hecha con palabras del libro', () {
      expect(
        FlashcardGrounding.isGrounded(
          card('¿Qué es un sustantivo?', 'Un nombre de cosas, lugares o personas.'),
          book,
        ),
        isTrue,
      );
    });

    test('rechaza respuestas inventadas', () {
      expect(
        FlashcardGrounding.isGrounded(
          card('¿Qué es un sustantivo?', 'Una máquina para volar hasta la luna.'),
          book,
        ),
        isFalse,
      );
    });

    test('rechaza las que dependen del libro (página, recuadro, dibujo)', () {
      expect(
        FlashcardGrounding.isGrounded(
          card('¿Qué dice el recuadro?', 'Cómo es el sustantivo.'),
          book,
        ),
        isFalse,
      );
      expect(
        FlashcardGrounding.isGrounded(card('¿Qué dice el adjetivo?', 'Mira la página 138.'), book),
        isFalse,
      );
    });

    test('rechaza frente igual al reverso o demasiado largo', () {
      expect(FlashcardGrounding.isGrounded(card('Los verbos', 'los verbos'), book), isFalse);
      expect(FlashcardGrounding.isGrounded(card('${'a' * 150}?', 'Un nombre.'), book), isFalse);
    });
  });

  group('LlamaFlashcardGenerator', () {
    test('saca las tarjetas validas segun llegan y para en el maximo', () async {
      final engine = _FakeEngine()
        ..pieces.addAll([
          'T1: ¿Qué es un sustantivo?\nR: Un nombre de cosas, lugares o personas.\n',
          'T2: ¿Qué dice el adjetivo?\nR: Cómo es el sustantivo.\n',
          'T3: ¿Qué hace la luna?\nR: Vuela por el cielo con alas de oro.\n',
          'T4: ¿Qué dicen los verbos?\nR: Lo que hacemos.',
        ]);
      final out = await LlamaFlashcardGenerator(engine)
          .generate(grade: 2, chunks: const [_chunk])
          .toList();
      expect(out.map((c) => c.front), [
        '¿Qué es un sustantivo?',
        '¿Qué dice el adjetivo?',
        '¿Qué dicen los verbos?',
      ], reason: 'la tarjeta inventada (luna) se descarta');
      expect(out.first.source, contains('2do_lengua'));
      expect(engine.lastMaxTokens, 320);
      expect(engine.calls, 1);
    });

    test('si la primera vez no sale ninguna, reintenta una vez', () async {
      final engine = _FakeEngine()..pieces.add('No sé qué decir.');
      final out = await LlamaFlashcardGenerator(engine)
          .generate(grade: 2, chunks: const [_chunk])
          .toList();
      expect(out, isEmpty);
      expect(engine.calls, 2);
    });
  });

  group('repositorio y migracion', () {
    late AppDatabase db;
    late FlashcardRepositoryImpl repo;
    late int leo;
    late int ana;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      final profiles = ChildProfileRepositoryImpl(db, const PinHasher(iterations: 10));
      leo = await profiles.create(
        ChildProfileInput(name: 'Leo', avatar: 'emoji:🦊', birthDate: DateTime(2015, 3, 1)),
      );
      ana = await profiles.create(
        ChildProfileInput(name: 'Ana', avatar: 'emoji:🐱', birthDate: DateTime(2016, 3, 1)),
      );
      repo = FlashcardRepositoryImpl(db);
    });
    tearDown(() => db.close());

    final t0 = DateTime(2026, 10, 30, 9);

    test('guarda, lista por nino y omite las repetidas', () async {
      expect(
        await repo.addAll(leo, const [
          FlashcardDraft(
            front: '¿Qué es un sustantivo?',
            back: 'Un nombre.',
            source: 'Español · pág. 1',
          ),
          FlashcardDraft(front: '¿Qué dice el adjetivo?', back: 'Cómo es algo.'),
        ], t0),
        2,
      );
      expect(
        await repo.addAll(leo, const [
          FlashcardDraft(front: '¿Qué es un sustantivo?', back: 'Otra.'),
        ], t0),
        0,
        reason: 'misma pregunta',
      );
      await repo.addAll(ana, const [
        FlashcardDraft(front: '¿Qué es un sustantivo?', back: 'Un nombre.'),
      ], t0);

      final deck = await repo.watchDeck(leo).first;
      expect(deck.map((c) => c.front), hasLength(2));
      expect(deck.any((c) => c.source == 'Español · pág. 1'), isTrue);
      expect((await repo.watchDeck(ana).first).length, 1);
    });

    test('anota los repasos y borra una tarjeta', () async {
      await repo.addAll(leo, const [FlashcardDraft(front: 'a?', back: 'b')], t0);
      final id = (await repo.watchDeck(leo).first).single.id;
      await repo.markReviewed(id, known: true, at: t0);
      await repo.markReviewed(id, known: false, at: t0);
      final card = (await repo.watchDeck(leo).first).single;
      expect((card.timesReviewed, card.timesKnown), (2, 1));
      await repo.delete(id);
      expect(await repo.watchDeck(leo).first, isEmpty);
    });

    test('borrar el perfil borra sus tarjetas (cascada)', () async {
      await repo.addAll(leo, const [FlashcardDraft(front: 'a?', back: 'b')], t0);
      await ChildProfileRepositoryImpl(db, const PinHasher(iterations: 10)).delete(leo);
      expect(await db.select(db.flashcards).get(), isEmpty);
    });

    test('la base de la version 3 se actualiza a la 4 sin perder datos', () async {
      final tmp = Directory.systemTemp.createTempSync('inocencia_flashcards_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final path = '${tmp.path}/inocencia.db';
      final old = sql.sqlite3.open(path);
      old.execute('''
        CREATE TABLE guardians (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          name TEXT NOT NULL, pin_hash TEXT NOT NULL, pin_length INTEGER NOT NULL);
        CREATE TABLE child_profiles (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          name TEXT NOT NULL, avatar TEXT NOT NULL, birth_date INTEGER NOT NULL,
          grade_override INTEGER NULL, pin_hash TEXT NULL, pin_length INTEGER NULL,
          created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)));
        INSERT INTO child_profiles (name, avatar, birth_date) VALUES ('Leo', 'emoji:🦊', 1426000000);
        PRAGMA user_version = 3;
      ''');
      old.close();
      final upgraded = AppDatabase(NativeDatabase(File(path)));
      addTearDown(upgraded.close);
      final child = (await upgraded.select(upgraded.childProfiles).get()).single;
      expect(child.name, 'Leo');
      final r = FlashcardRepositoryImpl(upgraded);
      expect(await r.addAll(child.id, const [FlashcardDraft(front: 'a?', back: 'b')], t0), 1);
    });
  });

  group('controladores', () {
    late AppDatabase db;
    late int leo;

    Future<ProviderContainer> make({
      FlashcardGenerator? generator,
      List<KnowledgeChunk> chunks = const [_chunk],
    }) async {
      db = AppDatabase(NativeDatabase.memory());
      leo = await ChildProfileRepositoryImpl(
        db,
        const PinHasher(iterations: 10),
      ).create(ChildProfileInput(name: 'Leo', avatar: 'emoji:🦊', birthDate: DateTime(2015, 3, 1)));
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tutorControllerProvider.overrideWith(() => _FakeTutor(chunks)),
          if (generator != null) flashcardGeneratorProvider.overrideWithValue(generator),
          flashcardRandomProvider.overrideWithValue(Random(1)),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 30, 9)),
        ],
      );
      addTearDown(() async {
        c.dispose();
        await db.close();
      });
      c.read(sessionProvider.notifier).selectChild(leo);
      return c;
    }

    test('generar guarda cada tarjeta segun llega y termina bien', () async {
      final gen = _FakeGenerator();
      final c = await make(generator: gen);
      c.listen(flashcardsControllerProvider, (_, _) {});
      final done = c.read(flashcardsControllerProvider.notifier).generate(grade: 2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.read(flashcardsControllerProvider).generating, isTrue);

      gen.controller.add(const FlashcardDraft(front: '¿Qué es un sustantivo?', back: 'Un nombre.'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.read(flashcardsControllerProvider).added, 1);
      expect(await FlashcardRepositoryImpl(db).watchDeck(leo).first, hasLength(1));

      gen.controller.add(
        const FlashcardDraft(front: '¿Qué dice el adjetivo?', back: 'Cómo es algo.'),
      );
      unawaited(gen.controller.close());
      await done;
      final s = c.read(flashcardsControllerProvider);
      expect((s.status, s.added), (FlashcardsGenStatus.done, 2));
    });

    test('sin tema consultado pide preguntar primero y no llama al generador', () async {
      final gen = _FakeGenerator();
      final c = await make(generator: gen, chunks: const []);
      c.listen(flashcardsControllerProvider, (_, _) {});
      await c.read(flashcardsControllerProvider.notifier).generate(grade: 2);
      final s = c.read(flashcardsControllerProvider);
      expect(s.status, FlashcardsGenStatus.failed);
      expect(s.message, FlashcardsController.needsTopic);
      expect(gen.asked, 0);
    });

    test('si el modelo no da ninguna tarjeta, avisa con amabilidad', () async {
      final gen = _FakeGenerator();
      final c = await make(generator: gen);
      c.listen(flashcardsControllerProvider, (_, _) {});
      final done = c.read(flashcardsControllerProvider.notifier).generate(grade: 2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      unawaited(gen.controller.close());
      await done;
      expect(c.read(flashcardsControllerProvider).message, FlashcardsController.unavailable);
    });

    test('un error del modelo no rompe: con tarjetas ya guardadas termina bien', () async {
      final gen = _FakeGenerator();
      final c = await make(generator: gen);
      c.listen(flashcardsControllerProvider, (_, _) {});
      final done = c.read(flashcardsControllerProvider.notifier).generate(grade: 2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gen.controller.add(const FlashcardDraft(front: 'a?', back: 'b'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gen.controller.addError(StateError('boom'));
      await done;
      expect(c.read(flashcardsControllerProvider).status, FlashcardsGenStatus.done);
    });

    group('repaso', () {
      const deck = [
        Flashcard(id: 1, front: 'a?', back: 'A'),
        Flashcard(id: 2, front: 'b?', back: 'B'),
        Flashcard(id: 3, front: 'c?', back: 'C'),
      ];

      Future<ProviderContainer> study() async {
        final c = await make();
        c.listen(studyControllerProvider, (_, _) {});
        await FlashcardRepositoryImpl(db).addAll(leo, [
          for (final d in deck) FlashcardDraft(front: d.front, back: d.back),
        ], DateTime(2026, 10, 30));
        final saved = await FlashcardRepositoryImpl(db).watchDeck(leo).first;
        c.read(studyControllerProvider.notifier).start(saved);
        return c;
      }

      test('hay que voltear antes de contestar y cada respuesta pasa a la siguiente', () async {
        final c = await study();
        final n = c.read(studyControllerProvider.notifier);
        expect(c.read(studyControllerProvider).total, 3);
        n.answer(known: true);
        expect(c.read(studyControllerProvider).queue.length, 3, reason: 'sin voltear no cuenta');
        n.flip();
        expect(c.read(studyControllerProvider).flipped, isTrue);
        n.answer(known: true);
        final s = c.read(studyControllerProvider);
        expect((s.queue.length, s.flipped, s.knownFirstTry), (2, false, 1));
      });

      test('las falladas vuelven al final, como mucho dos veces', () async {
        final c = await study();
        final n = c.read(studyControllerProvider.notifier);
        final first = c.read(studyControllerProvider).current!;
        for (var i = 0; i < 3; i++) {
          // Falla la misma tarjeta cada vez que sale; las otras las sabe.
          while (c.read(studyControllerProvider).current!.id != first.id) {
            n.flip();
            n.answer(known: true);
          }
          n.flip();
          n.answer(known: false);
        }
        final s = c.read(studyControllerProvider);
        expect(s.queue.where((q) => q.id == first.id), isEmpty, reason: 'tras 3 fallos se retira');
        expect(s.finished, isTrue);
        expect(s.knownFirstTry, 2);
      });

      test('guarda cada repaso en la base', () async {
        final c = await study();
        final n = c.read(studyControllerProvider.notifier);
        n.flip();
        n.answer(known: true);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final deckNow = await FlashcardRepositoryImpl(db).watchDeck(leo).first;
        expect(deckNow.map((d) => d.timesReviewed).reduce((a, b) => a + b), 1);
        expect(deckNow.map((d) => d.timesKnown).reduce((a, b) => a + b), 1);
      });
    });
  });
}
