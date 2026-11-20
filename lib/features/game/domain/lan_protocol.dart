import 'dart:convert';
import 'dart:math';

import 'game_rules.dart';
import 'net_sanitize.dart';

/// Mensajes del juego en red: JSON de una linea por mensaje, con versión.
///
/// Invitado → anfitrion: `hello{code, player}`, `result{round, correct, points, ms}`.
/// Anfitrion → invitado: `welcome{id, color, mode}`, `reject{reason}`,
/// `lobby{players}`, `start{state}`, `round{round}`, `state{state}`, `end{state}`.
/// Aviso de sala por UDP: `room{name, grade, mode, players, port}`. El nombre es el de
/// la sala ("Sala del Sinsonte"), nunca el del niño: el aviso lo oye todo el Wi-Fi.
///
/// Versión 2: código de sala de 4 cifras (lo muestra el anfitrión y lo escribe quien
/// entra) y aviso sin el nombre del niño.
class LanProtocol {
  const LanProtocol._();

  static const version = 2;
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

  /// Código de sala: 4 cifras al azar (seguro), sin ceros a la izquierda para que se
  /// lea bien en voz alta.
  static String newRoomCode([Random? random]) =>
      (1000 + (random ?? Random.secure()).nextInt(9000)).toString();

  static bool isRoomCode(Object? code) =>
      code is String && RegExp(r'^[0-9]{4}$').hasMatch(code);

  /// Nombre de la sala para el aviso: un ave cubana al azar.
  static String newRoomName([Random? random]) =>
      'Sala ${roomBirds[(random ?? Random.secure()).nextInt(roomBirds.length)]}';

  static const roomBirds = [
    'del Tocororo',
    'del Sinsonte',
    'del Zunzún',
    'del Tomeguín',
    'del Cartacuba',
    'del Negrito',
    'del Totí',
    'de la Cotorra',
    'del Pitirre',
    'del Carpintero',
    'de la Paloma',
    'del Colibrí',
  ];
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

  /// Nombre de la sala ("Sala del Sinsonte") y grado del niño que la creó.
  final String name;
  final int grade;
  final GameMode mode;
  final int players;

  static RoomBeacon? fromMessage(Map<String, Object?> m, String host) {
    try {
      if (m['t'] != 'room' || !LanProtocol.compatible(m)) return null;
      return RoomBeacon(
        host: host,
        port: NetSanitize.intIn(m['port'], 1, 65535, LanProtocol.tcpPort),
        name: NetSanitize.text(m['name'], 28, fallback: 'Sala'),
        grade: NetSanitize.intIn(m['grade'], 1, 6, 1),
        mode: GameMode.values.byName(m['mode']! as String),
        players: NetSanitize.intIn(m['players'], 0, GameRules.maxLanPlayers, 0),
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
