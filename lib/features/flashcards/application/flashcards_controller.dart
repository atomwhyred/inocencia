import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../auth/application/session.dart';
import '../../tutor/application/tutor_controller.dart';
import 'flashcard_providers.dart';

enum FlashcardsGenStatus { idle, generating, done, failed }

class FlashcardsGenState extends Equatable {
  const FlashcardsGenState({this.status = FlashcardsGenStatus.idle, this.added = 0, this.message});

  final FlashcardsGenStatus status;

  /// Tarjetas nuevas guardadas en esta tanda.
  final int added;
  final String? message;

  bool get generating => status == FlashcardsGenStatus.generating;

  @override
  List<Object?> get props => [status, added, message];
}

/// Pide al modelo local tarjetas del tema que el nino consulta y las va
/// guardando segun llegan (el mazo se actualiza solo).
class FlashcardsController extends Notifier<FlashcardsGenState> {
  StreamSubscription<int>? _sub;
  Completer<void>? _pending;
  bool _closed = false;

  static const unavailable =
      'No pude preparar las tarjetas. ¡Pregúntame otra cosa y lo intentamos luego!';
  static const needsTopic = 'Pregúntame algo primero y después creo tarjetas sobre eso.';

  @override
  FlashcardsGenState build() {
    ref.onDispose(() {
      _closed = true;
      _sub?.cancel();
      final p = _pending;
      if (p != null && !p.isCompleted) p.complete();
    });
    return const FlashcardsGenState();
  }

  Future<void> generate({required int grade}) async {
    if (state.generating) return;
    state = const FlashcardsGenState(status: FlashcardsGenStatus.generating);
    try {
      final chunks = await ref.read(tutorControllerProvider.notifier).quizChunks(grade);
      if (_closed) return;
      final childId = ref.read(sessionProvider).activeChildId;
      if (chunks.isEmpty || childId == null) {
        state = const FlashcardsGenState(status: FlashcardsGenStatus.failed, message: needsTopic);
        return;
      }
      final repo = ref.read(flashcardRepositoryProvider);
      final clock = ref.read(clockProvider);
      final done = Completer<void>();
      _pending = done;
      var added = 0;
      _sub = ref
          .read(flashcardGeneratorProvider)
          .generate(grade: grade, chunks: chunks)
          .asyncMap((draft) => repo.addAll(childId, [draft], clock()))
          .listen(
            (n) {
              added += n;
              if (!_closed) {
                state = FlashcardsGenState(status: FlashcardsGenStatus.generating, added: added);
              }
            },
            onError: (Object e) {
              if (!done.isCompleted) done.completeError(e);
            },
            onDone: () {
              if (!done.isCompleted) done.complete();
            },
            cancelOnError: true,
          );
      await done.future;
      if (_closed) return;
      state = added > 0
          ? FlashcardsGenState(status: FlashcardsGenStatus.done, added: added)
          : const FlashcardsGenState(status: FlashcardsGenStatus.failed, message: unavailable);
    } catch (_) {
      if (_closed) return;
      state = FlashcardsGenState(
        status: state.added > 0 ? FlashcardsGenStatus.done : FlashcardsGenStatus.failed,
        added: state.added,
        message: state.added > 0 ? null : unavailable,
      );
    }
  }

  /// Para la generacion (las tarjetas ya guardadas se quedan).
  void stop() {
    _sub?.cancel();
    final p = _pending;
    if (p != null && !p.isCompleted) p.complete();
    if (state.generating) {
      state = FlashcardsGenState(
        status: state.added > 0 ? FlashcardsGenStatus.done : FlashcardsGenStatus.idle,
        added: state.added,
      );
    }
  }
}

final flashcardsControllerProvider =
    NotifierProvider.autoDispose<FlashcardsController, FlashcardsGenState>(
      FlashcardsController.new,
    );
