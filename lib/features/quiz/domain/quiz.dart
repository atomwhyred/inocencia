import 'dart:math';

import 'package:equatable/equatable.dart';

import '../../../core/utils/plain_text.dart';

/// Una pregunta de opcion multiple con una sola respuesta correcta.
class QuizQuestion extends Equatable {
  const QuizQuestion({required this.text, required this.options, required this.correct});

  final String text;
  final List<String> options;

  /// Posicion de la opcion correcta en [options].
  final int correct;

  /// Las mismas opciones en otro orden (el modelo tiende a poner la correcta
  /// en la A); [correct] sigue apuntando a la buena.
  QuizQuestion shuffled(Random random) {
    final order = List<int>.generate(options.length, (i) => i)..shuffle(random);
    return QuizQuestion(
      text: text,
      options: [for (final i in order) options[i]],
      correct: order.indexOf(correct),
    );
  }

  @override
  List<Object?> get props => [text, options, correct];
}

/// Comprueba que una pregunta esta apoyada en el libro. Un modelo pequeno a veces
/// inventa preguntas sin sentido o marca como correcta una opcion cualquiera;
/// como el nino aprenderia algo falso, solo se aceptan las preguntas cuya
/// respuesta correcta aparece en los textos del libro y las opciones no se
/// repiten.
class QuizGrounding {
  const QuizGrounding._();

  static bool isGrounded(QuizQuestion q, String bookText) {
    if (dependsOnBookLayout(q.text)) return false;
    final options = q.options.map(plainText).toList();
    if (options.toSet().length != options.length || options.any((o) => o.isEmpty)) return false;
    final answer = options[q.correct];
    // Con palabras sueltas se busca como palabra completa ("sol" no esta en "solo").
    return ' ${plainText(bookText)} '.contains(' $answer ');
  }
}
