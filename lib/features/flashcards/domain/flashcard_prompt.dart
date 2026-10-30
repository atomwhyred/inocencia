import '../../../core/utils/school_grade_calculator.dart';
import '../../knowledge/domain/knowledge_chunk.dart';
import '../../tutor/domain/tutor_prompt.dart';

/// Pide al modelo un mazo corto de tarjetas con los textos del libro que se
/// estan viendo. Texto plano (mas facil para un modelo pequeno que JSON).
class FlashcardPrompt {
  const FlashcardPrompt._();

  static const cards = 4;

  /// Tokens que se le dejan al modelo: 4 tarjetas de pregunta y respuesta cortas.
  static const maxTokens = 320;

  static String system(int grade) =>
      '''
Eres inocencIA, un maestro cubano. Preparas tarjetas de memoria para un niño de ${SchoolGradeCalculator.label(grade)}.
Reglas:
- Haz exactamente $cards tarjetas. Cada una tiene una PREGUNTA corta (al frente) y su RESPUESTA en una sola frase corta (al reverso).
- Usa SOLO los TEXTOS DEL LIBRO, casi con sus palabras. Español sencillo.
- La tarjeta se debe entender sin el libro: NO menciones páginas, recuadros, ejercicios ni dibujos.
- Escribe EXACTAMENTE en este formato, sin nada más:
T1: pregunta
R: respuesta''';

  static List<ChatTurn> build({required int grade, required List<KnowledgeChunk> chunks}) => [
    ChatTurn('system', system(grade)),
    ChatTurn('user', '${TutorPrompt.bookContext(chunks)}\n\nEscribe ahora las $cards tarjetas.'),
  ];
}
