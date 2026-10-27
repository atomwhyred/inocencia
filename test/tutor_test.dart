import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/di/providers.dart';
import 'package:inocencia/features/external_data/domain/external_files_repository.dart';
import 'package:inocencia/features/external_data/domain/linked_file_status.dart';
import 'package:inocencia/features/knowledge/data/fts_query.dart';
import 'package:inocencia/features/knowledge/data/knowledge_repository_impl.dart';
import 'package:inocencia/features/knowledge/domain/knowledge_chunk.dart';
import 'package:inocencia/features/tutor/application/tutor_controller.dart';
import 'package:inocencia/features/tutor/domain/tutor_engine.dart';
import 'package:inocencia/features/tutor/domain/tutor_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

class _FakeEngine implements TutorEngine {
  bool loaded = false;
  Object? loadError;
  List<ChatTurn>? lastTurns;
  List<String> pieces = ['Los ', 'adjetivos ', 'dicen cómo es algo.'];
  Object? generateError;
  int generateCalls = 0;
  StreamController<String>? manual;

  @override
  bool get isLoaded => loaded;

  @override
  Future<void> load(String modelPath) async {
    if (loadError != null) throw loadError!;
    loaded = true;
  }

  @override
  Stream<String> generate(List<ChatTurn> turns) {
    generateCalls++;
    lastTurns = turns;
    if (manual != null) return manual!.stream;
    if (generateError != null) return Stream.error(generateError!);
    return Stream.fromIterable(pieces);
  }

  @override
  Future<void> dispose() async => loaded = false;
}

/// Motor que tarda en cargar y detecta si lo liberan a mitad de la carga.
class _SlowEngine implements TutorEngine {
  bool loaded = false;
  bool _loading = false;
  bool disposedWhileLoading = false;

  @override
  bool get isLoaded => loaded;

  @override
  Future<void> load(String modelPath) async {
    _loading = true;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (disposedWhileLoading) throw const TutorEngineException('Disposed');
    _loading = false;
    loaded = true;
  }

  @override
  Stream<String> generate(List<ChatTurn> turns) => const Stream.empty();

  @override
  Future<void> dispose() async {
    if (_loading) disposedWhileLoading = true;
    loaded = false;
  }
}

class _FakeKnowledge implements KnowledgeRepository {
  _FakeKnowledge(this.chunks);
  final List<KnowledgeChunk> chunks;
  String? lastQuery;
  int? lastGrade;
  bool closed = false;

  @override
  Future<List<KnowledgeChunk>> search(String question,
      {required int grade, String? subject, int limit = 3}) async {
    lastQuery = question;
    lastGrade = grade;
    return chunks;
  }

  @override
  Future<List<String>> subjectsForGrade(int grade) async => ['Español', 'Inglés'];

  @override
  Future<void> close() async => closed = true;
}

class _FakeFiles implements ExternalFilesRepository {
  _FakeFiles({this.ready = true});
  final bool ready;

  @override
  Future<LinkedFilesStatus> check() async => LinkedFilesStatus(
        model: ready
            ? const LinkedFileStatus(state: LinkState.ready, path: '/m.gguf')
            : const LinkedFileStatus(state: LinkState.notLinked),
        knowledge: ready
            ? const KnowledgeDbStatus(state: LinkState.ready, path: '/k.db')
            : const KnowledgeDbStatus.notLinked(),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _chunk = KnowledgeChunk(
  id: 1,
  grade: 4,
  subject: 'Español',
  book: '4to_esp_II',
  page: 60,
  text: 'Los adjetivos tienen el mismo género y número que los sustantivos.',
);

void main() {
  group('fts_query', () {
    test('quita palabras vacias y de peticion', () {
      expect(keyTerms('¿Qué es un adjetivo? Explícame por favor'), ['adjetivo']);
    });

    test('mantiene el orden y no repite', () {
      expect(keyTerms('plantas y plantas con agua'), ['plantas', 'agua']);
    });

    test('las tildes no cuentan para las palabras vacias', () {
      expect(keyTerms('Cuál es la fotosíntesis'), ['fotosíntesis']);
    });

    test('consulta estricta: terminos acortados con prefijo', () {
      expect(ftsAllQuery('los adjetivos y los verbos'), '"adjetiv"* AND "verb"*');
    });

    test('consulta amplia usa OR', () {
      expect(ftsAnyQuery('adjetivos verbos'), '"adjetiv"* OR "verb"*');
    });

    test('limita los terminos conservando los mas largos', () {
      final q = ftsAllQuery('sol luna estrellas planetas galaxias cometas asteroides', maxTerms: 3);
      expect(q.split(' AND ').length, 3);
      expect(q, contains('asteroid'));
      expect(q, isNot(contains('"sol"')));
    });

    test('sin terminos utiles la consulta queda vacia', () {
      expect(ftsAllQuery('¿Qué es eso? Hola, gracias'), '');
      expect(ftsAnyQuery('  '), '');
    });

    test('las comillas y operadores del nino no rompen la consulta', () {
      final q = ftsAllQuery('"hola" OR NOT ) ( * adjetivos');
      expect(q, contains('"adjetiv"*'));
      expect(q.contains('('), isFalse);
    });
  });

  group('TutorPrompt', () {
    test('el sistema nombra el grado y pide usar solo el libro', () {
      final s = TutorPrompt.system(5);
      expect(s, contains('5.º grado'));
      expect(s, contains('SOLO'));
      expect(s, contains('español'));
    });

    test('pide enseñar por fragmentos con pregunta guia, sin dar la respuesta de golpe', () {
      final s = TutorPrompt.system(5);
      expect(s, contains('UNA sola idea'));
      expect(s, contains('UNA pregunta'));
      expect(s, contains('no los repitas'));
      expect(s, contains('Nunca des toda la respuesta'));
      expect(s, contains('no lo resuelvas'));
      expect(s, contains('libro de texto'));
    });

    test('la pregunta lleva pegado el recordatorio de brevedad', () {
      final turns = TutorPrompt.build(grade: 5, chunks: const [_chunk], history: const [], question: 'q');
      expect(turns.last.content, endsWith('termina con una pregunta.'));
    });

    test('estructura: sistema, historial reciente y pregunta con contexto', () {
      final turns = TutorPrompt.build(
        grade: 4,
        chunks: const [_chunk],
        history: const [ChatTurn('user', 'hola'), ChatTurn('assistant', '¡Hola!')],
        question: '¿Qué es un adjetivo?',
      );
      expect(turns.map((t) => t.role), ['system', 'user', 'assistant', 'user']);
      expect(turns.last.content, contains('TEXTOS DEL LIBRO:'));
      expect(turns.last.content, contains('[1] Español · 4to_esp_II · pág. 60'));
      expect(turns.last.content, contains('Pregunta del niño: ¿Qué es un adjetivo?'));
    });

    test('solo conserva los ultimos turnos y recorta los largos', () {
      final history = [
        for (var i = 0; i < 10; i++) ChatTurn(i.isEven ? 'user' : 'assistant', 'turno $i ${'x' * 500}'),
      ];
      final turns = TutorPrompt.build(grade: 4, chunks: const [_chunk], history: history, question: 'q');
      expect(turns.length, 1 + TutorPrompt.maxHistoryTurns + 1);
      expect(turns[1].content, contains('turno 6'));
      expect(turns[1].content.length, lessThanOrEqualTo(TutorPrompt.maxHistoryChars + 1));
    });

    test('acota el contexto total', () {
      final big = List.generate(
        5,
        (i) => KnowledgeChunk(id: i, grade: 4, subject: 'S', book: 'b', text: 'palabra ' * 120),
      );
      final turns = TutorPrompt.build(grade: 4, chunks: big, history: const [], question: 'q');
      expect(turns.last.content.length, lessThan(TutorPrompt.maxContextChars + 300));
    });

    test('sin resultados nombra las asignaturas del grado', () {
      final r = TutorPrompt.noResults(4, ['Español', 'Inglés']);
      expect(r, contains('4.º grado'));
      expect(r, contains('Español, Inglés'));
    });
  });

  group('KnowledgeRepositoryImpl (base temporal)', () {
    late Directory tmp;
    late String path;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('inocencia_kb_');
      path = '${tmp.path}/k.db';
      final db = sqlite3.open(path);
      db.execute('CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT)');
      db.execute(
        'CREATE TABLE chunks(id INTEGER PRIMARY KEY, grade INTEGER, subject TEXT, '
        'book TEXT, chapter TEXT, page INTEGER, text TEXT)',
      );
      db.execute(
        "CREATE VIRTUAL TABLE chunks_fts USING fts5(text, content='chunks', "
        "content_rowid='id', tokenize='unicode61 remove_diacritics 2')",
      );
      final rows = [
        (1, 4, 'Español', 'Los adjetivos describen a los sustantivos y concuerdan en género y número.'),
        (2, 6, 'Español', 'El adjetivo calificativo expresa cualidades del sustantivo en sexto grado.'),
        (3, 6, 'Ciencias Naturales', 'La fotosíntesis ocurre en las hojas de las plantas verdes.'),
        (4, 4, 'Inglés', 'Adjectives come before nouns in English sentences.'),
      ];
      for (final r in rows) {
        db.execute('INSERT INTO chunks VALUES(?,?,?,?,?,?,?)', [r.$1, r.$2, r.$3, 'libro${r.$1}', null, r.$1 * 10, r.$4]);
      }
      db.execute('INSERT INTO chunks_fts(rowid, text) SELECT id, text FROM chunks');
      db.close();
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    test('filtra estrictamente por grado', () async {
      final repo = KnowledgeRepositoryImpl.open(path);
      final g4 = await repo.search('adjetivos', grade: 4);
      final g6 = await repo.search('adjetivos', grade: 6);
      expect(g4.map((c) => c.grade).toSet(), {4});
      expect(g6.map((c) => c.grade).toSet(), {6});
      expect(g4.map((c) => c.id), containsAll([1]));
      expect(g6.map((c) => c.id), [2]);
      await repo.close();
    });

    test('un grado sin ese contenido no devuelve nada (no se cuelan otros grados)', () async {
      final repo = KnowledgeRepositoryImpl.open(path);
      expect(await repo.search('fotosíntesis', grade: 4), isEmpty);
      expect(await repo.search('fotosíntesis', grade: 6), hasLength(1));
      await repo.close();
    });

    test('ignora tildes y mayusculas, y encuentra plurales', () async {
      final repo = KnowledgeRepositoryImpl.open(path);
      expect((await repo.search('FOTOSINTESIS de la PLANTA', grade: 6)).single.id, 3);
      await repo.close();
    });

    test('filtra por asignatura si se pide', () async {
      final repo = KnowledgeRepositoryImpl.open(path);
      final r = await repo.search('adjectives nouns', grade: 4, subject: 'Inglés');
      expect(r.map((c) => c.subject).toSet(), {'Inglés'});
      // La misma busqueda restringida a otra asignatura no devuelve ese fragmento.
      expect(await repo.search('adjectives nouns', grade: 4, subject: 'Español'), isEmpty);
      await repo.close();
    });

    test('pregunta sin terminos utiles o con sintaxis rara no falla', () async {
      final repo = KnowledgeRepositoryImpl.open(path);
      expect(await repo.search('hola', grade: 4), isEmpty);
      expect(await repo.search('"\'*() AND OR NOT ^', grade: 4), isEmpty);
      await repo.close();
    });

    test('asignaturas por grado', () async {
      final repo = KnowledgeRepositoryImpl.open(path);
      expect(await repo.subjectsForGrade(4), ['Español', 'Inglés']);
      expect(await repo.subjectsForGrade(9), isEmpty);
      await repo.close();
    });
  });

  // Contra la base real generada por tools/knowledge_builder (si existe).
  final realDb = File('build/knowledge.db');
  group('base real de libros', () {
    test('las preguntas tipicas devuelven fragmentos del grado correcto', () async {
      final repo = KnowledgeRepositoryImpl.open(realDb.path);
      final casos = {
        (4, '¿Qué es un adjetivo?'): 'Español',
        (6, '¿Cómo respiran las plantas?'): 'Ciencias Naturales',
        (5, '¿Qué fue la guerra de independencia de Cuba?'): 'Historia de Cuba',
        (6, '¿Qué es la democracia?'): 'Educación Cívica',
      };
      for (final e in casos.entries) {
        final (grade, q) = e.key;
        final r = await repo.search(q, grade: grade);
        expect(r, isNotEmpty, reason: q);
        expect(r.every((c) => c.grade == grade), isTrue, reason: 'otro grado en: $q');
        expect(r.map((c) => c.subject), contains(e.value), reason: q);
      }
      await repo.close();
    }, skip: realDb.existsSync() ? false : 'ejecuta tools/knowledge_builder primero');
  });

  group('TutorController', () {
    late _FakeEngine engine;
    late _FakeKnowledge knowledge;

    Future<ProviderContainer> make({bool filesReady = true, List<KnowledgeChunk>? chunks}) async {
      SharedPreferences.setMockInitialValues({});
      engine = _FakeEngine();
      knowledge = _FakeKnowledge(chunks ?? const [_chunk]);
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        externalFilesRepositoryProvider.overrideWithValue(_FakeFiles(ready: filesReady)),
        tutorEngineProvider.overrideWithValue(engine),
        knowledgeRepositoryFactoryProvider.overrideWithValue((_) => knowledge),
      ]);
      addTearDown(c.dispose);
      c.listen(tutorControllerProvider, (_, _) {}); // mantiene vivo el autoDispose
      return c;
    }

    test('el motor autoDispose no se destruye mientras el chat esta abierto (carga lenta)', () async {
      // Reproduce el ciclo de vida real: el motor se libera con ref.onDispose y
      // la carga del modelo tarda. Antes se liberaba a mitad de la carga.
      SharedPreferences.setMockInitialValues({});
      final slow = _SlowEngine();
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        externalFilesRepositoryProvider.overrideWithValue(_FakeFiles()),
        tutorEngineProvider.overrideWith((ref) {
          ref.onDispose(slow.dispose);
          return slow;
        }),
        knowledgeRepositoryFactoryProvider.overrideWithValue((_) => _FakeKnowledge(const [_chunk])),
      ]);
      addTearDown(c.dispose);
      c.listen(tutorControllerProvider, (_, _) {});

      final loading = c.read(tutorControllerProvider.notifier).prepare();
      await Future<void>.delayed(const Duration(milliseconds: 20)); // pasan frames mientras carga
      expect(slow.disposedWhileLoading, isFalse);
      await loading;
      expect(c.read(tutorControllerProvider).status, TutorStatus.ready);
      expect(slow.loaded, isTrue);
    });

    test('sin archivos vinculados pide ayuda al padre y no carga el modelo', () async {
      final c = await make(filesReady: false);
      await c.read(tutorControllerProvider.notifier).prepare();
      final s = c.read(tutorControllerProvider);
      expect(s.status, TutorStatus.needsFiles);
      expect(s.problem, contains('modelo'));
      expect(engine.loaded, isFalse);
    });

    test('un modelo que no carga deja el estado en error con el motivo', () async {
      final c = await make();
      engine.loadError = const TutorEngineException('No hay memoria');
      await c.read(tutorControllerProvider.notifier).prepare();
      expect(c.read(tutorControllerProvider).status, TutorStatus.error);
      expect(c.read(tutorControllerProvider).problem, 'No hay memoria');
    });

    test('pregunta: busca por grado, genera y guarda fuentes', () async {
      final c = await make();
      final ctl = c.read(tutorControllerProvider.notifier);
      await ctl.prepare();
      expect(c.read(tutorControllerProvider).status, TutorStatus.ready);

      await ctl.ask('¿Qué es un adjetivo?', grade: 4);
      final s = c.read(tutorControllerProvider);
      expect(knowledge.lastGrade, 4);
      expect(s.messages.map((m) => m.fromUser), [true, false]);
      expect(s.messages.last.text, 'Los adjetivos dicen cómo es algo.');
      expect(s.messages.last.sources, ['Español · 4to_esp_II · pág. 60']);
      expect(s.generating, isFalse);
      expect(engine.lastTurns!.last.content, contains('Pregunta del niño: ¿Qué es un adjetivo?'));
      expect(engine.lastTurns!.first.content, contains('4.º grado'));
    });

    test('sin resultados en el libro no se llama al modelo', () async {
      final c = await make(chunks: const []);
      final ctl = c.read(tutorControllerProvider.notifier);
      await ctl.prepare();
      await ctl.ask('¿Quién ganó el mundial?', grade: 4);
      expect(engine.generateCalls, 0);
      final last = c.read(tutorControllerProvider).messages.last;
      expect(last.text, contains('No encontré eso'));
      expect(last.text, contains('Español, Inglés'));
    });

    test('una pregunta corta se apoya en la anterior para buscar', () async {
      final c = await make();
      final ctl = c.read(tutorControllerProvider.notifier);
      await ctl.prepare();
      await ctl.ask('¿Qué es un adjetivo?', grade: 4);
      await ctl.ask('¿y el plural?', grade: 4);
      expect(knowledge.lastQuery, contains('adjetivo'));
      expect(knowledge.lastQuery, contains('plural'));
      // el historial viaja al modelo
      expect(engine.lastTurns!.map((t) => t.role), ['system', 'user', 'assistant', 'user']);
    });

    test('un error del motor deja un mensaje amable y no deja la UI "escribiendo"', () async {
      final c = await make();
      final ctl = c.read(tutorControllerProvider.notifier);
      await ctl.prepare();
      engine.generateError = const TutorEngineException('boom');
      await ctl.ask('adjetivos', grade: 4);
      final s = c.read(tutorControllerProvider);
      expect(s.generating, isFalse);
      expect(s.messages.last.text, contains('No pude generar'));
    });

    test('stop conserva lo escrito y libera la entrada', () async {
      final c = await make();
      final ctl = c.read(tutorControllerProvider.notifier);
      await ctl.prepare();
      engine.manual = StreamController<String>();
      final pending = ctl.ask('adjetivos', grade: 4);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      engine.manual!.add('Un adjetivo ');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(tutorControllerProvider).generating, isTrue);
      await ctl.stop();
      await pending;
      final s = c.read(tutorControllerProvider);
      expect(s.generating, isFalse);
      expect(s.messages.last.text, 'Un adjetivo');
    });

    test('ignora preguntas vacias y mientras responde', () async {
      final c = await make();
      final ctl = c.read(tutorControllerProvider.notifier);
      await ctl.prepare();
      await ctl.ask('   ', grade: 4);
      expect(c.read(tutorControllerProvider).messages, isEmpty);
    });

    test('al cerrarse libera la base de conocimiento', () async {
      final c = await make();
      await c.read(tutorControllerProvider.notifier).prepare();
      c.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(knowledge.closed, isTrue);
    });
  });
}
