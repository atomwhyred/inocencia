import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../domain/flashcard.dart';
import 'flashcard_providers.dart';

class StudyState extends Equatable {
  const StudyState({
    this.queue = const [],
    this.flipped = false,
    this.total = 0,
    this.knownFirstTry = 0,
  });

  /// Tarjetas por repasar; la primera es la que se ve.
  final List<Flashcard> queue;
  final bool flipped;
  final int total;

  /// Tarjetas que dijo saber a la primera.
  final int knownFirstTry;

  Flashcard? get current => queue.isEmpty ? null : queue.first;
  bool get finished => total > 0 && queue.isEmpty;

  StudyState copyWith({List<Flashcard>? queue, bool? flipped, int? knownFirstTry}) => StudyState(
    queue: queue ?? this.queue,
    flipped: flipped ?? this.flipped,
    total: total,
    knownFirstTry: knownFirstTry ?? this.knownFirstTry,
  );

  @override
  List<Object?> get props => [queue, flipped, total, knownFirstTry];
}

/// Una ronda de repaso: se voltea la tarjeta y el nino dice si la sabia. Las que
/// falla vuelven al final (como mucho dos veces, para no desanimarlo).
class StudyController extends Notifier<StudyState> {
  static const maxRetries = 2;

  final _missed = <int, int>{};

  @override
  StudyState build() => const StudyState();

  void start(List<Flashcard> deck) {
    _missed.clear();
    final queue = [...deck]..shuffle(ref.read(flashcardRandomProvider));
    state = StudyState(queue: queue, total: queue.length);
  }

  void flip() {
    if (state.current == null) return;
    state = state.copyWith(flipped: !state.flipped);
  }

  /// El nino dice si sabia la tarjeta de la que ve el reverso.
  void answer({required bool known}) {
    final card = state.current;
    if (card == null || !state.flipped) return;
    unawaited(
      ref
          .read(flashcardRepositoryProvider)
          .markReviewed(card.id, known: known, at: ref.read(clockProvider)()),
    );
    final queue = [...state.queue]..removeAt(0);
    var knownFirstTry = state.knownFirstTry;
    if (known) {
      if (!_missed.containsKey(card.id)) knownFirstTry++;
    } else {
      final misses = (_missed[card.id] ?? 0) + 1;
      _missed[card.id] = misses;
      if (misses <= maxRetries) queue.add(card);
    }
    state = state.copyWith(queue: queue, flipped: false, knownFirstTry: knownFirstTry);
  }
}

final studyControllerProvider = NotifierProvider.autoDispose<StudyController, StudyState>(
  StudyController.new,
);
