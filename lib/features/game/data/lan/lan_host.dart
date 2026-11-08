import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/game_rules.dart';
import '../../domain/lan_protocol.dart';

/// Anfitrion de una partida en red: su propio niño juega (id `h`) y los demás se
/// conectan por TCP. Lleva el reloj y los puntos; cada teléfono pone sus preguntas.
class LanHost {
  LanHost({
    required GamePlayer self,
    required this.mode,
    this.port = LanProtocol.tcpPort,
    this.revealPause = const Duration(milliseconds: 2500),
    this.grace = const Duration(seconds: 4),
    this.announce = true,
  }) : _self = GamePlayer(
         id: hostId,
         name: self.name,
         avatar: self.avatar,
         grade: self.grade,
         color: 0,
         childId: self.childId,
       );

  static const hostId = 'h';

  final GameMode mode;
  final int port;

  /// Pausa entre rondas para ver avanzar a los tocororos.
  final Duration revealPause;

  /// Margen sobre el tiempo de la pregunta (lo que tarda en llegar la respuesta).
  final Duration grace;

  /// Anunciar la sala por UDP (desactivado en pruebas).
  final bool announce;

  final GamePlayer _self;
  final _events = StreamController<LanEvent>.broadcast();
  final _peers = <String, _Peer>{};
  ServerSocket? _server;
  RawDatagramSocket? _udp;
  Timer? _beacon;
  Timer? _roundTimer;
  Timer? _pause;
  GameState? _game;
  var _nextId = 1;
  var _closed = false;

  Stream<LanEvent> get events => _events.stream;
  GamePlayer get self => _self;
  GameState? get game => _game;
  int get boundPort => _server?.port ?? port;

  List<GamePlayer> get players => [
    _self,
    for (final p in _peers.values) ?p.player,
  ];

  /// Abre la sala. Devuelve el puerto (con `port: 0`, uno libre: pruebas).
  Future<int> open() async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_accept, onError: (_) {});
    if (announce) await _startBeacon();
    return _server!.port;
  }

  Future<void> _startBeacon() async {
    try {
      _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udp!.broadcastEnabled = true;
    } catch (_) {
      return; // sin difusión: los invitados escriben la IP
    }
    final targets = await broadcastTargets();
    _beacon = Timer.periodic(const Duration(seconds: 1), (_) {
      final msg = utf8.encode(
        LanProtocol.encode('room', {
          'name': _self.name,
          'grade': _self.grade,
          'mode': mode.name,
          'players': players.length,
          'port': boundPort,
        }),
      );
      for (final t in targets) {
        try {
          _udp?.send(msg, t, LanProtocol.udpPort);
        } catch (_) {}
      }
    });
  }

  /// 255.255.255.255 y la difusión de cada red /24 del teléfono (el punto de
  /// acceso de Android usa una /24).
  static Future<List<InternetAddress>> broadcastTargets() async {
    final out = [InternetAddress('255.255.255.255')];
    for (final ip in await localAddresses()) {
      final parts = ip.split('.');
      out.add(InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'));
    }
    return out;
  }

  /// IPv4 del teléfono en la red local (lo que se muestra para conectarse a mano).
  static Future<List<String>> localAddresses() async {
    try {
      final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4);
      return [
        for (final i in ifs)
          for (final a in i.addresses)
            if (!a.isLoopback && !a.address.startsWith('169.254.')) a.address,
      ];
    } catch (_) {
      return const [];
    }
  }

  void _accept(Socket socket) {
    // Un invitado que se va a mitad de un envío no es un error del anfitrión.
    socket.done.catchError((_) {});
    final peer = _Peer(socket);
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => _onLine(peer, line),
          onDone: () => _drop(peer),
          onError: (_) => _drop(peer),
        );
  }

  void _onLine(_Peer peer, String line) {
    final m = LanProtocol.decode(line);
    if (m == null) return;
    switch (m['t']) {
      case 'hello':
        _hello(peer, m);
      case 'result':
        final id = peer.player?.id;
        if (id == null || m['round'] != _game?.round) return;
        submit(
          AnswerResult(
            playerId: id,
            correct: m['correct'] == true,
            points: (m['points'] as int?)?.clamp(1, 2) ?? 1,
            millis: m['ms'] as int?,
          ),
        );
    }
  }

  void _hello(_Peer peer, Map<String, Object?> m) {
    String? reason;
    if (!LanProtocol.compatible(m)) {
      reason = 'Tu inocencIA y la del anfitrión son de versiones distintas: actualizad las dos.';
    } else if (_game != null) {
      reason = 'La partida ya empezó.';
    } else if (players.length >= GameRules.maxLanPlayers) {
      reason = 'La sala está llena.';
    }
    if (reason != null) {
      peer.send('reject', {'reason': reason});
      peer.socket.destroy();
      return;
    }
    try {
      final p = (m['player']! as Map).cast<String, Object?>();
      final id = 'p${_nextId++}';
      peer.player = GamePlayer(
        id: id,
        name: (p['name']! as String).trim().characters(24),
        avatar: p['avatar']! as String,
        grade: p['grade']! as int,
        color: _nextColor(),
      );
      _peers[id] = peer;
      peer.send('welcome', {
        'id': id,
        'color': peer.player!.color,
        'mode': mode.name,
      });
      _lobby();
    } catch (_) {
      peer.socket.destroy();
    }
  }

  int _nextColor() {
    final used = players.map((p) => p.color).toSet();
    for (var c = 0; c < GameRules.laneColors.length; c++) {
      if (!used.contains(c)) return c;
    }
    return players.length % GameRules.laneColors.length;
  }

  void _drop(_Peer peer) {
    final id = peer.player?.id;
    if (_closed || id == null || _peers.remove(id) == null) return;
    final g = _game;
    if (g == null) {
      _lobby();
      return;
    }
    _game = GameRules.removePlayer(g, id);
    _broadcastState();
    if (_game!.finished) {
      _finish();
    } else if (_game!.roundComplete) {
      _closeRound();
    }
  }

  void _lobby() {
    final ps = players;
    _broadcast('lobby', {
      'players': [for (final p in ps) p.toJson()],
    });
    _emit(LanLobby(ps));
  }

  /// Empieza la partida con quien esté en la sala.
  void start() {
    if (_game != null || players.length < GameRules.minPlayers) return;
    _beacon?.cancel();
    _game = GameRules.start(mode, players);
    _broadcast('start', {'state': _game!.toJson()});
    _startRound();
  }

  void _startRound() {
    final g = _game!;
    _broadcast('round', {'round': g.round, 'state': g.toJson()});
    _emit(LanRound(g.round, g));
    final longest = g.players
        .map((p) => GameRules.timeFor(p.grade))
        .reduce((a, b) => a > b ? a : b);
    _roundTimer?.cancel();
    _roundTimer = Timer(longest + grace, () {
      // Quien no respondió a tiempo, falló.
      var s = _game!;
      for (final p in s.players) {
        if (!s.answered.contains(p.id)) {
          s = GameRules.answer(s, AnswerResult(playerId: p.id, correct: false));
        }
      }
      _game = s;
      _closeRound();
    });
  }

  /// Respuesta de un jugador (la del niño del anfitrión llega por aquí directamente).
  void submit(AnswerResult r) {
    final g = _game;
    if (g == null || g.finished) return;
    final next = GameRules.answer(g, r);
    if (identical(next, g)) return;
    _game = next;
    _broadcastState();
    if (next.roundComplete) _closeRound();
  }

  void _closeRound() {
    _roundTimer?.cancel();
    final before = _game!;
    _game = GameRules.closeRound(before);
    // Se envían los resultados de la ronda para animarlos aunque la siguiente los vacíe.
    _broadcastState(withResults: before.lastResults);
    if (_game!.finished) {
      _finish();
      return;
    }
    _pause?.cancel();
    _pause = Timer(revealPause, _startRound);
  }

  void _finish() {
    _roundTimer?.cancel();
    _pause?.cancel();
    _broadcast('end', {'state': _game!.toJson()});
    _emit(LanEnded(_game!));
  }

  void _broadcastState({List<AnswerResult>? withResults}) {
    final g = _game!;
    _broadcast('state', {'state': g.toJson()});
    _emit(
      LanState(withResults == null ? g : g.copyWith(lastResults: withResults)),
    );
  }

  void _broadcast(String type, Map<String, Object?> data) {
    for (final p in _peers.values) {
      p.send(type, data);
    }
  }

  void _emit(LanEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _beacon?.cancel();
    _roundTimer?.cancel();
    _pause?.cancel();
    _udp?.close();
    final peers = [..._peers.values];
    _peers.clear();
    for (final p in peers) {
      p.socket.destroy();
    }
    await _server?.close();
    await _events.close();
  }
}

class _Peer {
  _Peer(this.socket);

  final Socket socket;
  GamePlayer? player;

  void send(String type, Map<String, Object?> data) {
    try {
      socket.write(LanProtocol.encode(type, data));
    } catch (_) {}
  }
}

extension on String {
  /// Corta a [max] caracteres (los nombres llegan de otro teléfono).
  String characters(int max) => length <= max ? this : substring(0, max);
}
