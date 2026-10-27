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
  /// ~1500 caracteres ≈ 450 tokens de libro. El primer token de un modelo de 3B
  /// tarda ~1 s por cada ~20 tokens de prompt: es el presupuesto de latencia.
  static const maxContextChars = 1500;

  /// Tutor hibrido: rigor con la teoria del libro cubano del grado, pero sin
  /// soltar la respuesta de golpe. Un paso + una pregunta. Corto a proposito:
  /// cada token de instrucciones se paga en el primer token de la respuesta.
  static String system(int grade) => '''
Eres inocencIA, un tutor virtual paciente y cariñoso para niños cubanos de ${SchoolGradeCalculator.label(grade)} (unos ${grade + 5} años). Enseñas con el contenido y el orden del libro de texto.
Reglas:
- Español sencillo y frases cortas.
- Usa SOLO los TEXTOS DEL LIBRO, casi con sus palabras. No inventes y no repitas sus ejercicios.
- Da UN solo paso o idea (2 o 3 frases completas) y termina con UNA pregunta tuya que lo haga pensar el siguiente paso (nunca "¿entiendes?"). Nunca des toda la respuesta de golpe; ante un ejercicio, no lo resuelvas: pide el primer paso.
- Si el niño contesta, dile si va bien o corrígelo con suavidad, y avanza un paso.
- Si el libro no lo explica, dilo y sugiere preguntar al maestro.
- Máximo 60 palabras.''';

  /// Recordatorio pegado a la pregunta: los modelos pequeños olvidan las reglas
  /// del sistema cuando el contexto del libro es largo.
  static const _reminder = 'Responde con UN solo paso en 2 o 3 frases claras y termina con una pregunta que lo haga pensar.';

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
