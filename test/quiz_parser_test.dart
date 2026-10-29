import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/features/quiz/domain/quiz.dart';
import 'package:inocencia/features/quiz/domain/quiz_parser.dart';
import 'package:inocencia/features/quiz/domain/quiz_prompt.dart';
import 'package:inocencia/features/knowledge/domain/knowledge_chunk.dart';

void main() {
  groundingTests();
  const good = '''
P1: ¿Qué es un sustantivo?
A) Una palabra que nombra
B) Una palabra que corre
C) Una palabra que suma
RESPUESTA: A

P2: ¿Cuál es un nombre propio?
A) casa
B) Cuba
C) río
RESPUESTA: B

P3: ¿Qué letra va al inicio de un nombre propio?
A) minúscula
B) la z
C) mayúscula
RESPUESTA: C
''';

  group('QuizParser', () {
    test('lee tres preguntas bien formadas', () {
      final q = QuizParser.parse(good);
      expect(q, hasLength(3));
      expect(q[0].text, '¿Qué es un sustantivo?');
      expect(q[0].options, [
        'Una palabra que nombra',
        'Una palabra que corre',
        'Una palabra que suma',
      ]);
      expect([for (final x in q) x.correct], [0, 1, 2]);
    });

    test('tolera mayúsculas, numeración, negritas y "Respuesta correcta"', () {
      final q = QuizParser.parse('''
**Pregunta 1.** ¿Cuánto es 2 + 2?
a) 3
b. 4
(C) 5
Respuesta correcta: b

2) ¿Cuánto es 1 + 1?
A: 2
B: 3
C: 4
RESPUESTA = (A)
''');
      expect(q, hasLength(2));
      expect(q[0].correct, 1);
      expect(q[0].options, ['3', '4', '5']);
      expect(q[1].correct, 0);
    });

    test('descarta preguntas sin 3 opciones o sin respuesta, y no falla con ruido', () {
      final q = QuizParser.parse('''
Claro, aquí tienes tu cuestionario:
P1: Pregunta sin respuesta
A) uno
B) dos
C) tres

P2: Pregunta con dos opciones
A) uno
B) dos
RESPUESTA: A

P3: ¿Esta sí está bien?
A) sí
B) no
C) tal vez
RESPUESTA: A
''');
      expect(q, hasLength(1));
      expect(q.single.text, '¿Esta sí está bien?');
    });

    test('texto vacío o sin formato no da preguntas', () {
      expect(QuizParser.parse(''), isEmpty);
      expect(QuizParser.parse('No sé qué preguntar.'), isEmpty);
    });
  });

  group('QuizQuestion.shuffled', () {
    test('cambia el orden pero la correcta sigue siendo la misma opción', () {
      const q = QuizQuestion(text: 'x', options: ['uno', 'dos', 'tres'], correct: 1);
      final orders = <String>{};
      for (var seed = 0; seed < 30; seed++) {
        final s = q.shuffled(Random(seed));
        expect([...s.options]..sort(), ['dos', 'tres', 'uno']);
        orders.add(s.options.join());
        // La correcta (dos) sigue apuntada tras barajar.
        final again = q.shuffled(Random(seed));
        expect(again.options[again.correct], 'dos');
      }
      expect(orders.length, greaterThan(1));
    });
  });

  test('el prompt pide 3 preguntas con el libro y el formato exacto', () {
    final turns = QuizPrompt.build(
      grade: 2,
      chunks: const [
        KnowledgeChunk(
          id: 1,
          subject: 'Español',
          book: '2do_lengua',
          page: 138,
          grade: 2,
          text: 'El sustantivo nombra.',
        ),
      ],
    );
    expect(turns.first.role, 'system');
    expect(turns.first.content, contains('exactamente 3 preguntas'));
    expect(turns.first.content, contains('RESPUESTA: B'));
    expect(turns.last.content, contains('TEXTOS DEL LIBRO'));
    expect(turns.last.content, contains('El sustantivo nombra.'));
  });
}

void groundingTests() {
  group('QuizGrounding', () {
    const book = 'Los sustantivos nombran personas, animales y cosas. Cuba es un nombre propio.';
    const ok = QuizQuestion(
      text: '¿Qué es Cuba?',
      options: ['un color', 'un nombre propio', 'un verbo'],
      correct: 1,
    );

    test('acepta una pregunta cuya respuesta sale del libro (sin tildes ni mayúsculas)', () {
      expect(QuizGrounding.isGrounded(ok, book), isTrue);
      expect(QuizGrounding.isGrounded(ok, 'CUBA ES UN NOMBRE PROPIO'), isTrue);
    });

    test('rechaza la que marca como correcta algo que el libro no dice', () {
      const bad = QuizQuestion(
        text: '¿Qué escriben con mayúscula?',
        options: ['cine', 'mesa', 'elefante'],
        correct: 0,
      );
      expect(QuizGrounding.isGrounded(bad, book), isFalse);
    });

    test('rechaza preguntas que dependen de una página, recuadro o dibujo', () {
      const q = QuizQuestion(
        text: '¿Qué es Cuba en el recuadro de la página 138?',
        options: ['un color', 'un nombre propio', 'un verbo'],
        correct: 1,
      );
      expect(QuizGrounding.isGrounded(q, book), isFalse);
    });

    test('no confunde una palabra con otra que la contiene y rechaza opciones repetidas', () {
      const q = QuizQuestion(text: 'x', options: ['sol', 'luna', 'mar'], correct: 0);
      expect(QuizGrounding.isGrounded(q, 'Es el día más solo del año'), isFalse);
      const dup = QuizQuestion(text: 'x', options: ['Cuba', 'cuba', 'mar'], correct: 0);
      expect(QuizGrounding.isGrounded(dup, book), isFalse);
    });
  });
}
