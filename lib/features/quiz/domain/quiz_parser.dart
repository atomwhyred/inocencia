import 'quiz.dart';

/// Lee el cuestionario que escribe el modelo. Es tolerante con mayusculas,
/// numeracion y espacios, y descarta las preguntas mal formadas en vez de fallar.
class QuizParser {
  const QuizParser._();

  static final _question = RegExp(
    r'^\s*(?:pregunta|p)?\s*\d+\s*[:.)\-]\s*(.+)$',
    caseSensitive: false,
  );
  static final _option = RegExp(r'^\s*\(?([ABCabc])\s*[).:\-]\s*(.+)$');
  static final _answer = RegExp(
    r'^\s*(?:respuesta(?:\s+correcta)?|correcta)\s*[:=\-]?\s*\(?\s*([ABCabc])\b',
    caseSensitive: false,
  );

  static List<QuizQuestion> parse(String raw) {
    final out = <QuizQuestion>[];
    String? text;
    var options = <String?>[null, null, null];
    int? correct;

    void close() {
      final t = text;
      final c = correct;
      if (t != null && c != null && options.every((o) => o != null && o.isNotEmpty)) {
        out.add(QuizQuestion(text: t, options: [for (final o in options) o!], correct: c));
      }
      text = null;
      options = <String?>[null, null, null];
      correct = null;
    }

    for (final line in raw.replaceAll('**', '').split('\n')) {
      final answer = _answer.firstMatch(line);
      if (answer != null) {
        correct = 'abc'.indexOf(answer.group(1)!.toLowerCase());
        continue;
      }
      final option = _option.firstMatch(line);
      if (option != null && text != null) {
        options['abc'.indexOf(option.group(1)!.toLowerCase())] = option.group(2)!.trim();
        continue;
      }
      final question = _question.firstMatch(line);
      if (question != null) {
        close();
        text = question.group(1)!.trim();
      }
    }
    close();
    return out;
  }
}
