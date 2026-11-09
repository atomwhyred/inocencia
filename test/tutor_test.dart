import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/di/providers.dart';
import 'package:inocencia/core/security/pin_hasher.dart';
import 'package:inocencia/core/storage/app_database.dart';
import 'package:inocencia/features/auth/application/session.dart';
import 'package:inocencia/features/mascot/application/mascot_atlas.dart';
import 'package:inocencia/features/mascot/application/mascot_settings.dart';
import 'package:inocencia/features/mascot/domain/mascot_cheers.dart';
import 'package:inocencia/features/mascot/domain/mascot_mood.dart';
import 'package:inocencia/features/achievements/application/achievement_service.dart';
import 'package:inocencia/features/pomodoro/application/pomodoro.dart';
import 'package:inocencia/features/power/application/power_mode.dart';
import 'package:inocencia/features/quiz/application/quiz_controller.dart';
import 'package:inocencia/features/speech/application/speech_controller.dart';
import 'package:inocencia/features/profiles/presentation/avatar_view.dart';
import 'package:inocencia/features/mascot/presentation/mascot_view.dart';
import 'package:inocencia/features/profiles/data/child_profile_repository_impl.dart';
import 'package:inocencia/features/profiles/domain/child_profile.dart';
import 'package:inocencia/features/external_data/domain/external_files_repository.dart';
import 'package:inocencia/features/external_data/domain/linked_file_status.dart';
import 'package:inocencia/features/knowledge/data/fts_query.dart';
import 'package:inocencia/features/knowledge/data/knowledge_repository_impl.dart';
import 'package:inocencia/features/knowledge/domain/knowledge_chunk.dart';
import 'package:inocencia/features/tutor/application/tutor_controller.dart';
import 'package:inocencia/features/tutor/data/tutor_history_repository_impl.dart';
import 'package:inocencia/features/tutor/domain/tutor_engine.dart';
import 'package:inocencia/features/tutor/domain/tutor_prompt.dart';
import 'package:inocencia/features/tutor/presentation/tutor_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'speech_test.dart' show FakeSpeechService;

class _FakeEngine implements TutorEngine {
  bool loaded = false;
  Object? loadError;
  List<ChatTurn>? lastTurns;
  List<String> pieces = ['Los ', 'adjetivos ', 'dicen cómo es algo.'];
  Object? generateError;
  int generateCalls = 0;
  int? lastMaxTokens;
  bool? lastLowPower;
  int loads = 0;
  StreamController<String>? manual;

  @override
  bool get isLoaded => loaded;

  @override
  Future<void> load(String modelPath, {bool lowPower = false}) async {
    if (loadError != null) throw loadError!;
    loaded = true;
    loads++;
    lastLowPower = lowPower;
  }

  @override
  Stream<String> generate(List<ChatTurn> turns, {int? maxTokens}) {
    generateCalls++;
    lastTurns = turns;
    lastMaxTokens = maxTokens;
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
  Future<void> load(String modelPath, {bool lowPower = false}) async {
    _loading = true;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (disposedWhileLoading) throw const TutorEngineException('Disposed');
    _loading = false;
    loaded = true;
  }

  @override
  Stream<String> generate(List<ChatTurn> turns, {int? maxTokens}) => const Stream.empty();

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

    test('las formas del verbo ser no son terminos de busqueda', () {
      expect(keyTerms('¿Qué fue la guerra de independencia de Cuba?'), ['guerra', 'independencia', 'cuba']);
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

  group('cobertura de terminos', () {
    test('cuenta terminos con plural, tildes y mayusculas', () {
      final terms = looseTerms('fracciones denominador');
      expect(termCoverage('La FRACCIÓN tiene un denominador.', terms), 2);
      expect(termCoverage('Un adjetivo describe.', terms), 0);
    });

    test('exige dos tercios de los terminos (minimo)', () {
      expect(minLooseCoverage(1), 1);
      expect(minLooseCoverage(2), 2);
      expect(minLooseCoverage(3), 2);
      expect(minLooseCoverage(4), 3);
      expect(minLooseCoverage(6), 4);
    });
  });

  group('TutorPrompt', () {
    test('el sistema nombra el grado y pide usar solo el libro', () {
      final s = TutorPrompt.system(5);
      expect(s, contains('5.º grado'));
      expect(s, contains('SOLO'));
      expect(s, contains('Español'));
    });

    test('pide enseñar por fragmentos con pregunta guia, sin dar la respuesta de golpe', () {
      final s = TutorPrompt.system(5);
      expect(s, contains('UN solo paso'));
      expect(s, contains('UNA pregunta'));
      expect(s, contains('nunca "¿entiendes?"'));
      expect(s, contains('no repitas sus ejercicios'));
      expect(s, contains('Nunca des toda la respuesta de golpe'));
      expect(s, contains('no lo resuelvas'));
      expect(s, contains('libro de texto'));
    });

    test('pide no citar lo que el niño no ve (poemas, tablas, páginas)', () {
      final s = TutorPrompt.system(4);
      expect(s, contains('El niño no ve el libro'));
      expect(s, contains('"la tabla"'));
    });

    test('la pregunta lleva pegado el recordatorio de brevedad', () {
      final turns = TutorPrompt.build(grade: 5, chunks: const [_chunk], history: const [], question: 'q');
      expect(turns.last.content, endsWith('termina con una pregunta que lo haga pensar.'));
      expect(turns.last.content, contains('UN solo paso'));
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

    group('hideUnseen', () {
      test('quita lo que el niño no ve, con frases reales del modelo', () {
        expect(
          TutorPrompt.hideUnseen(
            'Un sustantivo propio es el nombre de una persona. ¿Qué ejemplos encuentras en la tabla del texto?',
          ),
          'Un sustantivo propio es el nombre de una persona. ¿Qué ejemplos encuentras?',
        );
        expect(
          TutorPrompt.hideUnseen('¿Qué oración del ejercicio te ayuda a entender mejor qué es un verbo?'),
          '¿Qué oración te ayuda a entender mejor qué es un verbo?',
        );
        expect(
          TutorPrompt.hideUnseen('¿Qué palabras en el poema podrían ser sustantivos propios?'),
          '¿Qué palabras podrían ser sustantivos propios?',
        );
        expect(
          TutorPrompt.hideUnseen('En el poema, hay cinco sustantivos propios. ¿Cuáles ves?'),
          'Hay cinco sustantivos propios. ¿Cuáles ves?',
        );
        expect(TutorPrompt.hideUnseen('¿Qué observas al ver la tabla?'), '¿Qué observas?');
        expect(
          TutorPrompt.hideUnseen('¿Qué adjetivos describen a los sustantivos en el ejemplo?'),
          '¿Qué adjetivos describen a los sustantivos?',
        );
        expect(
          TutorPrompt.hideUnseen('Mira el recuadro de la página 138. ¿Qué ves en los dibujos?'),
          'Mira el recuadro. ¿Qué ves?',
        );
      });

      test('respeta la tabla de multiplicar, tu libro y lo que no menciona nada', () {
        const a = '¿Qué observas en la tabla de multiplicar del 3?';
        expect(TutorPrompt.hideUnseen(a), a);
        const b = 'Búscalo en tu libro. ¿Qué es un verbo?';
        expect(TutorPrompt.hideUnseen(b), b);
        const c = 'Una fracción es una parte de un todo, por ejemplo 1/2. ¿Qué parte es la mitad?';
        expect(TutorPrompt.hideUnseen(c), c);
      });
    });

    group('isAnswer', () {
      const asked = [ChatTurn('user', '¿Qué es un adjetivo?'), ChatTurn('assistant', 'Dice cómo es algo. ¿Cuál es el adjetivo de "casa grande"?')];

      test('una respuesta corta a la pregunta del tutor lo es', () {
        expect(TutorPrompt.isAnswer(asked, 'grande'), isTrue);
        expect(TutorPrompt.isAnswer(asked, 'es la palabra grande'), isTrue);
        expect(TutorPrompt.isAnswer(asked, 'no sé'), isTrue);
      });

      test('una pregunta o una peticion no lo es', () {
        expect(TutorPrompt.isAnswer(asked, '¿Y el plural?'), isFalse);
        expect(TutorPrompt.isAnswer(asked, 'y el plural?'), isFalse);
        expect(TutorPrompt.isAnswer(asked, 'Cómo se escribe'), isFalse);
        expect(TutorPrompt.isAnswer(asked, 'por qué'), isFalse);
        expect(TutorPrompt.isAnswer(asked, 'Explícame otra vez'), isFalse);
        expect(TutorPrompt.isAnswer(asked, 'no entiendo'), isFalse);
        // Pedir algo no es contestar (antes salia "Casi, ¡muy bien!").
        expect(TutorPrompt.isAnswer(asked, 'Dame un ejemplo de adjetivo'), isFalse);
        expect(TutorPrompt.isAnswer(asked, 'Enséñame otra vez'), isFalse);
        expect(TutorPrompt.isAnswer(asked, 'puedes repetirlo'), isFalse);
        expect(TutorPrompt.isAnswer(asked, 'y el plural'), isFalse);
        expect(TutorPrompt.isAnswer(asked, 'Entonces los verbos'), isFalse);
      });

      test('un mensaje largo no lo es', () {
        expect(TutorPrompt.isAnswer(asked, 'quiero saber ahora mismo todo sobre las plantas y los animales del bosque'), isFalse);
      });

      test('sin historial, o si el tutor no preguntó, no lo es', () {
        expect(TutorPrompt.isAnswer(const [], 'grande'), isFalse);
        expect(TutorPrompt.isAnswer(const [ChatTurn('user', 'hola'), ChatTurn('assistant', 'Hola, soy tu tutor.')], 'grande'), isFalse);
        expect(TutorPrompt.isAnswer(const [ChatTurn('user', 'hola')], 'grande'), isFalse);
      });
    });

    test('si el niño contesta, el mensaje lo marca y pide valorar primero', () {
      final turns = TutorPrompt.build(
        grade: 4,
        chunks: const [_chunk],
        history: const [ChatTurn('assistant', '¿Cuál es el adjetivo?')],
        question: 'grande',
        answering: true,
      );
      expect(turns.last.content, contains('Respuesta del niño a tu pregunta: grande'));
      expect(turns.last.content, isNot(contains('Pregunta del niño')));
      expect(turns.last.content, contains('Valora su respuesta con cariño'));
      expect(turns.last.content, contains('UNA sola pregunta'));
    });

    test('"no sé" pide una pista en vez de valorar', () {
      for (final text in ['no sé', 'No se', 'no lo sé', 'ni idea']) {
        final turns = TutorPrompt.build(
          grade: 4,
          chunks: const [_chunk],
          history: const [ChatTurn('assistant', '¿Cuál es el adjetivo?')],
          question: text,
          answering: true,
        );
        expect(turns.last.content, contains('El niño no sabe'), reason: text);
        expect(turns.last.content, isNot(contains('Valora su respuesta')), reason: text);
      }
    });

    test('endOfFirstQuestion corta justo tras la primera pregunta', () {
      expect(TutorPrompt.endOfFirstQuestion('Muy bien. ¿Qué más? ¿Y esto?'), 'Muy bien. ¿Qué más?'.length);
      expect(TutorPrompt.endOfFirstQuestion('Aun sin pregunta'), -1);
    });

    group('lastQuestion', () {
      test('devuelve la pregunta con la que acaba el mensaje', () {
        expect(
          TutorPrompt.lastQuestion('Dice cómo es algo. ¿Cuál es el adjetivo de "casa grande"?'),
          '¿Cuál es el adjetivo de "casa grande"?',
        );
        expect(TutorPrompt.lastQuestion('¿Qué es un adjetivo?'), '¿Qué es un adjetivo?');
      });

      test('con varias preguntas, la última', () {
        expect(TutorPrompt.lastQuestion('¿Lo viste? Piénsalo. ¿Cuántas hojas tiene?'), '¿Cuántas hojas tiene?');
        expect(TutorPrompt.lastQuestion('¿Lo viste? ¿Y el tallo?'), '¿Y el tallo?');
      });

      test('si el modelo olvidó el ¿, corta en el último límite de frase', () {
        expect(
          TutorPrompt.lastQuestion('Las hojas son verdes. Qué partes tienen clorofila?'),
          'Qué partes tienen clorofila?',
        );
        expect(TutorPrompt.lastQuestion('Qué es un verbo?'), 'Qué es un verbo?');
      });

      test('un ¿ de una pregunta anterior no se arrastra', () {
        expect(TutorPrompt.lastQuestion('¿Lo viste? Dime cuál es?'), 'Dime cuál es?');
      });

      test('sin pregunta final no hay botón', () {
        expect(TutorPrompt.lastQuestion('Los adjetivos dicen cómo es algo.'), isNull);
        expect(TutorPrompt.lastQuestion('¿Lo viste? Pues ya lo sabes.'), isNull);
        expect(TutorPrompt.lastQuestion(''), isNull);
        expect(TutorPrompt.lastQuestion('?'), isNull);
      });

      test('admite comillas o espacios tras el signo de cierre', () {
        expect(TutorPrompt.lastQuestion('Piensa: "¿Qué es un verbo?" '), '¿Qué es un verbo?');
      });
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

    test('una palabra suelta de la pregunta no basta para colar otra asignatura', () async {
      final repo = KnowledgeRepositoryImpl.open(path);
      // Hay libro de Español y Ciencias en 6.º, pero ninguno de Matematica:
      // "sumo" o "distinto" no deben traer paginas ajenas.
      expect(await repo.search('como sumo fracciones con distinto denominador', grade: 6), isEmpty);
      await repo.close();
    });

    test('el rescate amplio sigue valiendo si falla solo una palabra', () async {
      final repo = KnowledgeRepositoryImpl.open(path);
      // "verdes" no esta junto a "plantas" y "hojas" en la pregunta: AND falla
      // por la palabra extra "gigantes", pero 3 de 4 terminos cubren el fragmento.
      final r = await repo.search('fotosintesis plantas hojas gigantes', grade: 6);
      expect(r.map((c) => c.id), [3]);
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
        (6, '¿Cómo sumo fracciones con distinto denominador?'): 'Matemática',
        (4, '¿Cómo se multiplican números de dos cifras?'): 'Matemática',
        (6, '¿Qué es internet?'): 'Mundo Digital',
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

    test('un tema que no esta en los libros del grado no devuelve paginas ajenas', () async {
      final repo = KnowledgeRepositoryImpl.open(realDb.path);
      // Ni el temario de 6.º ni sus palabras sueltas ("distinto", "sumo"...) deben
      // colar paginas de otra asignatura: el modelo acabaria inventando.
      expect(await repo.search('ecuacion cuadratica discriminante', grade: 6), isEmpty);
      expect(await repo.search('teorema de pitagoras hipotenusa', grade: 6), isEmpty);
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
      expect(s.messages.last.sources.map((x) => x.label), ['Español · 4to_esp_II · pág. 60']);
      expect(s.messages.last.sources.single.page, 60);
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

    test('si el niño contesta al tutor, se valora la respuesta y se busca con la pregunta anterior', () async {
      final c = await make();
      final ctl = c.read(tutorControllerProvider.notifier);
      await ctl.prepare();
      engine.pieces = ['Dice cómo es algo. ', '¿Cuál es el adjetivo de "casa grande"?'];
      await ctl.ask('¿Qué es un adjetivo?', grade: 4);
      expect(engine.lastTurns!.last.content, contains('Pregunta del niño'));

      await ctl.ask('la casa y el grande', grade: 4);
      expect(engine.lastTurns!.last.content, contains('Respuesta del niño a tu pregunta: la casa y el grande'));
      expect(knowledge.lastQuery, contains('adjetivo'));

      // una pregunta nueva en mitad de la conversación sigue siendo una pregunta
      await ctl.ask('¿Y el plural?', grade: 4);
      expect(engine.lastTurns!.last.content, contains('Pregunta del niño: ¿Y el plural?'));
    });

    test('una pregunta completa con un solo termino clave se busca sola', () async {
      final c = await make();
      final ctl = c.read(tutorControllerProvider.notifier);
      await ctl.prepare();
      await ctl.ask('¿Qué es un adjetivo?', grade: 4);
      await ctl.ask('Que es un sustantivo', grade: 4);
      expect(knowledge.lastQuery, 'Que es un sustantivo');
    });

    test('la respuesta se corta tras la primera pregunta', () async {
      final c = await make();
      final ctl = c.read(tutorControllerProvider.notifier);
      await ctl.prepare();
      engine.pieces = ['Muy bien. ', '¿Qué más? ', '¿Y esto? ', 'Pregunta: ¿otra?'];
      await ctl.ask('adjetivos', grade: 4);
      final s = c.read(tutorControllerProvider);
      expect(s.messages.last.text, 'Muy bien. ¿Qué más?');
      expect(s.generating, isFalse);
    });

    test('varias respuestas seguidas se anclan a la pregunta original', () async {
      final c = await make();
      final ctl = c.read(tutorControllerProvider.notifier);
      await ctl.prepare();
      engine.pieces = ['Pista. ', '¿Cuál es el adjetivo?'];
      await ctl.ask('¿Qué es un adjetivo?', grade: 4);
      await ctl.ask('no se', grade: 4);
      await ctl.ask('grande', grade: 4);
      expect(knowledge.lastQuery, contains('adjetivo'));
      expect(knowledge.lastQuery, contains('grande'));
      expect(engine.lastTurns!.last.content, contains('Respuesta del niño a tu pregunta: grande'));
    });

    test('con answering se trata como respuesta aunque no lo parezca', () async {
      final c = await make();
      final ctl = c.read(tutorControllerProvider.notifier);
      await ctl.prepare();
      engine.pieces = ['Dice cómo es algo. ', '¿Cuál es el adjetivo?'];
      await ctl.ask('¿Qué es un adjetivo?', grade: 4);
      const long = 'creo que es la palabra grande porque dice cómo es la casa, ¿o me equivoco con la otra?';
      // Sin la marca, una frase con "?" se toma por una pregunta nueva.
      await ctl.ask(long, grade: 4);
      expect(engine.lastTurns!.last.content, contains('Pregunta del niño: $long'));

      await ctl.ask(long, grade: 4, answering: true);
      expect(engine.lastTurns!.last.content, contains('Respuesta del niño a tu pregunta: $long'));
      expect(engine.lastTurns!.last.content, contains('Valora su respuesta'));
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

    test('una respuesta detenida sin texto no viaja al modelo en el historial', () async {
      final c = await make();
      final ctl = c.read(tutorControllerProvider.notifier);
      await ctl.prepare();
      engine.manual = StreamController<String>();
      final pending = ctl.ask('adjetivos', grade: 4);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await ctl.stop();
      await pending;
      expect(c.read(tutorControllerProvider).messages.last.text, '…');

      engine.manual = null;
      await ctl.ask('sustantivos', grade: 4);
      expect(engine.lastTurns!.any((t) => t.content == '…'), isFalse);
      expect(engine.lastTurns!.map((t) => t.role), ['system', 'user', 'user']);
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

  group('TutorController con la conversación guardada', () {
    late AppDatabase db;
    late int leo;
    late int ana;
    late _FakeEngine engine;
    late _FakeKnowledge knowledge;

    Future<int> newChild(String name) =>
        ChildProfileRepositoryImpl(db, const PinHasher(iterations: 10)).create(
          ChildProfileInput(name: name, avatar: 'emoji:🦊', birthDate: DateTime(2015, 3, 1)),
        );

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      leo = await newChild('Leo');
      ana = await newChild('Ana');
    });
    tearDown(() => db.close());

    /// Abre el chat de [childId] como lo haria la app: con sesion y base de datos.
    Future<ProviderContainer> open(int childId) async {
      SharedPreferences.setMockInitialValues({});
      engine = _FakeEngine();
      knowledge = _FakeKnowledge(const [_chunk]);
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        appDatabaseProvider.overrideWithValue(db),
        externalFilesRepositoryProvider.overrideWithValue(_FakeFiles()),
        tutorEngineProvider.overrideWithValue(engine),
        knowledgeRepositoryFactoryProvider.overrideWithValue((_) => knowledge),
      ]);
      addTearDown(c.dispose);
      c.read(sessionProvider.notifier).selectChild(childId);
      c.listen(tutorControllerProvider, (_, _) {});
      await c.read(tutorControllerProvider.notifier).prepare();
      return c;
    }

    /// Lo guardado del niño, como "N:texto" (niño) y "T:texto" (tutor). Deja
    /// terminar antes las escrituras encadenadas.
    Future<List<String>> saved(int childId) async {
      await pumpEventQueue();
      final stored = await TutorHistoryRepositoryImpl(db).load(childId);
      return [for (final m in stored) '${m.fromUser ? 'N' : 'T'}:${m.text}'];
    }

    test('guarda la pregunta y la respuesta con sus fuentes', () async {
      final c = await open(leo);
      engine.pieces = ['Dice cómo es algo. ', '¿Un ejemplo?'];
      await c.read(tutorControllerProvider.notifier).ask('¿Qué es un adjetivo?', grade: 4);
      expect(await saved(leo), ['N:¿Qué es un adjetivo?', 'T:Dice cómo es algo. ¿Un ejemplo?']);
      final stored = await TutorHistoryRepositoryImpl(db).load(leo);
      expect(stored.last.sources.single.label, 'Español · 4to_esp_II · pág. 60');
      expect(stored.last.sources.single.page, 60);
    });

    test('al volver a abrir el chat recupera la conversación y se sigue desde ahí', () async {
      var c = await open(leo);
      engine.pieces = ['Dice cómo es algo. ', '¿Cuál es el adjetivo de "casa grande"?'];
      await c.read(tutorControllerProvider.notifier).ask('¿Qué es un adjetivo?', grade: 4);
      await pumpEventQueue();
      c.dispose();

      c = await open(leo);
      final msgs = c.read(tutorControllerProvider).messages;
      expect(msgs.map((m) => m.fromUser), [true, false]);
      expect(msgs.last.text, 'Dice cómo es algo. ¿Cuál es el adjetivo de "casa grande"?');
      expect(msgs.last.sources, isNotEmpty);
      expect(msgs.every((m) => !m.streaming), isTrue);

      // Contesta a la pregunta que quedó pendiente: el tutor lo ve como respuesta.
      await c.read(tutorControllerProvider.notifier).ask('grande', grade: 4);
      expect(engine.lastTurns!.map((t) => t.role), ['system', 'user', 'assistant', 'user']);
      expect(engine.lastTurns!.last.content, contains('Respuesta del niño a tu pregunta: grande'));
    });

    test('cada niño recupera solo su conversación', () async {
      var c = await open(leo);
      await c.read(tutorControllerProvider.notifier).ask('¿Qué es un adjetivo?', grade: 4);
      await pumpEventQueue();
      c.dispose();

      c = await open(ana);
      expect(c.read(tutorControllerProvider).messages, isEmpty);
    });

    test('un aviso de error o una respuesta detenida sin texto no se guardan', () async {
      final c = await open(leo);
      final ctl = c.read(tutorControllerProvider.notifier);
      engine.generateError = const TutorEngineException('boom');
      await ctl.ask('adjetivos', grade: 4);
      expect(c.read(tutorControllerProvider).messages.last.text, contains('No pude generar'));

      engine.generateError = null;
      engine.manual = StreamController<String>();
      final pending = ctl.ask('sustantivos', grade: 4);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await ctl.stop();
      await pending;
      expect(c.read(tutorControllerProvider).messages.last.text, '…');

      expect(await saved(leo), ['N:adjetivos', 'N:sustantivos']);
    });

    test('una respuesta detenida con texto parcial sí se guarda', () async {
      final c = await open(leo);
      final ctl = c.read(tutorControllerProvider.notifier);
      engine.manual = StreamController<String>();
      final pending = ctl.ask('adjetivos', grade: 4);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      engine.manual!.add('Un adjetivo ');
      await Future<void>.delayed(Duration.zero);
      await ctl.stop();
      await pending;
      expect(await saved(leo), ['N:adjetivos', 'T:Un adjetivo']);
    });

    test('si la base falla, se sigue conversando sin guardar', () async {
      final c = await open(leo);
      await db.close();
      await c.read(tutorControllerProvider.notifier).ask('¿Qué es un adjetivo?', grade: 4);
      final last = c.read(tutorControllerProvider).messages.last;
      expect(last.text, 'Los adjetivos dicen cómo es algo.');
      expect(last.streaming, isFalse);
    });
  });


  group('TutorPage: la pregunta del tutor como botón', () {
    late AppDatabase db;
    late _FakeEngine engine;

    Future<ProviderContainer> openPage(
      WidgetTester tester, {
      DateTime Function()? clock,
      Map<String, Object> prefs = const {},
      bool lowBattery = false,
    }) async {
      tester.view.physicalSize = const Size(500, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(prefs);
      db = AppDatabase(NativeDatabase.memory());
      final leo = await ChildProfileRepositoryImpl(db, const PinHasher(iterations: 10)).create(
        ChildProfileInput(name: 'Leo', avatar: 'emoji:🦊', birthDate: DateTime(2015, 3, 1)),
      );
      engine = _FakeEngine()..pieces = ['Dice cómo es algo. ', '¿Cuál es el adjetivo de "casa grande"?'];
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        appDatabaseProvider.overrideWithValue(db),
        externalFilesRepositoryProvider.overrideWithValue(_FakeFiles()),
        tutorEngineProvider.overrideWithValue(engine),
        knowledgeRepositoryFactoryProvider.overrideWithValue((_) => _FakeKnowledge(const [_chunk])),
        // Toco sin animacion (pumpAndSettle no terminaria) y sin leer sus capas del disco.
        mascotAnimateProvider.overrideWithValue(false),
        mascotAtlasProvider.overrideWith((ref) async => null),
        // Sin Timer periodico: las pruebas del Pomodoro avanzan el reloj a mano.
        pomodoroTickProvider.overrideWithValue(null),
        speechServiceProvider.overrideWithValue(FakeSpeechService()),
        if (clock != null) clockProvider.overrideWithValue(clock),
        if (lowBattery) lowBatterySuggestionProvider.overrideWithValue(true),
        batteryPollProvider.overrideWithValue(null),
      ]);
      c.read(sessionProvider.notifier).selectChild(leo);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        await tester.runAsync(db.close);
      });
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: TutorPage()),
      ));
      await tester.pumpAndSettle();
      return c;
    }

    Future<void> send(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
    }

    final questionButton = find.widgetWithText(FilledButton, '¿Cuál es el adjetivo de "casa grande"?');

    testWidgets('la pregunta aparece como botón bajo la última respuesta; tocarla prepara la respuesta',
        (tester) async {
      await openPage(tester);
      expect(questionButton, findsNothing);
      await send(tester, '¿Qué es un adjetivo?');

      expect(questionButton, findsOneWidget);
      expect(find.textContaining('Respondiendo a:'), findsNothing);

      await tester.tap(questionButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('Respondiendo a:'), findsOneWidget);
      expect(find.text('Escribe tu respuesta…'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isTrue);
      // Tocarla no envia nada: solo se ha preguntado una vez.
      expect(engine.generateCalls, 1);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.textContaining('Respondiendo a:'), findsNothing);
      expect(find.text('Escribe tu pregunta…'), findsOneWidget);
    });

    testWidgets('lo que se escribe tras tocarla viaja como respuesta y el banner se quita', (tester) async {
      await openPage(tester);
      await send(tester, '¿Qué es un adjetivo?');
      await tester.tap(questionButton);
      await tester.pumpAndSettle();

      const answer = 'creo que es grande, ¿o es casa?';
      await send(tester, answer);

      expect(engine.generateCalls, 2);
      expect(engine.lastTurns!.last.content, contains('Respuesta del niño a tu pregunta: $answer'));
      expect(find.textContaining('Respondiendo a:'), findsNothing);
      // Solo la última respuesta del tutor ofrece su botón.
      expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
    });

    testWidgets('sin pregunta al final no hay botón', (tester) async {
      await openPage(tester);
      engine.pieces = ['Los adjetivos dicen cómo es algo.'];
      await send(tester, '¿Qué es un adjetivo?');
      expect(find.byIcon(Icons.touch_app_rounded), findsNothing);
    });

    group('lectura en voz alta', () {
      testWidgets('solo las respuestas del tutor traen altavoz; tocarlo lee y se puede parar',
          (tester) async {
        await openPage(tester);
        await send(tester, '¿Qué es un adjetivo?');
        // Una burbuja del niño y otra del tutor: un solo altavoz.
        expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.volume_up_rounded));
        await tester.pump();
        await tester.pump();
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
        expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.stop_rounded));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
        expect(find.byIcon(Icons.stop_rounded), findsNothing);
      });

      testWidgets('si el padre lo apaga no hay altavoz', (tester) async {
        final c = await openPage(tester);
        await c.read(speechEnabledProvider.notifier).set(false);
        await send(tester, '¿Qué es un adjetivo?');
        expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
      });

      testWidgets('enviar una pregunta nueva calla la lectura', (tester) async {
        final c = await openPage(tester);
        await send(tester, '¿Qué es un adjetivo?');
        await tester.tap(find.byIcon(Icons.volume_up_rounded));
        await tester.pump();
        expect(c.read(speechProvider).status.name, 'speaking');
        await send(tester, 'otra cosa');
        expect(c.read(speechProvider).status.name, 'idle');
      });
    });

    group('Quiz', () {
      const quiz = '''
P1: ¿Qué tienen el mismo género y número que los sustantivos?
A) Los adjetivos
B) Los verbos
C) Las sumas
RESPUESTA: A
P2: ¿Con qué concuerdan los adjetivos?
A) los relojes
B) los sustantivos
C) las nubes
RESPUESTA: B
P3: ¿Qué comparten el adjetivo y el sustantivo?
A) el color
B) la rima
C) el mismo género y número
RESPUESTA: C
''';

      final quizButton = find.byTooltip('Hacer un quiz');

      Future<void> openQuiz(WidgetTester tester) async {
        await tester.tap(quizButton);
        await tester.pumpAndSettle();
      }

      testWidgets('el botón solo se activa cuando ya hay un tema del libro', (tester) async {
        await openPage(tester);
        expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.quiz_rounded)).onPressed, isNull);
        await send(tester, '¿Qué es un adjetivo?');
        expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.quiz_rounded)).onPressed, isNotNull);
      });

      testWidgets('3 preguntas, respuesta inmediata, resultado, estrellas y medallas', (tester) async {
        final c = await openPage(tester);
        await send(tester, '¿Qué es un adjetivo?');
        engine.pieces = [quiz];
        await openQuiz(tester);

        expect(engine.lastMaxTokens, 420);
        expect(find.text('Pregunta 1 de 3'), findsOneWidget);
        expect(find.text('¿Qué tienen el mismo género y número que los sustantivos?'), findsOneWidget);

        await tester.tap(find.text('Los adjetivos'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Ganaste una estrella'), findsOneWidget);
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();

        // Falla a posta: ve cual era la correcta, sin castigo.
        expect(find.text('Pregunta 2 de 3'), findsOneWidget);
        await tester.tap(find.text('los relojes'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Casi. La respuesta correcta era la'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
        expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
        // Ya contesto: tocar otra opcion no cambia nada.
        await tester.tap(find.text('los sustantivos'));
        await tester.pumpAndSettle();
        expect(c.read(quizControllerProvider).correct, 1);
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('el mismo género y número'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver mi resultado'));
        await tester.pump();
        await tester.pump();
        expect(find.text('Acertaste 2 de 3'), findsOneWidget);
        expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));

        // Medallas y estrellas quedan guardadas.
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        final progress = await tester.runAsync(
          () => c.read(achievementRepositoryProvider).watch(c.read(sessionProvider).activeChildId!).first,
        );
        expect(progress!.stars, 2);
        expect(progress.earned.keys, containsAll(['first_topic', 'first_quiz']));
        expect(progress.earned.keys, isNot(contains('perfect_quiz')));

        await tester.tap(find.text('Volver al chat'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('si el modelo escribe mal el quiz se reintenta una vez y luego avisa con cariño',
          (tester) async {
        await openPage(tester);
        await send(tester, '¿Qué es un adjetivo?');
        engine.pieces = ['No sé qué preguntar.'];
        final before = engine.generateCalls;
        await openQuiz(tester);

        expect(engine.generateCalls - before, 2);
        expect(find.text(QuizController.unavailable), findsOneWidget);
        await tester.tap(find.text('Volver al chat'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('cada pregunta aparece en cuanto está lista y se espera por la siguiente', (tester) async {
        final c = await openPage(tester);
        await send(tester, '¿Qué es un adjetivo?');
        final live = StreamController<String>();
        engine.manual = live;
        await tester.tap(find.byIcon(Icons.quiz_rounded));
        await tester.pump();
        await tester.pump();
        expect(find.text('Toco está preparando tu quiz…'), findsOneWidget);

        // Solo la primera pregunta: ya se puede contestar sin esperar al resto.
        live.add('P1: ¿Qué tienen el mismo género y número que los sustantivos?\nA) Los adjetivos\nB) Los verbos\n'
            'C) Las sumas\nRESPUESTA: A\nP2: ¿Con qué concuerdan los adjetivos?\nA) los relojes');
        await tester.pump();
        await tester.pump();
        expect(find.text('Pregunta 1 de 1'), findsOneWidget);
        await tester.tap(find.text('Los adjetivos'));
        await tester.pump();
        await tester.tap(find.text('Siguiente'));
        await tester.pump();
        expect(find.text('Toco está escribiendo la siguiente pregunta…'), findsOneWidget);

        // Llegan las otras dos: sigue solo con la segunda y el modelo se para al tener 3.
        live.add('\nB) los sustantivos\nC) las nubes\nRESPUESTA: B\nP3: ¿Qué comparten el adjetivo y el sustantivo?\nA) el color\n'
            'B) la rima\nC) el mismo género y número\nRESPUESTA: C\n');
        await tester.pump();
        await tester.pump();
        expect(find.text('Pregunta 2 de 3'), findsOneWidget);
        expect(c.read(quizControllerProvider).expecting, isFalse);
        expect(live.hasListener, isFalse, reason: 'con 3 preguntas se deja de generar');
        unawaited(live.close());
      });

      testWidgets('si el modelo se corta tras la primera, el quiz acaba con esa pregunta', (tester) async {
        final c = await openPage(tester);
        await send(tester, '¿Qué es un adjetivo?');
        engine.pieces = [
          'P1: ¿Qué tienen el mismo género y número que los sustantivos?\nA) Los adjetivos\nB) Los verbos\n'
              'C) Las sumas\nRESPUESTA: A',
        ];
        await openQuiz(tester);
        expect(find.text('Pregunta 1 de 1'), findsOneWidget);
        await tester.tap(find.text('Los adjetivos'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver mi resultado'));
        await tester.pump();
        await tester.pump();
        expect(find.text('Acertaste 1 de 1'), findsOneWidget);
        expect(c.read(quizControllerProvider).status, QuizStatus.finished);
      });

      testWidgets('un quiz a medias se puede cerrar con la X', (tester) async {
        await openPage(tester);
        await send(tester, '¿Qué es un adjetivo?');
        engine.pieces = [quiz];
        await openQuiz(tester);
        await tester.tap(find.byTooltip('Cerrar el quiz'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
      });
    });

    group('modo batería / apagón', () {
      testWidgets('cambiar el modo recarga el modelo con menos consumo, sin perder la conversación',
          (tester) async {
        final c = await openPage(tester);
        await send(tester, '¿Qué es un adjetivo?');
        expect(engine.loads, 1);
        expect(engine.lastLowPower, isFalse);

        await c.read(batterySaverProvider.notifier).set(true);
        await tester.pumpAndSettle();
        expect(engine.loads, 2);
        expect(engine.lastLowPower, isTrue);
        expect(find.text('¿Qué es un adjetivo?'), findsOneWidget);
        // Sigue contestando tras la recarga.
        await send(tester, 'otra cosa');
        expect(engine.generateCalls, 2);

        await c.read(batterySaverProvider.notifier).set(false);
        await tester.pumpAndSettle();
        expect(engine.loads, 3);
        expect(engine.lastLowPower, isFalse);
      });

      testWidgets('con poca batería Toco lo dice como un mensaje, con los botones debajo', (tester) async {
        final c = await openPage(tester, lowBattery: true);
        final text = tester.getRect(find.text('Queda poca batería. ¿Ahorramos energía?'));
        expect(tester.getRect(find.text('Ahorrar')).top, greaterThan(text.bottom));
        // Encima de la barra de escribir.
        expect(text.bottom, lessThan(tester.getRect(find.byType(TextField)).top));
        await tester.tap(find.text('Ahorrar'));
        await tester.pumpAndSettle();
        expect(c.read(batterySaverProvider), isTrue);
      });

      testWidgets('si el tutor está contestando, la recarga espera a que acabe', (tester) async {
        final c = await openPage(tester);
        final live = StreamController<String>();
        engine.manual = live;
        await tester.enterText(find.byType(TextField), '¿Qué es un adjetivo?');
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pump();
        await tester.pump();
        await c.read(batterySaverProvider.notifier).set(true);
        await tester.pump();
        expect(engine.loads, 1, reason: 'no se recarga a media respuesta');

        live.add('Los adjetivos dicen cómo es algo. ¿Cuál es uno?');
        await tester.pumpAndSettle();
        expect(engine.loads, 2);
        expect(engine.lastLowPower, isTrue);
        unawaited(live.close());
      });

      testWidgets('arrancar con el modo ya activo carga el modelo en modo ligero', (tester) async {
        final c = await openPage(tester, prefs: {'battery_saver': true});
        expect(c.read(batterySaverProvider), isTrue);
        expect(engine.lastLowPower, isTrue);
      });
    });

    group('Pomodoro infantil', () {
      late DateTime now;

      Future<ProviderContainer> open(WidgetTester tester) async {
        // Leo nacio en 2015: 5.º grado, 20 + 5 minutos.
        now = DateTime(2026, 10, 29, 9);
        return openPage(tester, clock: () => now);
      }

      Future<void> studyFor(WidgetTester tester, ProviderContainer c, Duration d) async {
        final plan = PomodoroPlan.forGrade(5);
        for (var i = 0; i < d.inSeconds; i += 5) {
          now = now.add(const Duration(seconds: 5));
          c.read(pomodoroProvider.notifier).tick(plan);
        }
        await tester.pumpAndSettle();
      }

      testWidgets('al acabar el estudio el chat se congela y Toco pasa al centro con la cuenta atrás',
          (tester) async {
        final c = await open(tester);
        expect(find.byType(TextField), findsOneWidget);
        await studyFor(tester, c, const Duration(minutes: 20));

        expect(find.byType(TextField), findsNothing);
        expect(find.textContaining('hora de descansar'), findsOneWidget);
        expect(find.text('05:00'), findsOneWidget);
        expect(find.text('¡Listo, sigamos!'), findsNothing);
        final screen = tester.view.physicalSize;
        final toco = tester.getCenter(find.byType(MascotView));
        expect(toco.dx, closeTo(screen.width / 2, 1));
        expect(toco.dy, greaterThan(screen.height * 0.25));

        // Congelado: preguntar no hace nada.
        await c.read(tutorControllerProvider.notifier).ask('hola', grade: 5);
        expect(engine.generateCalls, 0);

        // Tocar a Toco antes de tiempo no devuelve al chat.
        await tester.tap(find.byType(MascotView));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
      });

      testWidgets('solo el mensaje de Toco, al acabar el descanso, devuelve al chat', (tester) async {
        final c = await open(tester);
        await studyFor(tester, c, const Duration(minutes: 20));
        now = now.add(const Duration(minutes: 5));
        c.read(pomodoroProvider.notifier).tick(PomodoroPlan.forGrade(5));
        await tester.pumpAndSettle();

        expect(find.text('¡Descansaste muy bien!'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.text('¡Listo, sigamos!'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        await send(tester, '¿Qué es un adjetivo?');
        expect(engine.generateCalls, 1);
      });

      testWidgets('tocar a Toco al acabar el descanso también vuelve', (tester) async {
        final c = await open(tester);
        await studyFor(tester, c, const Duration(minutes: 20));
        now = now.add(const Duration(minutes: 5));
        c.read(pomodoroProvider.notifier).tick(PomodoroPlan.forGrade(5));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(MascotView));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('si el padre lo apaga, el chat no se congela', (tester) async {
        final c = await open(tester);
        await c.read(pomodoroEnabledProvider.notifier).set(false);
        await studyFor(tester, c, const Duration(minutes: 30));
        expect(find.byType(TextField), findsOneWidget);
        expect(find.textContaining('hora de descansar'), findsNothing);
      });
    });

    group('Toco, la mascota', () {
      MascotView toco(WidgetTester tester) => tester.widget<MascotView>(find.byType(MascotView));

      testWidgets('vive en la barra superior, pequeño, con el chat vacío y con mensajes', (tester) async {
        await openPage(tester);
        final inBar = find.descendant(of: find.byType(AppBar), matching: find.byType(MascotView));
        expect(inBar, findsOneWidget);
        expect(toco(tester).size, MascotSize.small);
        expect(find.textContaining('Soy Toco'), findsOneWidget);

        await send(tester, '¿Qué es un adjetivo?');
        expect(inBar, findsOneWidget);
        expect(find.byType(MascotView), findsOneWidget);
        expect(toco(tester).size, MascotSize.small);
      });

      testWidgets('su ánimo sigue al chat: espera, habla y se alegra si el niño acierta', (tester) async {
        await openPage(tester);
        expect(toco(tester).mood.activity, MascotActivity.idle);
        await send(tester, '¿Qué es un adjetivo?');
        expect(toco(tester).mood, const MascotMood(MascotActivity.idle));

        // Al tocar la pregunta del tutor, Toco escucha.
        await tester.tap(questionButton);
        await tester.pumpAndSettle();
        expect(toco(tester).mood.activity, MascotActivity.listening);

        engine.pieces = ['¡Muy bien! ', 'Ahora dime: ¿y el plural?'];
        await send(tester, 'grande');
        expect(toco(tester).mood, const MascotMood(MascotActivity.idle, MascotEmotion.happy));
      });

      testWidgets('arriba al centro, sin avatar y con el aviso de internet solo como icono', (tester) async {
        await openPage(tester);
        expect(find.byType(AvatarView), findsNothing);
        expect(find.text('Sin internet'), findsNothing);
        expect(find.bySemanticsLabel('Funciona sin internet, en este dispositivo'), findsOneWidget);
        final screen = tester.view.physicalSize.width;
        expect(tester.getCenter(find.byType(MascotView)).dx, closeTo(screen / 2, 1));
        expect(tester.getCenter(find.byIcon(Icons.wifi_off_rounded)).dx, greaterThan(screen * 0.8));
      });

      testWidgets('al tocarlo se alegra, anima con un juego y el mensaje se va solo', (tester) async {
        await openPage(tester);
        await tester.tap(find.byType(MascotView));
        await tester.pump();
        expect(find.textContaining('jug'), findsOneWidget);
        expect(toco(tester).mood, const MascotMood(MascotActivity.idle, MascotEmotion.happy));

        await tester.pumpAndSettle();
        expect(find.textContaining('jug'), findsNothing);
        expect(toco(tester).mood, const MascotMood(MascotActivity.idle));

        // Cada toque dice algo distinto.
        await tester.tap(find.byType(MascotView));
        await tester.pump();
        final first = mascotCheer(0);
        expect(find.text(first), findsNothing);
        expect(find.text(mascotCheer(1)), findsOneWidget);
        await tester.pumpAndSettle();
      });

      testWidgets('el padre puede apagarla: no queda rastro de Toco', (tester) async {
        final c = await openPage(tester);
        await c.read(mascotEnabledProvider.notifier).set(false);
        await tester.pumpAndSettle();
        expect(find.byType(MascotView), findsNothing);
        // El chat sigue funcionando.
        await send(tester, '¿Qué es un adjetivo?');
        expect(questionButton, findsOneWidget);
      });

      testWidgets('la ultima respuesta con libro ofrece crear tarjetas; una sola vez', (tester) async {
        await openPage(tester);
        expect(find.text('Crear tarjetas'), findsNothing, reason: 'aun no hay respuesta');
        await send(tester, '¿Qué es un adjetivo?');
        expect(find.text('Crear tarjetas'), findsOneWidget);
        await send(tester, '¿Y el verbo?');
        expect(find.text('Crear tarjetas'), findsOneWidget, reason: 'solo en la ultima respuesta');
      });

      testWidgets('sin nombre ni grado, y Toco cabe en la barra (50 dp)', (tester) async {
        await openPage(tester);
        expect(find.text('¡Hola, Leo!'), findsNothing);
        expect(find.text('6.º grado'), findsNothing);
        expect(tester.getSize(find.byType(MascotView)).height, lessThanOrEqualTo(kToolbarHeight + 2));
      });

      testWidgets('con Toco encendido no hay burbuja de espera; con Toco apagado, sí', (tester) async {
        final semantics = tester.ensureSemantics();
        final c = await openPage(tester);
        final live = StreamController<String>();
        engine.manual = live;
        await tester.enterText(find.byType(TextField), '¿Qué es un adjetivo?');
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pump();
        await tester.pump();
        expect(find.bySemanticsLabel('Estoy buscando en tu libro…'), findsNothing);
        expect(toco(tester).mood.activity, MascotActivity.thinking);

        await c.read(mascotEnabledProvider.notifier).set(false);
        await tester.pump();
        expect(find.bySemanticsLabel('Estoy buscando en tu libro…'), findsOneWidget);

        live.add('Los adjetivos dicen cómo es algo. ¿Cuál es uno?');
        await tester.pump();
        unawaited(live.close());
        await tester.pumpAndSettle();
        semantics.dispose();
      });
    });
  });

}
