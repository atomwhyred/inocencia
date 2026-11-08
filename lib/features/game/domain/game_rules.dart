import 'package:equatable/equatable.dart';

/// Carrera (gana quien llega antes a la meta) o Entre todos (cooperativo).
enum GameMode { race, team }

/// Un nino en la partida. [id] es unico en la partida; [childId] solo existe para
/// los ninos de este telefono (a ellos se les guardan las estrellas).
class GamePlayer extends Equatable {
  const GamePlayer({
    required this.id,
    required this.name,
    required this.avatar,
    required this.grade,
    required this.color,
    this.childId,
  });

  final String id;
  final String name;

  /// `emoji:<caracter>` o `photo:<ruta>` (en red, las fotos llegan como `jpeg:<base64>`).
  final String avatar;
  final int grade;

  /// Indice en la paleta de carriles ([GameRules.laneColors]).
  final int color;
  final int? childId;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'grade': grade,
    'color': color,
  };

  factory GamePlayer.fromJson(Map<String, Object?> j) => GamePlayer(
    id: j['id']! as String,
    name: j['name']! as String,
    avatar: j['avatar']! as String,
    grade: j['grade']! as int,
    color: j['color']! as int,
  );

  @override
  List<Object?> get props => [id, name, avatar, grade, color, childId];
}

/// Lo que paso con la respuesta de un jugador en una ronda.
class AnswerResult extends Equatable {
  const AnswerResult({
    required this.playerId,
    required this.correct,
    this.points = 1,
    this.millis,
  });

  final String playerId;
  final bool correct;

  /// Lo que vale si acierta (2 si es una tarjeta propia).
  final int points;

  /// Lo que tardo (solo para mostrarlo).
  final int? millis;

  int get gained => correct ? points : 0;

  @override
  List<Object?> get props => [playerId, correct, points, millis];
}

/// Estado de la partida. Inmutable: [GameRules] devuelve uno nuevo en cada paso.
class GameState extends Equatable {
  const GameState({
    required this.mode,
    required this.players,
    this.positions = const {},
    this.teamProgress = 0,
    this.round = 1,
    this.answered = const {},
    this.finished = false,
    this.winners = const [],
    this.lastResults = const [],
  });

  final GameMode mode;
  final List<GamePlayer> players;

  /// Casillas avanzadas por cada jugador (carrera) o aciertos de cada uno (equipo).
  final Map<String, int> positions;

  /// Aciertos sumados entre todos (modo equipo).
  final int teamProgress;
  final int round;

  /// Quien ya respondio en la ronda actual.
  final Set<String> answered;
  final bool finished;

  /// Ganadores de la carrera (varios si empatan). En equipo: todos si llegaron.
  final List<String> winners;

  /// Resultados de la ultima ronda cerrada (para las animaciones).
  final List<AnswerResult> lastResults;

  int positionOf(String id) => positions[id] ?? 0;
  int get teamGoal => GameRules.teamGoal(players.length);
  bool get teamWon =>
      mode == GameMode.team && finished && teamProgress >= teamGoal;
  bool get roundComplete => players.every((p) => answered.contains(p.id));

  /// Jugadores ordenados de mas a menos avanzado (para el podio).
  List<GamePlayer> get ranking =>
      [...players]
        ..sort((a, b) => positionOf(b.id).compareTo(positionOf(a.id)));

  GameState copyWith({
    List<GamePlayer>? players,
    Map<String, int>? positions,
    int? teamProgress,
    int? round,
    Set<String>? answered,
    bool? finished,
    List<String>? winners,
    List<AnswerResult>? lastResults,
  }) => GameState(
    mode: mode,
    players: players ?? this.players,
    positions: positions ?? this.positions,
    teamProgress: teamProgress ?? this.teamProgress,
    round: round ?? this.round,
    answered: answered ?? this.answered,
    finished: finished ?? this.finished,
    winners: winners ?? this.winners,
    lastResults: lastResults ?? this.lastResults,
  );

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'players': [for (final p in players) p.toJson()],
    'positions': positions,
    'teamProgress': teamProgress,
    'round': round,
    'answered': answered.toList(),
    'finished': finished,
    'winners': winners,
  };

  factory GameState.fromJson(Map<String, Object?> j) => GameState(
    mode: GameMode.values.byName(j['mode']! as String),
    players: [
      for (final p in j['players']! as List)
        GamePlayer.fromJson((p as Map).cast<String, Object?>()),
    ],
    positions: (j['positions']! as Map).map(
      (k, v) => MapEntry(k as String, v as int),
    ),
    teamProgress: j['teamProgress']! as int,
    round: j['round']! as int,
    answered: {for (final a in j['answered']! as List) a as String},
    finished: j['finished']! as bool,
    winners: [for (final w in j['winners']! as List) w as String],
  );

  @override
  List<Object?> get props => [
    mode,
    players,
    positions,
    teamProgress,
    round,
    answered,
    finished,
    winners,
    lastResults,
  ];
}

/// Reglas de "Carrera de tocororos" y "Entre todos".
///
/// Cada nino responde preguntas de SU grado: por eso se puede jugar entre grados.
/// En cada ronda responden todos (por turnos en un telefono, a la vez en red) y la
/// partida solo termina al cerrar una ronda, asi todos tienen las mismas preguntas.
class GameRules {
  const GameRules._();

  /// Casillas de la carrera.
  static const raceLength = 10;

  /// Si nadie llega, la carrera termina aqui y gana quien va delante.
  static const maxRaceRounds = 15;

  /// Rondas del modo equipo.
  static const maxTeamRounds = 10;

  static const minPlayers = 2;
  static const maxLocalPlayers = 4;
  static const maxLanPlayers = 6;

  /// Aciertos entre todos para que Toco llegue a su nido.
  static int teamGoal(int players) => 6 * players;

  /// Tiempo para responder: los pequenos leen mas despacio.
  static Duration timeFor(int grade) =>
      grade <= 2 ? const Duration(seconds: 35) : const Duration(seconds: 25);

  /// Colores de los carriles (indices de [GamePlayer.color]).
  static const laneColors = [
    0xFF0035AD,
    0xFFDC241F,
    0xFF2E7D32,
    0xFFF9A825,
    0xFF6A1B9A,
    0xFF00838F,
  ];

  static GameState start(GameMode mode, List<GamePlayer> players) {
    if (players.length < minPlayers) {
      throw ArgumentError('Hacen falta al menos $minPlayers jugadores');
    }
    return GameState(
      mode: mode,
      players: players,
      positions: {for (final p in players) p.id: 0},
    );
  }

  /// Anota la respuesta de un jugador. Una segunda respuesta en la misma ronda se ignora.
  static GameState answer(GameState s, AnswerResult r) {
    if (s.finished || s.answered.contains(r.playerId)) return s;
    if (!s.players.any((p) => p.id == r.playerId)) return s;
    final positions = {...s.positions};
    var pos = (positions[r.playerId] ?? 0) + r.gained;
    if (s.mode == GameMode.race && pos > raceLength) pos = raceLength;
    positions[r.playerId] = pos;
    return s.copyWith(
      positions: positions,
      teamProgress: s.teamProgress + (s.mode == GameMode.team ? r.gained : 0),
      answered: {...s.answered, r.playerId},
      lastResults: [...s.lastResults.where((x) => x.playerId != r.playerId), r],
    );
  }

  /// Un jugador se fue (red): deja de contar para cerrar la ronda.
  static GameState removePlayer(GameState s, String id) {
    final players = s.players.where((p) => p.id != id).toList();
    if (players.length == s.players.length) return s;
    final next = s.copyWith(
      players: players,
      positions: {...s.positions}..remove(id),
      answered: {...s.answered}..remove(id),
    );
    if (!next.finished && players.length < minPlayers) {
      return next.copyWith(
        finished: true,
        winners: [for (final p in players) p.id],
      );
    }
    return next;
  }

  /// Cierra la ronda (todos respondieron o se acabo el tiempo): decide si termina.
  static GameState closeRound(GameState s) {
    if (s.finished) return s;
    if (s.mode == GameMode.race) {
      final best = s.players
          .map((p) => s.positionOf(p.id))
          .fold<int>(0, (a, b) => a > b ? a : b);
      if (best >= raceLength || s.round >= maxRaceRounds) {
        return s.copyWith(
          finished: true,
          winners: [
            for (final p in s.players)
              if (s.positionOf(p.id) == best && best > 0) p.id,
          ],
        );
      }
    } else {
      if (s.teamProgress >= s.teamGoal) {
        return s.copyWith(
          finished: true,
          winners: [for (final p in s.players) p.id],
        );
      }
      if (s.round >= maxTeamRounds) {
        return s.copyWith(finished: true, winners: const []);
      }
    }
    return s.copyWith(
      round: s.round + 1,
      answered: const {},
      lastResults: const [],
    );
  }

  /// Estrellas para un nino al acabar: 1 por jugar, +1 por cada 3 aciertos, +2 si gana.
  static int starsFor(GameState s, String playerId) {
    final hits = s.positionOf(playerId);
    final won = s.mode == GameMode.race
        ? s.winners.contains(playerId)
        : s.teamWon;
    return 1 + hits ~/ 3 + (won ? 2 : 0);
  }
}
