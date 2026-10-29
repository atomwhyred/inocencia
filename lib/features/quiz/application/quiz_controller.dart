import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../achievements/application/achievement_service.dart';
import '../../auth/application/session.dart';
import '../../tutor/application/tutor_controller.dart';
import '../domain/quiz.dart';
import '../domain/quiz_parser.dart';
import '../../tutor/domain/tutor_prompt.dart';
import '../domain/quiz_prompt.dart';

enum QuizStatus {
  /// El modelo escribe las preguntas.
  preparing,

  /// Esperando que el nino elija una opcion.
  asking,

  /// Ya eligio: se muestra si acerto.
  answered,

  /// Contesto todas las que hay y el modelo aun escribe la siguiente.
  waiting,

  finished,

  /// No se pudo preparar el quiz.
  failed,
}

class QuizState extends Equatable {
  const QuizState({
    this.status = QuizStatus.preparing,
    this.questions = const [],
    this.index = 0,
    this.picked,
    this.correct = 0,
    this.message,
    this.expecting = false,
  });

  final QuizStatus status;
  final List<QuizQuestion> questions;
  final int index;

  /// Opcion que eligio el nino en la pregunta actual.
  final int? picked;

  /// Aciertos hasta ahora.
  final int correct;
  final String? message;

  /// El modelo aun esta escribiendo preguntas: pueden llegar mas.
  final bool expecting;

  QuizQuestion? get question => index < questions.length ? questions[index] : null;
  bool get isLast => index >= questions.length - 1 && !expecting;
  bool get pickedRight => picked != null && picked == question?.correct;

  QuizState copyWith({
    QuizStatus? status,
    List<QuizQuestion>? questions,
    int? index,
    Object? picked = _keep,
    int? correct,
    String? message,
    bool? expecting,
  }) => QuizState(
    status: status ?? this.status,
    questions: questions ?? this.questions,
    index: index ?? this.index,
    picked: identical(picked, _keep) ? this.picked : picked as int?,
    correct: correct ?? this.correct,
    message: message ?? this.message,
    expecting: expecting ?? this.expecting,
  );

  static const _keep = Object();

  @override
  List<Object?> get props => [status, questions, index, picked, correct, message, expecting];
}

/// Orden de las opciones; las pruebas lo fijan.
final quizRandomProvider = Provider<Random>((ref) => Random());

/// Un quiz de 3 preguntas sobre el tema de la conversacion: el modelo local lo
/// escribe a partir de los textos del libro y el nino lo contesta.
class QuizController extends Notifier<QuizState> {
  StreamSubscription<String>? _sub;
  Completer<void>? _pending;
  bool _closed = false;

  /// Texto del libro con el que se hizo el quiz: las preguntas se comprueban contra el.
  String _bookText = '';

  static const unavailable =
      'No pude preparar el quiz. ¡Pregúntame otra cosa y lo intentamos luego!';
  static const needsTopic = 'Pregúntame algo primero y después hacemos un quiz sobre eso.';

  @override
  QuizState build() {
    ref.onDispose(() {
      _closed = true;
      _sub?.cancel();
      final p = _pending;
      if (p != null && !p.isCompleted) p.complete();
    });
    return const QuizState();
  }

  /// Pide el quiz al modelo y va mostrando cada pregunta en cuanto esta lista
  /// (un 3B tarda ~40 s por pregunta: el nino no espera a las tres). Si no sale
  /// ninguna se reintenta una vez.
  Future<void> start({required int grade}) async {
    state = const QuizState();
    try {
      final chunks = await ref.read(tutorControllerProvider.notifier).quizChunks(grade);
      if (_closed) return;
      if (chunks.isEmpty) {
        state = const QuizState(status: QuizStatus.failed, message: needsTopic);
        return;
      }
      final turns = QuizPrompt.build(grade: grade, chunks: chunks);
      _bookText = chunks.map((c) => c.text).join(' ');
      for (var attempt = 0; attempt < 2 && state.questions.isEmpty; attempt++) {
        await _generate(turns);
        if (_closed) return;
      }
      if (state.questions.isEmpty) {
        state = const QuizState(status: QuizStatus.failed, message: unavailable);
        return;
      }
      state = state.copyWith(expecting: false);
      // Si el nino ya contesto todas las que habia, ahora puede seguir (o acabar).
      if (state.status == QuizStatus.waiting) _advance();
    } catch (_) {
      if (_closed) return;
      if (state.questions.isEmpty) {
        state = const QuizState(status: QuizStatus.failed, message: unavailable);
      } else {
        state = state.copyWith(expecting: false);
        if (state.status == QuizStatus.waiting) _advance();
      }
    }
  }

  /// Escribe el quiz leyendo lo que va llegando. Para en cuanto hay 3 preguntas.
  Future<void> _generate(List<ChatTurn> turns) {
    final engine = ref.read(tutorEngineProvider);
    final done = Completer<void>();
    final buf = StringBuffer();
    _pending = done;
    state = state.copyWith(expecting: true);

    void finish() {
      if (!done.isCompleted) done.complete();
    }

    _sub = engine
        .generate(turns, maxTokens: QuizPrompt.maxTokens)
        .listen(
          (piece) {
            buf.write(piece);
            final parsed = [
              for (final q in QuizParser.parse(buf.toString()))
                if (QuizGrounding.isGrounded(q, _bookText)) q,
            ];
            for (
              var i = state.questions.length;
              i < parsed.length && i < QuizPrompt.questions;
              i++
            ) {
              _add(parsed[i].shuffled(ref.read(quizRandomProvider)));
            }
            if (state.questions.length >= QuizPrompt.questions) {
              _sub?.cancel();
              finish();
            }
          },
          onError: (Object e) {
            if (!done.isCompleted) done.completeError(e);
          },
          onDone: finish,
          cancelOnError: true,
        );
    return done.future;
  }

  /// Llega una pregunta nueva: la primera abre el quiz; si el nino estaba
  /// esperando, sigue con esta.
  void _add(QuizQuestion q) {
    final questions = [...state.questions, q];
    state = state.copyWith(questions: questions);
    if (questions.length == 1) {
      state = state.copyWith(status: QuizStatus.asking);
    } else if (state.status == QuizStatus.waiting) {
      _advance();
    }
  }

  void _advance() {
    if (state.index + 1 < state.questions.length) {
      state = state.copyWith(status: QuizStatus.asking, index: state.index + 1, picked: null);
    } else if (!state.expecting) {
      _finish();
    }
  }

  /// El nino elige la opcion [option] de la pregunta actual.
  void answer(int option) {
    final q = state.question;
    if (state.status != QuizStatus.asking || q == null) return;
    state = state.copyWith(
      status: QuizStatus.answered,
      picked: option,
      correct: state.correct + (option == q.correct ? 1 : 0),
    );
  }

  /// Pasa a la siguiente pregunta o, tras la ultima, termina y anota los logros.
  void next() {
    if (state.status != QuizStatus.answered) return;
    if (state.index + 1 < state.questions.length) {
      _advance();
    } else if (state.expecting) {
      // El modelo aun escribe la siguiente.
      state = state.copyWith(status: QuizStatus.waiting);
    } else {
      _finish();
    }
  }

  void _finish() {
    state = state.copyWith(status: QuizStatus.finished);
    final child = ref.read(sessionProvider).activeChildId;
    if (child != null) {
      unawaited(
        ref
            .read(achievementServiceProvider)
            .quizFinished(child, correct: state.correct, total: state.questions.length),
      );
    }
  }
}

final quizControllerProvider = NotifierProvider.autoDispose<QuizController, QuizState>(
  QuizController.new,
);
