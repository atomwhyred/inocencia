import '../../../core/utils/school_grade_calculator.dart';
import '../../knowledge/domain/knowledge_chunk.dart';
import 'tutor_source.dart';

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
  /// ~1100 caracteres ≈ 330 tokens de libro. El primer token de un modelo de 3B
  /// tarda ~1 s por cada ~20 tokens de prompt: es el presupuesto de latencia
  /// (con 1500 la Xiaomi Pad 5 tardaba 24 s en empezar).
  static const maxContextChars = 1100;

  /// Tutor hibrido: rigor con la teoria del libro cubano del grado, pero sin
  /// soltar la respuesta de golpe. Un paso + una pregunta. Corto a proposito:
  /// cada token de instrucciones se paga en el primer token de la respuesta.
  static String system(int grade) => '''
Eres inocencIA, un tutor virtual paciente y cariñoso para niños cubanos de ${SchoolGradeCalculator.label(grade)} (unos ${grade + 5} años). Enseñas con el contenido y el orden del libro de texto.
Reglas:
- Español sencillo y frases cortas.
- Usa SOLO los TEXTOS DEL LIBRO, casi con sus palabras. No inventes y no repitas sus ejercicios.
- El niño no ve el libro: no hables de "el poema", "la tabla", "el dibujo" ni de páginas; copia las palabras que necesites.
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

  /// La pregunta con la que el tutor cierra su mensaje, para ofrecerla como
  /// boton y que el nino la conteste. `null` si el mensaje no acaba en pregunta.
  /// Va desde el `¿` anterior al ultimo `?`; si el modelo olvido el `¿`, desde el
  /// ultimo limite de frase.
  static String? lastQuestion(String text) {
    final t = text.trim();
    final end = t.lastIndexOf('?');
    if (end < 0) return null;
    // Solo cuenta si la pregunta es lo ultimo (se admiten comillas de cierre).
    if (t.substring(end + 1).replaceAll(RegExp('["\'”»)\\s]'), '').isNotEmpty) return null;
    var start = t.lastIndexOf('¿', end);
    // Un `¿` de una pregunta anterior no vale: entre medias hay otro `?`.
    if (start >= 0 && t.substring(start, end).contains('?')) start = -1;
    if (start < 0) {
      final boundary = t.substring(0, end).lastIndexOf(RegExp(r'[.!?\n]'));
      start = boundary + 1; // 0 si no hay limite
    }
    final q = t.substring(start, end + 1).trim();
    return q.length < 3 ? null : q;
  }

  /// Cosas del libro que el nino no tiene delante en el chat. "La tabla de
  /// multiplicar" si es contenido y se respeta; "tu libro" y "tu libreta" tambien.
  static const _unseenNouns =
      r'(?:tablas?(?!\s+de\s+multiplicar)|poemas?|textos?|ejercicios?|ejemplos?|lecturas?|dibujos?|'
      r'imagen|im[aá]genes|ilustraci[oó]n(?:es)?|recuadros?|cuadros?|esquemas?|'
      r'p[aá]ginas?(?:\s+\d+)?)';

  /// "en la tabla del texto", "en el poema", "de los ejercicios"...
  static final _unseenRef = RegExp(
    r'\s*\b(?:en|de|dentro\s+de|sobre)\s+(?:el|la|los|las|este|esta|ese|esa|estos|estas)\s+' +
        _unseenNouns +
        r'(?:\s+(?:del|de\s+la)\s+' +
        _unseenNouns +
        r')?\b',
    caseSensitive: false,
  );

  /// "del ejercicio", "del texto" (contraccion).
  static final _unseenDel = RegExp(r'\s*\bdel\s+' + _unseenNouns + r'\b', caseSensitive: false);

  /// "al ver la tabla", "mirando el dibujo".
  static final _unseenLook = RegExp(
    r'\s*\b(?:al\s+ver|al\s+mirar|mirando|observando)\s+(?:el|la|los|las)\s+' +
        _unseenNouns +
        r'\b',
    caseSensitive: false,
  );

  /// Quita de la respuesta del modelo lo que el nino no puede ver ("¿Qué ejemplos
  /// encuentras en la tabla del texto?" → "¿Qué ejemplos encuentras?"). El modelo
  /// pequeno lo hace aunque las instrucciones lo prohiben: copia el contexto del libro.
  static String hideUnseen(String text) {
    var t = text
        .replaceAll(_unseenRef, '')
        .replaceAll(_unseenDel, '')
        .replaceAll(_unseenLook, '');
    if (t == text) return text;
    t = t
        .replaceAllMapped(RegExp(r' +([?.,;:!])'), (m) => m[1]!)
        .replaceAllMapped(RegExp(r'([¿¡])\s*,\s*'), (m) => m[1]!)
        .replaceAllMapped(RegExp(r'(^|[.!?]\s+),\s*'), (m) => m[1]!)
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trimLeft();
    // Mayuscula al principio de frase si se quito lo que la abria ("En el poema, hay..." → "Hay...").
    return t.replaceAllMapped(
      RegExp(r'(^|[.!?]\s+|[¿¡])([a-záéíóúñ])'),
      (m) => '${m[1]}${m[2]!.toUpperCase()}',
    ).trim();
  }

  static const _maxAnswerWords = 12;

  /// Palabras con las que un nino pregunta, pide algo o encadena otra duda
  /// ("y el plural") en vez de contestar.
  static const _nonAnswerStarts = {
    'que', 'como', 'por', 'cual', 'cuales', 'cuando', 'donde', 'quien', 'quienes',
    'cuanto', 'cuantos', 'cuanta', 'cuantas', 'para', 'explica', 'explicame',
    'dime', 'ayudame', 'repite', 'cuentame', 'otra', 'otro', 'quiero',
    'dame', 'muestrame', 'ensename', 'enseñame', 'puedes', 'necesito',
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

  /// Los fragmentos del libro tal y como se le pasan al modelo.
  static String bookContext(List<KnowledgeChunk> chunks) => _context(chunks);

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
  static String sourceLabel(KnowledgeChunk c) => TutorSource.fromChunk(c).label;

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
    return '$_noResultsStart de $label.$topics '
        'Prueba a preguntarlo de otra forma o consúltalo con tu maestro.';
  }

  static const _noResultsStart = 'No encontré eso en tus libros';

  /// Textos con los que el tutor avisa de que no pudo responder.
  static const errorText = 'Ups, algo salió mal y no pude responder. Inténtalo de nuevo.';
  static const emptyAnswerText = 'No pude generar una respuesta. Inténtalo de nuevo.';

  /// `true` si [text] es uno de esos avisos (no una explicacion del tutor).
  static bool isFailure(String text) =>
      text.startsWith(_noResultsStart) || text == errorText || text == emptyAnswerText;
}
