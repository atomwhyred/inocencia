import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/features/flashcards/domain/flashcard.dart';
import 'package:inocencia/features/game/data/sqlite_question_bank.dart';
import 'package:inocencia/features/game/domain/game_question.dart';
import 'package:inocencia/features/quiz/domain/quiz.dart';
import 'package:sqlite3/sqlite3.dart';

Flashcard card(int id, String front, String back) => Flashcard(id: id, front: front, back: back);

void main() {
  group('tarjetas como preguntas', () {
    test('con menos de 3 respuestas distintas no hay preguntas', () {
      final r = Random(1);
      expect(CardQuestions.fromDeck([card(1, '¿a?', 'Sol'), card(2, '¿b?', 'Luna')], r), isEmpty);
      expect(
        CardQuestions.fromDeck([card(1, '¿a?', 'Sol'), card(2, '¿b?', 'sol'), card(3, '¿c?', 'Luna')], r),
        isEmpty,
        reason: '"Sol" y "sol" son la misma respuesta',
      );
    });

    test('la buena es su reverso y las falsas, reversos de otras tarjetas; valen doble', () {
      final deck = [card(1, '¿Capital de Cuba?', 'La Habana'), card(2, '¿2+2?', '4'), card(3, '¿Color del cielo?', 'Azul')];
      final qs = CardQuestions.fromDeck(deck, Random(3));
      expect(qs, hasLength(3));
      for (final q in qs) {
        expect(q.ownCard, isTrue);
        expect(q.points, 2);
        expect(q.quiz.options.toSet(), {'La Habana', '4', 'Azul'});
      }
      final habana = qs.firstWhere((q) => q.quiz.text == '¿Capital de Cuba?');
      expect(habana.quiz.options[habana.quiz.correct], 'La Habana');
    });
  });

  group('mazo de la partida', () {
    GameQuestion q(String t, {bool own = false}) => GameQuestion(
      quiz: QuizQuestion(text: t, options: const ['a', 'b', 'c'], correct: 0),
      ownCard: own,
    );

    test('mezcla dos del libro y una propia, y no repite hasta agotarlas', () {
      final deck = QuestionDeck([q('1'), q('2'), q('3'), q('4')], [q('x', own: true), q('y', own: true)], Random(5));
      expect(deck.length, 6);
      final first = [for (var i = 0; i < 6; i++) deck.next()];
      expect(first.map((g) => g.quiz.text).toSet(), hasLength(6));
      expect(first[2].ownCard, isTrue);
      expect(first[5].ownCard, isTrue);
      deck.next(); // vuelve a empezar sin fallar
    });

    test('al servir una pregunta la correcta sigue siendo la misma opción', () {
      final deck = QuestionDeck([q('1')], const [], Random(9));
      for (var i = 0; i < 5; i++) {
        final g = deck.next();
        expect(g.quiz.options[g.quiz.correct], 'a');
      }
    });

    test('sin preguntas está vacío', () {
      expect(QuestionDeck(const [], const [], Random(1)).isEmpty, isTrue);
    });
  });

  group('banco en knowledge.db', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('bank'));
    tearDown(() => dir.deleteSync(recursive: true));

    String makeDb({required bool withBank}) {
      final path = '${dir.path}/k.db';
      final db = sqlite3.open(path);
      db.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
      if (withBank) {
        db.execute(
          'CREATE TABLE game_questions (id INTEGER PRIMARY KEY, grade INTEGER, subject TEXT, book TEXT, '
          'page INTEGER, question TEXT, a TEXT, b TEXT, c TEXT, correct INTEGER)',
        );
        for (var i = 0; i < 5; i++) {
          db.execute(
            'INSERT INTO game_questions (grade, subject, book, page, question, a, b, c, correct) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [i < 3 ? 4 : 6, 'Matemática', '4to_matematica', 10 + i, '¿Pregunta $i?', 'x', 'y', 'z', 2],
          );
        }
      }
      db.close();
      return path;
    }

    test('lee solo las del grado pedido, con su fuente', () {
      final bank = SqliteQuestionBank.open(makeDb(withBank: true));
      addTearDown(bank.close);
      expect(bank.available, isTrue);
      final qs = bank.forGrade(4, count: 10, random: Random(1));
      expect(qs, hasLength(3));
      expect(qs.first.quiz.options[qs.first.quiz.correct], 'z');
      expect(qs.first.source, startsWith('Matemática · 4to_matematica · pág. 1'));
      expect(bank.forGrade(6, count: 1, random: Random(1)), hasLength(1));
      expect(bank.forGrade(2, count: 5, random: Random(1)), isEmpty);
    });

    test('una base antigua sin la tabla no falla: no hay banco', () {
      final bank = SqliteQuestionBank.open(makeDb(withBank: false));
      addTearDown(bank.close);
      expect(bank.available, isFalse);
      expect(bank.forGrade(4, count: 5, random: Random(1)), isEmpty);
    });
  });
}
