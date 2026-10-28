import 'package:equatable/equatable.dart';

import '../../tutor/application/tutor_controller.dart';
import '../../tutor/domain/tutor_prompt.dart';

/// Lo que esta haciendo la mascota (Toco), segun el estado del chat.
enum MascotActivity {
  /// El tutor se esta preparando (cargando el modelo).
  sleeping,

  /// Listo; si no hay mensajes, saluda.
  idle,

  /// El modelo esta pensando: aun no ha llegado ninguna palabra.
  thinking,

  /// Llega el texto de la respuesta.
  talking,

  /// El tutor acabo preguntando y el nino prepara su respuesta.
  listening,

  /// Algo fallo: sin modelo, error o sin resultados en los libros.
  sad,
}

/// Como reacciona a la respuesta del nino (solo cuando contesto, no pregunto).
enum MascotEmotion { neutral, happy, concerned }

class MascotMood extends Equatable {
  const MascotMood(this.activity, [this.emotion = MascotEmotion.neutral]);

  final MascotActivity activity;
  final MascotEmotion emotion;

  @override
  List<Object?> get props => [activity, emotion];

  @override
  String toString() => 'MascotMood($activity, $emotion)';
}

/// Valoracion que el tutor hace de la respuesta del nino en su primera frase.
enum Verdict { positive, negative }

/// Estado de la mascota para [state]. [replying] es `true` mientras el nino
/// prepara su respuesta (banner "Respondiendo a: ..." o foco en la caja).
MascotMood moodFor(TutorState state, {bool replying = false}) {
  switch (state.status) {
    case TutorStatus.idle:
    case TutorStatus.loading:
      return const MascotMood(MascotActivity.sleeping);
    case TutorStatus.needsFiles:
    case TutorStatus.error:
      return const MascotMood(MascotActivity.sad);
    case TutorStatus.ready:
      break;
  }
  final messages = state.messages;
  if (messages.isEmpty) return const MascotMood(MascotActivity.idle);

  final last = messages.last;
  if (last.fromUser) return const MascotMood(MascotActivity.thinking);
  if (last.streaming && last.text.isEmpty) return const MascotMood(MascotActivity.thinking);
  if (!last.streaming && TutorPrompt.isFailure(last.text)) {
    return const MascotMood(MascotActivity.sad);
  }

  final emotion = _emotionAfterAnswer(messages);
  if (last.streaming) return MascotMood(MascotActivity.talking, emotion);
  if (replying && TutorPrompt.lastQuestion(last.text) != null) {
    return const MascotMood(MascotActivity.listening);
  }
  return MascotMood(MascotActivity.idle, emotion);
}

/// Si el ultimo mensaje del tutor responde a una *respuesta* del nino, la
/// emocion sale de como la valora. Si el nino pregunto, es neutral.
MascotEmotion _emotionAfterAnswer(List<TutorMessage> messages) {
  if (messages.length < 3) return MascotEmotion.neutral;
  final reply = messages[messages.length - 1];
  final child = messages[messages.length - 2];
  final question = messages[messages.length - 3];
  if (reply.fromUser || !child.fromUser || question.fromUser) return MascotEmotion.neutral;
  final history = [ChatTurn('assistant', question.text)];
  if (!TutorPrompt.isAnswer(history, child.text)) return MascotEmotion.neutral;
  return switch (verdictOf(reply.text)) {
    Verdict.positive => MascotEmotion.happy,
    Verdict.negative => MascotEmotion.concerned,
    null => MascotEmotion.neutral,
  };
}

/// Como valora el tutor la respuesta, mirando solo su primera frase: el
/// prompt le pide empezar con "Casi" si falla y valorar con carino si acierta.
/// `null` si no se puede saber (en la duda, Toco no celebra ni se preocupa).
Verdict? verdictOf(String text) {
  final first = _firstSentence(_plain(text));
  if (first.isEmpty) return null;
  // Lo negativo primero: "no es correcto" contiene "correcto".
  if (_negative.hasMatch(first)) return Verdict.negative;
  if (_positive.hasMatch(first)) return Verdict.positive;
  return null;
}

final _negative = RegExp(
  r'^(casi|uy|ojo)\b|\b(no (es |esta )?(del todo|exactamente|exacto|correcto|asi|eso|cierto|bien)|incorrect[oa]|todavia no|aun no|te equivocas|equivocad[oa])\b',
);

final _positive = RegExp(
  r'\b(muy bien|bien hecho|excelente|correct[oa]|exact[oa]|exactamente|perfect[oa]|eso es|asi es|'
  r'felicidades|felicitaciones|genial|magnific[oa]|estupend[oa]|fantastic[oa]|bravo|'
  r'buena respuesta|buen trabajo|acertaste|lo lograste|lo hiciste muy bien|'
  r'claro que si|tienes razon)\b',
);

/// Hasta el primer `.`, `!` o `?` (o salto de linea), con un tope.
String _firstSentence(String s) {
  final t = s.trim();
  final end = t.indexOf(RegExp(r'[.!?\n]'));
  final sentence = end < 0 ? t : t.substring(0, end);
  return sentence.length > 90 ? sentence.substring(0, 90) : sentence;
}

/// Minusculas y sin tildes ni signos de apertura.
String _plain(String s) {
  const from = 'áéíóúüÁÉÍÓÚÜ';
  const to = 'aeiouuaeiouu';
  final buf = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    if (c == '¡' || c == '¿') continue;
    final i = from.indexOf(c);
    buf.write(i >= 0 ? to[i] : c);
  }
  return buf.toString();
}
