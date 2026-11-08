import 'dart:convert';

import 'game_rules.dart';

/// Mensajes del juego en red: JSON de una linea por mensaje, con versión.
///
/// Invitado → anfitrion: `hello{player}`, `result{round, correct, points, ms}`.
/// Anfitrion → invitado: `welcome{id, color, mode}`, `reject{reason}`,
/// `lobby{players}`, `start{state}`, `round{round}`, `state{state}`, `end{state}`.
/// Aviso de sala por UDP: `room{name, grade, mode, players, port}`.
class LanProtocol {
  const LanProtocol._();

  static const version = 1;
  static const tcpPort = 47321;
  static const udpPort = 47320;

  static String encode(String type, [Map<String, Object?> data = const {}]) =>
      '${jsonEncode({'t': type, 'v': version, ...data})}\n';

  /// `null` si la linea no es un mensaje valido (se ignora sin romper la partida).
  static Map<String, Object?>? decode(String line) {
    try {
      final m = jsonDecode(line);
      if (m is Map<String, Object?> && m['t'] is String && m['v'] is int) {
        return m;
      }
    } catch (_) {}
    return null;
  }

  static bool compatible(Map<String, Object?> m) => m['v'] == version;
}

/// Una sala anunciada en la red.
class RoomBeacon {
  const RoomBeacon({
    required this.host,
    required this.port,
    required this.name,
    required this.grade,
    required this.mode,
    required this.players,
  });

  final String host;
  final int port;

  /// Nombre y grado del niño que la creó.
  final String name;
  final int grade;
  final GameMode mode;
  final int players;

  static RoomBeacon? fromMessage(Map<String, Object?> m, String host) {
    try {
      if (m['t'] != 'room' || !LanProtocol.compatible(m)) return null;
      return RoomBeacon(
        host: host,
        port: m['port']! as int,
        name: m['name']! as String,
        grade: m['grade']! as int,
        mode: GameMode.values.byName(m['mode']! as String),
        players: m['players']! as int,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Lo que pasa en la partida en red, igual para el anfitrion y los invitados.
sealed class LanEvent {
  const LanEvent();
}

/// Ya estoy en la sala con este id.
class LanJoined extends LanEvent {
  const LanJoined(this.playerId, this.mode);
  final String playerId;
  final GameMode mode;
}

class LanLobby extends LanEvent {
  const LanLobby(this.players);
  final List<GamePlayer> players;
}

/// Empieza la ronda [round]: cada uno responde su pregunta.
class LanRound extends LanEvent {
  const LanRound(this.round, this.game);
  final int round;
  final GameState game;
}

/// Alguien respondió o se cerró la ronda.
class LanState extends LanEvent {
  const LanState(this.game);
  final GameState game;
}

class LanEnded extends LanEvent {
  const LanEnded(this.game);
  final GameState game;
}

/// Se cortó la conexión o nos rechazaron.
class LanClosed extends LanEvent {
  const LanClosed(this.reason);
  final String reason;
}
