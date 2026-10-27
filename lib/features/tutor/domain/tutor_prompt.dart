import '../../../core/utils/school_grade_calculator.dart';
import '../../knowledge/domain/knowledge_chunk.dart';

/// Un turno de la conversacion tal y como se le pasa al modelo.
class ChatTurn {
  const ChatTurn(this.role, this.content);

  /// `system`, `user` o `assistant`.
  final String role;
  final String content;

  Map<String, String> toMap() => {'role': role, 'content': content};
}

/// Construye el prompt del tutor: reglas pedagogicas + textos del libro del
/// grado del nino + la pregunta. Un modelo pequeno (1-2B) sigue mejor
/// instrucciones cortas y con el contexto pegado a la pregunta.
class TutorPrompt {
  const TutorPrompt._();

  /// Turnos previos que se conservan para entender "¿y el plural?".
  static const maxHistoryTurns = 4;
  static const maxHistoryChars = 300;
  /// ~2000 caracteres ≈ 600 tokens de libro: lo que cabe sin que el primer
  /// token tarde demasiado en un movil de gama baja.
  static const maxContextChars = 2000;

  /// Tutor hibrido: rigor con la teoria del libro cubano del grado, pero sin
  /// soltar la respuesta de golpe. Una idea corta + una pregunta que guie.
  /// Un modelo de 1-2B obedece mejor reglas cortas y concretas.
  static String system(int grade) => '''
Eres inocencIA, un tutor virtual paciente, cariñoso y ordenado para niños cubanos de ${SchoolGradeCalculator.label(grade)} (unos ${grade + 5} años).
Enseñas con el mismo contenido y el mismo orden que el libro de texto de su grado.
Reglas:
- Habla en español, con palabras sencillas de niño de esa edad y frases cortas.
- Usa SOLO los TEXTOS DEL LIBRO y apóyate en sus frases, casi con sus mismas palabras. No inventes datos, ejemplos ni comparaciones que no estén en ellos.
- Los ejercicios y preguntas que aparecen en los textos no son tuyos: no los repitas. Explica el contenido que los acompaña.
- Nunca des toda la respuesta de golpe. Explica UNA sola idea pequeña (2 o 3 frases) y termina con UNA pregunta propia, sencilla, sobre lo que acabas de explicar.
- Si te pide resolver un ejercicio, no lo resuelvas: indica el primer paso y pregúntale cómo seguir.
- Si el niño contesta tu pregunta, dile con cariño si va bien; si se equivoca, corrígelo con suavidad y ayúdalo a pensar. Luego avanza un paso.
- Si los textos no tienen la respuesta, dilo con sinceridad y sugiere preguntar a su maestro.
- Máximo 60 palabras.''';

  /// Recordatorio pegado a la pregunta: los modelos pequeños olvidan las reglas
  /// del sistema cuando el contexto del libro es largo.
  static const _reminder = 'Responde en 2 o 3 frases cortas, sin dar todo de golpe, y termina con una pregunta.';

  /// Mensajes para el modelo: sistema, historial reciente y la pregunta con el
  /// contexto recuperado.
  static List<ChatTurn> build({
    required int grade,
    required List<KnowledgeChunk> chunks,
    required List<ChatTurn> history,
    required String question,
  }) {
    final recent = history
        .where((t) => t.role != 'system')
        .toList()
        .reversed
        .take(maxHistoryTurns)
        .toList()
        .reversed
        .map((t) => ChatTurn(t.role, _clip(t.content, maxHistoryChars)));
    return [
      ChatTurn('system', system(grade)),
      ...recent,
      ChatTurn('user', '${_context(chunks)}\n\nPregunta del niño: ${question.trim()}\n$_reminder'),
    ];
  }

  static String _context(List<KnowledgeChunk> chunks) {
    final buf = StringBuffer('TEXTOS DEL LIBRO:');
    var used = 0;
    for (var i = 0; i < chunks.length; i++) {
      final c = chunks[i];
      final room = maxContextChars - used;
      if (room < 200) break;
      final text = _clip(c.text, room);
      used += text.length;
      buf.write('\n[${i + 1}] ${sourceLabel(c)}: $text');
    }
    return buf.toString();
  }

  /// "Español · 4to_esp_II · pág. 89".
  static String sourceLabel(KnowledgeChunk c) => [
        c.subject,
        if (c.book != null) c.book!,
        if (c.page != null) 'pág. ${c.page}',
      ].join(' · ');

  static String _clip(String s, int max) {
    final t = s.trim();
    if (t.length <= max) return t;
    final cut = t.lastIndexOf(' ', max);
    return '${t.substring(0, cut > max ~/ 2 ? cut : max)}…';
  }

  /// Respuesta sin IA cuando el libro del grado no tiene nada sobre la
  /// pregunta: evita inventar y ahorra bateria.
  static String noResults(int grade, List<String> subjects) {
    final label = SchoolGradeCalculator.label(grade);
    final topics = subjects.isEmpty
        ? ''
        : ' Puedo ayudarte con: ${subjects.join(', ')}.';
    return 'No encontré eso en tus libros de $label.$topics '
        'Prueba a preguntarlo de otra forma o consúltalo con tu maestro.';
  }
}
