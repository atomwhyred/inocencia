import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/game_rules.dart';
import '../../domain/lan_protocol.dart';

/// Invitado en una partida en red: se presenta, recibe la sala y las rondas, y
/// envía sus respuestas.
class LanClient {
  LanClient._(this._socket);

  final Socket _socket;
  final _events = StreamController<LanEvent>.broadcast();
  String? _id;
  GameState? _game;
  var _closed = false;

  Stream<LanEvent> get events => _events.stream;
  String? get playerId => _id;
  GameState? get game => _game;

  /// Se conecta y se presenta. Los eventos llegan por [events] (el primero,
  /// [LanJoined] o [LanClosed] si el anfitrión lo rechaza).
  static Future<LanClient> connect(
    String host, {
    int port = LanProtocol.tcpPort,
    required String name,
    required String avatar,
    required int grade,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.setOption(SocketOption.tcpNoDelay, true);
    socket.done.catchError((_) {});
    final c = LanClient._(socket);
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          c._onLine,
          onDone: () => c._lost('La sala se cerró.'),
          onError: (_) => c._lost('Se perdió la conexión.'),
        );
    socket.write(
      LanProtocol.encode('hello', {
        'player': {'name': name, 'avatar': avatar, 'grade': grade},
      }),
    );
    return c;
  }

  void _onLine(String line) {
    final m = LanProtocol.decode(line);
    if (m == null) return;
    try {
      switch (m['t']) {
        case 'welcome':
          _id = m['id']! as String;
          _emit(LanJoined(_id!, GameMode.values.byName(m['mode']! as String)));
        case 'reject':
          _lost(m['reason'] as String? ?? 'No se pudo entrar en la sala.');
        case 'lobby':
          _emit(
            LanLobby([
              for (final p in m['players']! as List)
                GamePlayer.fromJson((p as Map).cast<String, Object?>()),
            ]),
          );
        case 'start':
          _game = _state(m);
          _emit(LanState(_game!));
        case 'round':
          _game = _state(m);
          _emit(LanRound(m['round']! as int, _game!));
        case 'state':
          _game = _state(m);
          _emit(LanState(_game!));
        case 'end':
          _game = _state(m);
          _emit(LanEnded(_game!));
      }
    } catch (_) {
      // Mensaje con un formato inesperado: se ignora.
    }
  }

  static GameState _state(Map<String, Object?> m) =>
      GameState.fromJson((m['state']! as Map).cast<String, Object?>());

  void sendResult({
    required int round,
    required bool correct,
    required int points,
    int? millis,
  }) {
    if (_closed) return;
    try {
      _socket.write(
        LanProtocol.encode('result', {
          'round': round,
          'correct': correct,
          'points': points,
          'ms': millis,
        }),
      );
    } catch (_) {}
  }

  void _lost(String reason) {
    if (_closed) return;
    // Al terminar la partida el anfitrión cierra: no es un error.
    if (_game?.finished != true) _emit(LanClosed(reason));
    close();
  }

  void _emit(LanEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _socket.destroy();
    await _events.close();
  }
}

/// Escucha los avisos UDP de las salas cercanas.
class LanDiscovery {
  LanDiscovery._(this._socket);

  final RawDatagramSocket _socket;

  static Future<LanDiscovery?> start() async {
    try {
      final s = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        LanProtocol.udpPort,
        reuseAddress: true,
      );
      return LanDiscovery._(s);
    } catch (_) {
      return null;
    }
  }

  /// Salas que se anuncian (una entrada por aviso; la pantalla las agrupa por IP).
  Stream<RoomBeacon> get rooms => _socket
      .where((e) => e == RawSocketEvent.read)
      .map((_) => _socket.receive())
      .where((d) => d != null)
      .map((d) {
        final m = LanProtocol.decode(
          utf8.decode(d!.data, allowMalformed: true).trim(),
        );
        return m == null ? null : RoomBeacon.fromMessage(m, d.address.address);
      })
      .where((r) => r != null)
      .cast<RoomBeacon>();

  void close() => _socket.close();
}
