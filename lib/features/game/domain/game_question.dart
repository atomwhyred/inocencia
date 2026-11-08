import 'dart:math';

import 'package:equatable/equatable.dart';

import '../../../core/utils/plain_text.dart';
import '../../flashcards/domain/flashcard.dart';
import '../../quiz/domain/quiz.dart';

/// Una pregunta del juego: del banco del libro o de una tarjeta del propio nino.
class GameQuestion extends Equatable {
  const GameQuestion({required this.quiz, this.ownCard = false, this.source});

  final QuizQuestion quiz;

  /// Sale de una tarjeta que el nino creo: vale el doble.
  final bool ownCard;

  /// "Matemática · 4to_matematica · pág. 12" (solo las del banco).
  final String? source;

  int get points => ownCard ? 2 : 1;

  @override
  List<Object?> get props => [quiz, ownCard, source];
}

/// Las tarjetas del nino como preguntas de opcion multiple: la respuesta buena
/// es el reverso de la tarjeta y las falsas, reversos de otras tarjetas suyas.
class CardQuestions {
  const CardQuestions._();

  /// Hacen falta al menos 3 tarjetas con respuestas distintas.
  static const minCards = 3;

  static List<GameQuestion> fromDeck(List<Flashcard> deck, Random random) {
    final cards = <Flashcard>[];
    final seen = <String>{};
    for (final c in deck) {
      final key = plainText(c.back);
      if (key.isEmpty || c.front.trim().isEmpty || !seen.add(key)) continue;
      cards.add(c);
    }
    if (cards.length < minCards) return const [];
    final out = <GameQuestion>[];
    for (final card in cards) {
      final others = [
        for (final o in cards)
          if (o.id != card.id) o.back.trim(),
      ]..shuffle(random);
      final quiz = QuizQuestion(
        text: card.front.trim(),
        options: [card.back.trim(), others[0], others[1]],
        correct: 0,
      ).shuffled(random);
      out.add(GameQuestion(quiz: quiz, ownCard: true, source: card.source));
    }
    return out;
  }
}

/// Fuente de preguntas de un nino para una partida.
abstract class QuestionBank {
  /// `true` si la base de libros trae el banco de preguntas del juego.
  bool get available;

  /// Hasta [count] preguntas del grado [grade], al azar.
  List<GameQuestion> forGrade(
    int grade, {
    required int count,
    required Random random,
  });

  void close();
}

/// Mezcla el banco del libro con las tarjetas propias (una de cada tres, si hay)
/// y las sirve sin repetir hasta agotarlas; entonces vuelve a empezar.
class QuestionDeck {
  QuestionDeck(List<GameQuestion> bank, List<GameQuestion> cards, Random random)
    : _random = random,
      _all = _mix(bank, cards, random);

  final Random _random;
  final List<GameQuestion> _all;
  var _next = 0;

  bool get isEmpty => _all.isEmpty;
  int get length => _all.length;

  static List<GameQuestion> _mix(
    List<GameQuestion> bank,
    List<GameQuestion> cards,
    Random random,
  ) {
    final b = [...bank]..shuffle(random);
    final c = [...cards]..shuffle(random);
    final out = <GameQuestion>[];
    var i = 0;
    var j = 0;
    while (i < b.length || j < c.length) {
      // Dos del libro y una propia, mientras queden de las dos clases.
      if (j < c.length && (out.length % 3 == 2 || i >= b.length)) {
        out.add(c[j++]);
      } else {
        out.add(b[i++]);
      }
    }
    return out;
  }

  GameQuestion next() {
    if (_all.isEmpty) throw StateError('No hay preguntas');
    if (_next >= _all.length) {
      _all.shuffle(_random);
      _next = 0;
    }
    final q = _all[_next++];
    return GameQuestion(
      quiz: q.quiz.shuffled(_random),
      ownCard: q.ownCard,
      source: q.source,
    );
  }
}
