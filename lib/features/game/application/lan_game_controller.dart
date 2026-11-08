import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../achievements/application/achievement_service.dart';
import '../../auth/application/active_child.dart';
import '../../profiles/presentation/avatar_view.dart';
import '../data/lan/lan_client.dart';
import '../data/lan/lan_host.dart';
import '../domain/game_question.dart';
import '../domain/game_rules.dart';
import '../domain/lan_protocol.dart';
import 'game_providers.dart';

enum LanPhase {
  /// Crear sala o unirse.
  choose,
  preparing,

  /// Anfitrion esperando a los demás.
  hosting,

  /// Buscando salas cercanas.
  searching,
  connecting,

  /// Invitado ya en la sala, esperando a que empiece.
  lobby,
  asking,

  /// Ya respondió: espera a los demás.
  waiting,
  finished,
  error,
}

class LanView extends Equatable {
  const LanView({
    this.phase = LanPhase.choose,
    this.isHost = false,
    this.players = const [],
    this.game,
    this.myId,
    this.question,
    this.picked,
    this.deadline,
    this.rooms = const [],
    this.addresses = const [],
    this.message,
    this.myStars,
  });

  final LanPhase phase;
  final bool isHost;
  final List<GamePlayer> players;
  final GameState? game;
  final String? myId;
  final GameQuestion? question;
  final int? picked;
  final DateTime? deadline;
  final List<RoomBeacon> rooms;

  /// IPs de este teléfono (para conectarse a mano).
  final List<String> addresses;
  final String? message;
  final int? myStars;

  GamePlayer? get me => players.where((p) => p.id == myId).firstOrNull;

  LanView copyWith({
    LanPhase? phase,
    bool? isHost,
    List<GamePlayer>? players,
    GameState? game,
    String? myId,
    GameQuestion? question,
    int? picked,
    bool clearPicked = false,
    DateTime? deadline,
    List<RoomBeacon>? rooms,
    List<String>? addresses,
    String? message,
    int? myStars,
  }) => LanView(
    phase: phase ?? this.phase,
    isHost: isHost ?? this.isHost,
    players: players ?? this.players,
    game: game ?? this.game,
    myId: myId ?? this.myId,
    question: question ?? this.question,
    picked: clearPicked ? null : (picked ?? this.picked),
    deadline: deadline ?? this.deadline,
    rooms: rooms ?? this.rooms,
    addresses: addresses ?? this.addresses,
    message: message ?? this.message,
    myStars: myStars ?? this.myStars,
  );

  @override
  List<Object?> get props => [
    phase,
    isHost,
    players,
    game,
    myId,
    question,
    picked,
    deadline,
    rooms,
    addresses,
    message,
    myStars,
  ];
}

/// Mantiene el Wi-Fi escuchando avisos y la pantalla encendida (Android).
class LanPlatform {
  const LanPlatform();
  static const _channel = MethodChannel('com.inocencia.app/lan');

  Future<void> begin() => _call('begin');
  Future<void> end() => _call('end');

  Future<void> _call(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } catch (_) {
      // Fuera de Android (pruebas, escritorio) no hace falta.
    }
  }
}

final lanPlatformProvider = Provider<LanPlatform>((ref) => const LanPlatform());

/// Partida entre teléfonos. Cada niño responde preguntas de su grado con su
/// propia base de libros y sus tarjetas; el anfitrión lleva el reloj y los puntos.
class LanGameController extends Notifier<LanView> {
  LanHost? _host;
  LanClient? _client;
  LanDiscovery? _discovery;
  StreamSubscription<LanEvent>? _sub;
  StreamSubscription<RoomBeacon>? _roomsSub;
  QuestionDeck? _deck;
  Timer? _timer;
  int? _round;
  DateTime? _askedAt;
  var _mode = GameMode.race;

  @override
  LanView build() {
    ref.onDispose(_shutdown);
    return const LanView();
  }

  void _shutdown() {
    _timer?.cancel();
    _sub?.cancel();
    _roomsSub?.cancel();
    _discovery?.close();
    _host?.close();
    _client?.close();
    ref.read(lanPlatformProvider).end();
  }

  /// El niño de este teléfono como jugador (las fotos viajan como miniatura).
  Future<GamePlayer?> _me() async {
    final child = ref.read(activeChildProvider);
    final grade = ref.read(activeGradeProvider);
    if (child == null || grade == null) return null;
    return GamePlayer(
      id: 'me',
      name: child.name,
      avatar: await networkAvatar(child.avatar),
      grade: grade,
      color: 0,
      childId: child.id,
    );
  }

  Future<bool> _prepareDeck(GamePlayer me) async {
    _deck = await ref
        .read(gameDeckBuilderProvider)
        .build(grade: me.grade, childId: me.childId);
    if (_deck!.isEmpty) {
      state = state.copyWith(
        phase: LanPhase.error,
        message:
            'No hay preguntas de tu grado en este teléfono: pide a un adulto que copie la base de libros '
            'con el banco del juego, o crea al menos 3 tarjetas desde el tutor.',
      );
      return false;
    }
    return true;
  }

  Future<void> host(GameMode mode) async {
    _mode = mode;
    state = state.copyWith(phase: LanPhase.preparing, isHost: true);
    final me = await _me();
    if (me == null || !await _prepareDeck(me) || !ref.mounted) return;
    await ref.read(lanPlatformProvider).begin();
    final host = _host = LanHost(self: me, mode: mode);
    try {
      await host.open();
    } on SocketException catch (e) {
      debugPrint('[juego] no se pudo abrir la sala: $e');
      state = state.copyWith(
        phase: LanPhase.error,
        message: 'No se pudo abrir la sala en este teléfono.\n\n$networkBlockedHint',
      );
      return;
    }
    _sub = host.events.listen(_onEvent);
    state = state.copyWith(
      phase: LanPhase.hosting,
      myId: LanHost.hostId,
      players: host.players,
      addresses: await LanHost.localAddresses(),
    );
  }

  void startGame() => _host?.start();

  Future<void> search() async {
    state = state.copyWith(
      phase: LanPhase.searching,
      isHost: false,
      rooms: const [],
    );
    await ref.read(lanPlatformProvider).begin();
    _discovery?.close();
    _discovery = await LanDiscovery.start();
    _roomsSub = _discovery?.rooms.listen((r) {
      final others = state.rooms.where((x) => x.host != r.host).toList();
      state = state.copyWith(rooms: [...others, r]);
    });
  }

  Future<void> join(String address) async {
    state = state.copyWith(phase: LanPhase.connecting);
    final me = await _me();
    if (me == null || !await _prepareDeck(me) || !ref.mounted) return;
    _roomsSub?.cancel();
    _discovery?.close();
    try {
      final client = _client = await LanClient.connect(
        address.trim(),
        name: me.name,
        avatar: me.avatar,
        grade: me.grade,
      );
      _sub = client.events.listen(_onEvent);
    } on Object catch (e) {
      debugPrint('[juego] no se pudo entrar en $address: $e');
      state = state.copyWith(
        phase: LanPhase.error,
        message:
            'No se encontró la sala en $address. ¿Estáis conectados al mismo Wi-Fi o punto de acceso?'
            '\n\n$networkBlockedHint',
      );
    }
  }

  void _onEvent(LanEvent e) {
    switch (e) {
      case LanJoined(:final playerId, :final mode):
        _mode = mode;
        state = state.copyWith(phase: LanPhase.lobby, myId: playerId);
      case LanLobby(:final players):
        state = state.copyWith(players: players);
      case LanRound(:final round, :final game):
        _ask(round, game);
      case LanState(:final game):
        state = state.copyWith(game: game, players: game.players);
      case LanEnded(:final game):
        _finish(game);
      case LanClosed(:final reason):
        _timer?.cancel();
        state = state.copyWith(phase: LanPhase.error, message: reason);
    }
  }

  void _ask(int round, GameState game) {
    final me = game.players.where((p) => p.id == state.myId).firstOrNull;
    if (me == null || _deck == null) return;
    _round = round;
    final limit = GameRules.timeFor(me.grade);
    final now = ref.read(clockProvider)();
    _askedAt = now;
    state = state.copyWith(
      phase: LanPhase.asking,
      game: game,
      players: game.players,
      question: _deck!.next(),
      clearPicked: true,
      deadline: now.add(limit),
    );
    _timer?.cancel();
    _timer = Timer(limit, () => pick(-1));
  }

  void pick(int option) {
    final q = state.question;
    final round = _round;
    if (state.phase != LanPhase.asking || q == null || round == null) return;
    _timer?.cancel();
    final correct = option == q.quiz.correct;
    final ms = ref.read(clockProvider)().difference(_askedAt!).inMilliseconds;
    state = state.copyWith(phase: LanPhase.waiting, picked: option);
    if (_host != null) {
      _host!.submit(
        AnswerResult(
          playerId: LanHost.hostId,
          correct: correct,
          points: q.points,
          millis: ms,
        ),
      );
    } else {
      _client?.sendResult(
        round: round,
        correct: correct,
        points: q.points,
        millis: ms,
      );
    }
  }

  Future<void> _finish(GameState game) async {
    _timer?.cancel();
    final myId = state.myId;
    final stars = myId == null ? 0 : GameRules.starsFor(game, myId);
    state = state.copyWith(
      phase: LanPhase.finished,
      game: game,
      players: game.players,
      myStars: stars,
    );
    await ref.read(lanPlatformProvider).end();
    final childId = ref.read(activeChildProvider)?.id;
    if (childId != null && myId != null) {
      await ref
          .read(achievementServiceProvider)
          .gameFinished(childId, stars: stars);
    }
  }

  GameMode get mode => _mode;
}

/// Android deja bloquear la red por app (ajustes de la app, "Acceso a la red"): entonces
/// ni siquiera se puede abrir un puerto local. Un padre pudo apagarlo por ser una app offline.
const networkBlockedHint =
    'Si no funciona, puede que este teléfono no deje a inocencIA usar la red: en Ajustes › '
    'Aplicaciones › inocencIA › Datos móviles y Wi-Fi, activa el acceso a la red. inocencIA no se '
    'conecta a internet: solo lo usa para jugar con los teléfonos de casa.';

final lanGameProvider =
    NotifierProvider.autoDispose<LanGameController, LanView>(
      LanGameController.new,
    );

/// Avatar que se puede enviar: los emoji tal cual; las fotos, como miniatura PNG de 96 px.
Future<String> networkAvatar(String avatar) async {
  if (!avatar.startsWith('photo:')) return avatar;
  try {
    final bytes = await File(avatar.substring(6)).readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 96,
      targetHeight: 96,
    );
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) return 'emoji:🙂';
    return imageAvatar(png.buffer.asUint8List());
  } catch (_) {
    return 'emoji:🙂';
  }
}
