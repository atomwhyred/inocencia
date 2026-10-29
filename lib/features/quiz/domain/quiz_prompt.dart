import '../../../core/utils/school_grade_calculator.dart';
import '../../knowledge/domain/knowledge_chunk.dart';
import '../../tutor/domain/tutor_prompt.dart';

/// Pide al modelo un cuestionario corto con los textos del libro que se estan
/// viendo. Formato de texto plano (mas facil para un modelo pequeno que JSON).
class QuizPrompt {
  const QuizPrompt._();

  static const questions = 3;

  /// Tokens que se le dejan al modelo: 3 preguntas con 3 opciones cada una.
  static const maxTokens = 420;

  static String system(int grade) =>
      '''
Eres inocencIA, un maestro cubano. Preparas un cuestionario para un niño de ${SchoolGradeCalculator.label(grade)}.
Reglas:
- Haz exactamente $questions preguntas de opción múltiple con 3 opciones (A, B y C) y UNA sola correcta.
- Usa SOLO los TEXTOS DEL LIBRO. Español sencillo y frases cortas.
- La pregunta se debe entender sin el libro: NO menciones páginas, recuadros ni ejercicios.
- La opción correcta sale del texto y las otras dos son claramente falsas (no sirven para esa pregunta).
- Escribe EXACTAMENTE en este formato, sin nada más:
P1: pregunta
A) opción
B) opción
C) opción
RESPUESTA: B''';

  static List<ChatTurn> build({required int grade, required List<KnowledgeChunk> chunks}) => [
    ChatTurn('system', system(grade)),
    ChatTurn(
      'user',
      '${TutorPrompt.bookContext(chunks)}\n\nEscribe ahora las $questions preguntas.',
    ),
  ];
}
