import 'dart:math';

import 'package:equatable/equatable.dart';

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

  static String _plain(String s) {
    const from = 'áéíóúüñÁÉÍÓÚÜÑ';
    const to = 'aeiouunaeiouun';
    final buf = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      final c = String.fromCharCode(r);
      final i = from.indexOf(c);
      buf.write(i >= 0 ? to[i] : c);
    }
    return buf
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r' +'), ' ')
        .trim();
  }

  /// Preguntas que dependen de algo que el nino no tiene delante.
  static final _needsBook = RegExp(r'\b(pagina|recuadro|ejercicio|imagen|dibujo|figura|texto)\b');

  static bool isGrounded(QuizQuestion q, String bookText) {
    if (_needsBook.hasMatch(_plain(q.text))) return false;
    final options = q.options.map(_plain).toList();
    if (options.toSet().length != options.length || options.any((o) => o.isEmpty)) return false;
    final answer = options[q.correct];
    // Con palabras sueltas se busca como palabra completa ("sol" no esta en "solo").
    return ' ${_plain(bookText)} '.contains(' $answer ');
  }
}
