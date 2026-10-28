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

  /// Cuando el nino contesta a la pregunta del tutor, primero hay que valorar su
  /// respuesta: el modelo pequeno no lo hace si el mensaje parece una pregunta nueva.
  static const _reminderAnswer =
      'Valora su respuesta con cariño (si falla, empieza con "Casi" y corrígela con suavidad). Luego da UN paso y termina con UNA sola pregunta.';

  /// "No sé" no es una respuesta que valorar: hay que darle una pista.
  static const _reminderUnsure =
      'El niño no sabe. Anímalo, dale una pista del libro sin dar la respuesta y termina con UNA sola pregunta fácil.';

  static final _unsure = RegExp(r'^(no (lo )?se|ni idea|no recuerdo)\b');

  static bool _isUnsure(String text) => _unsure.hasMatch(_plain(text.trim()));

  /// Indice donde acaba la primera pregunta de [text] (justo tras su `?`), o -1
  /// si aun no hay ninguna. El modelo pequeno encadena varias preguntas y un
  /// "Pregunta:" repetido: se corta ahi, y de paso se ahorra generar el resto.
  static int endOfFirstQuestion(String text) {
    final i = text.indexOf('?');
    return i < 0 ? -1 : i + 1;
  }

  static const _maxAnswerWords = 12;

  /// Palabras con las que un nino pregunta, pide algo o encadena otra duda
  /// ("y el plural") en vez de contestar.
  static const _nonAnswerStarts = {
    'que', 'como', 'por', 'cual', 'cuales', 'cuando', 'donde', 'quien', 'quienes',
    'cuanto', 'cuantos', 'cuanta', 'cuantas', 'para', 'explica', 'explicame',
    'dime', 'ayudame', 'repite', 'cuentame', 'otra', 'otro', 'quiero',
    'y', 'entonces', 'pero',
  };

  /// `true` si [text] parece la respuesta del nino a la ultima pregunta del
  /// tutor: el tutor acabo preguntando y el nino contesta corto, sin `?` y sin
  /// empezar por una palabra interrogativa o una peticion.
  static bool isAnswer(List<ChatTurn> history, String text) {
    final last = history.where((t) => t.role != 'system').lastOrNull;
    if (last == null || last.role != 'assistant') return false;
    if (!last.content.trimRight().endsWith('?')) return false;
    final t = text.trim();
    if (t.isEmpty || t.contains('?') || t.contains('¿')) return false;
    if (t.split(RegExp(r'\s+')).length > _maxAnswerWords) return false;
    final plain = _plain(t);
    final first = plain.split(RegExp(r'\s+')).first;
    return !_nonAnswerStarts.contains(first) && !plain.startsWith('no entiendo');
  }

  static String _plain(String s) {
    const from = 'áéíóúüÁÉÍÓÚÜ';
    const to = 'aeiouuaeiouu';
    final buf = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      final c = String.fromCharCode(r);
      final i = from.indexOf(c);
      buf.write(i >= 0 ? to[i] : c);
    }
    return buf.toString();
  }

  /// Mensajes para el modelo: sistema, historial reciente y la pregunta con el
  /// contexto recuperado. Si [answering], el mensaje del nino es la respuesta a
  /// la pregunta del tutor y no una pregunta nueva.
  static List<ChatTurn> build({
    required int grade,
    required List<KnowledgeChunk> chunks,
    required List<ChatTurn> history,
    required String question,
    bool answering = false,
  }) {
    final label = answering ? 'Respuesta del niño a tu pregunta' : 'Pregunta del niño';
    final reminder = !answering
        ? _reminder
        : _isUnsure(question)
            ? _reminderUnsure
            : _reminderAnswer;
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
      ChatTurn('user', '${_context(chunks)}\n\n$label: ${question.trim()}\n$reminder'),
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
