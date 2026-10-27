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

  static String system(int grade) => '''
Eres inocencIA, un tutor amable y paciente para niños cubanos de ${SchoolGradeCalculator.label(grade)}.
Reglas:
- Responde siempre en español, con palabras sencillas y frases cortas.
- Usa SOLO la información de los TEXTOS DEL LIBRO. No inventes datos.
- Si los textos no contienen la respuesta, di con sinceridad que no la encuentras en su libro y sugiere preguntar a su maestro o a un adulto.
- Explica paso a paso y, si ayuda, con un ejemplo de la vida diaria.
- No des solo la respuesta final de una tarea: guía al niño para que piense.
- Termina con una pregunta corta para comprobar si entendió.''';

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
      ChatTurn('user', '${_context(chunks)}\n\nPregunta del niño: ${question.trim()}'),
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
