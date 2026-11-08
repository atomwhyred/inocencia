import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/utils/school_grade_calculator.dart';
import '../../achievements/application/achievement_service.dart';
import '../../profiles/domain/child_profile.dart';
import '../domain/game_question.dart';
import '../domain/game_rules.dart';
import 'game_providers.dart';

enum LocalPhase {
  /// Preparando las preguntas de cada nino.
  loading,

  /// "Pasa el telefono a Ana": nadie ve la pregunta del otro.
  handOff,

  /// Pregunta en pantalla, con el reloj corriendo.
  asking,

  /// Ya respondio (o se acabo el tiempo): se ve si acerto.
  reveal,
  finished,

  /// Alguien no tiene preguntas.
  failed,
}

class LocalGameView extends Equatable {
  const LocalGameView({
    this.phase = LocalPhase.loading,
    this.game,
    this.turn = 0,
    this.question,
    this.picked,
    this.deadline,
    this.message,
    this.stars = const {},
  });

  final LocalPhase phase;
  final GameState? game;

  /// Indice en `game.players` de quien juega ahora.
  final int turn;
  final GameQuestion? question;

  /// Opcion elegida; -1 si se acabo el tiempo.
  final int? picked;
  final DateTime? deadline;
  final String? message;

  /// Estrellas ganadas por cada jugador al terminar.
  final Map<String, int> stars;

  GamePlayer? get player =>
      game == null || turn >= game!.players.length ? null : game!.players[turn];
  bool get wasCorrect => question != null && picked == question!.quiz.correct;

  LocalGameView copyWith({
    LocalPhase? phase,
    GameState? game,
    int? turn,
    GameQuestion? question,
    int? picked,
    bool clearPicked = false,
    DateTime? deadline,
    String? message,
    Map<String, int>? stars,
  }) => LocalGameView(
    phase: phase ?? this.phase,
    game: game ?? this.game,
    turn: turn ?? this.turn,
    question: question ?? this.question,
    picked: clearPicked ? null : (picked ?? this.picked),
    deadline: deadline ?? this.deadline,
    message: message ?? this.message,
    stars: stars ?? this.stars,
  );

  @override
  List<Object?> get props => [
    phase,
    game,
    turn,
    question,
    picked,
    deadline,
    message,
    stars,
  ];
}

/// Partida en un solo telefono: los ninos se lo pasan por turnos. Cada uno
/// responde preguntas de su grado (banco del libro y sus tarjetas).
class LocalGameController extends Notifier<LocalGameView> {
  final _decks = <String, QuestionDeck>{};
  Timer? _timer;

  @override
  LocalGameView build() {
    ref.onDispose(() => _timer?.cancel());
    return const LocalGameView();
  }

  static String playerId(ChildProfile c) => 'c${c.id}';

  Future<void> start(GameMode mode, List<ChildProfile> kids) async {
    _timer?.cancel();
    _decks.clear();
    state = const LocalGameView();
    final now = ref.read(clockProvider)();
    final players = <GamePlayer>[];
    for (var i = 0; i < kids.length; i++) {
      final k = kids[i];
      final grade = k.gradeAt(now);
      players.add(
        GamePlayer(
          id: playerId(k),
          name: k.name,
          avatar: k.avatar,
          grade: grade,
          color: i,
          childId: k.id,
        ),
      );
      final deck = await ref
          .read(gameDeckBuilderProvider)
          .build(grade: grade, childId: k.id);
      if (!ref.mounted) return;
      if (deck.isEmpty) {
        state = LocalGameView(
          phase: LocalPhase.failed,
          message:
              '${k.name} (${SchoolGradeCalculator.label(grade)}) no tiene preguntas para jugar: '
              'pide a un adulto que copie la base de libros con el banco del juego, '
              'o crea al menos 3 tarjetas desde el tutor.',
        );
        return;
      }
      _decks[players.last.id] = deck;
    }
    state = LocalGameView(
      phase: LocalPhase.handOff,
      game: GameRules.start(mode, players),
    );
  }

  /// El nino tiene el telefono: se muestra su pregunta y empieza su tiempo.
  void ready() {
    final player = state.player;
    if (state.phase != LocalPhase.handOff || player == null) return;
    final limit = GameRules.timeFor(player.grade);
    state = state.copyWith(
      phase: LocalPhase.asking,
      question: _decks[player.id]!.next(),
      clearPicked: true,
      deadline: ref.read(clockProvider)().add(limit),
    );
    _timer?.cancel();
    _timer = Timer(limit, () => pick(-1));
  }

  void pick(int option) {
    final player = state.player;
    final q = state.question;
    if (state.phase != LocalPhase.asking || player == null || q == null) return;
    _timer?.cancel();
    final game = GameRules.answer(
      state.game!,
      AnswerResult(
        playerId: player.id,
        correct: option == q.quiz.correct,
        points: q.points,
      ),
    );
    state = state.copyWith(
      phase: LocalPhase.reveal,
      picked: option,
      game: game,
    );
  }

  /// Siguiente turno; al cerrar la ronda decide si la partida termino.
  Future<void> next() async {
    if (state.phase != LocalPhase.reveal) return;
    var game = state.game!;
    var turn = state.turn + 1;
    if (game.roundComplete) {
      game = GameRules.closeRound(game);
      turn = 0;
    }
    if (game.finished) {
      final stars = {
        for (final p in game.players) p.id: GameRules.starsFor(game, p.id),
      };
      state = state.copyWith(
        phase: LocalPhase.finished,
        game: game,
        stars: stars,
      );
      final medals = ref.read(achievementServiceProvider);
      for (final p in game.players) {
        if (p.childId != null) {
          await medals.gameFinished(p.childId!, stars: stars[p.id]!);
        }
      }
      return;
    }
    state = state.copyWith(
      phase: LocalPhase.handOff,
      game: game,
      turn: turn,
      clearPicked: true,
    );
  }
}

final localGameProvider =
    NotifierProvider.autoDispose<LocalGameController, LocalGameView>(
      LocalGameController.new,
    );
