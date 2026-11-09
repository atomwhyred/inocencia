import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/features/game/application/lan_game_controller.dart';
import 'package:inocencia/features/game/data/lan/lan_client.dart';
import 'package:inocencia/features/game/data/lan/lan_host.dart';
import 'package:inocencia/features/game/domain/game_rules.dart';
import 'package:inocencia/features/game/domain/lan_protocol.dart';

const ana = GamePlayer(id: 'x', name: 'Ana', avatar: 'emoji:🦊', grade: 2, color: 0, childId: 1);

Future<T> next<T extends LanEvent>(Stream<LanEvent> s, {bool Function(T)? where}) => s
    .where((e) => e is T && (where == null || where(e)))
    .cast<T>()
    .first
    .timeout(const Duration(seconds: 10));

void main() {
  group('protocolo', () {
    test('ida y vuelta, y basura ignorada', () {
      final m = LanProtocol.decode(LanProtocol.encode('result', {'round': 3, 'correct': true}).trim())!;
      expect(m['t'], 'result');
      expect(m['round'], 3);
      expect(LanProtocol.compatible(m), isTrue);
      expect(LanProtocol.decode('hola'), isNull);
      expect(LanProtocol.decode('{"x":1}'), isNull);
    });

    test('aviso de sala', () {
      final m = LanProtocol.decode(
        LanProtocol.encode('room', {'name': 'Ana', 'grade': 2, 'mode': 'race', 'players': 1, 'port': 47321}).trim(),
      )!;
      final r = RoomBeacon.fromMessage(m, '192.168.43.1')!;
      expect((r.host, r.name, r.grade, r.mode, r.players), ('192.168.43.1', 'Ana', 2, GameMode.race, 1));
      expect(RoomBeacon.fromMessage({...m, 'v': 99}, 'x'), isNull, reason: 'otra versión');
    });
  });

  group('partida por red (127.0.0.1)', () {
    late LanHost host;
    late int port;

    setUp(() async {
      host = LanHost(
        self: ana,
        mode: GameMode.race,
        port: 0,
        announce: false,
        revealPause: const Duration(milliseconds: 20),
        grace: Duration.zero,
      );
      port = await host.open();
    });
    tearDown(() => host.close());

    Future<LanClient> join(String name, int grade) async {
      final c = await LanClient.connect('127.0.0.1', port: port, name: name, avatar: 'emoji:🐼', grade: grade);
      await next<LanJoined>(c.events);
      return c;
    }

    test('dos invitados entran, se ven con su grado y juegan hasta la meta', () async {
      final lobby = host.events.where((e) => e is LanLobby && e.players.length == 3).first;
      final leo = await join('Leo', 6);
      final ivan = await join('Iván', 4);
      final players = (await lobby.timeout(const Duration(seconds: 5)) as LanLobby).players;
      expect(players.map((p) => '${p.name} ${p.grade}'), ['Ana 2', 'Leo 6', 'Iván 4']);
      expect(players.map((p) => p.color).toSet(), hasLength(3), reason: 'un color por carril');

      // Cada ronda: Ana (anfitriona) acierta con tarjeta (+2), Leo acierta, Iván falla.
      final done = next<LanEnded>(leo.events);
      void play(LanClient c, bool correct) => c.events.listen((e) {
        if (e is LanRound) c.sendResult(round: e.round, correct: correct, points: 1);
      });
      play(leo, true);
      play(ivan, false);
      host.events.listen((e) {
        if (e is LanRound) host.submit(const AnswerResult(playerId: LanHost.hostId, correct: true, points: 2));
      });
      host.start();

      final end = (await done).game;
      expect(end.finished, isTrue);
      expect(end.winners, ['h']);
      expect(end.positionOf('h'), GameRules.raceLength);
      expect(end.positionOf(leo.playerId!), 5);
      expect(end.positionOf(ivan.playerId!), 0);
      await leo.close();
      await ivan.close();
    });

    test('si un invitado se va a mitad, la ronda no se queda esperando', () async {
      final leo = await join('Leo', 6);
      final ivan = await join('Iván', 4);
      final round2 = next<LanRound>(leo.events, where: (e) => e.round == 2);
      leo.events.listen((e) {
        if (e is LanRound) leo.sendResult(round: e.round, correct: true, points: 1);
      });
      host.start();
      await next<LanRound>(ivan.events);
      host.submit(const AnswerResult(playerId: LanHost.hostId, correct: false));
      await ivan.close(); // Iván cierra la app sin responder
      final r2 = await round2;
      expect(r2.game.players.map((p) => p.name), ['Ana', 'Leo']);
      await leo.close();
    });

    test('rechaza otra versión y a quien llega con la partida empezada', () async {
      final raw = await Socket.connect('127.0.0.1', port);
      raw.write('${jsonEncode({'t': 'hello', 'v': 99, 'player': {'name': 'X', 'avatar': 'emoji:🐸', 'grade': 3}})}\n');
      final reply = await raw.cast<List<int>>().transform(utf8.decoder).first.timeout(const Duration(seconds: 5));
      expect(LanProtocol.decode(reply.trim())!['t'], 'reject');
      raw.destroy();

      final leo = await join('Leo', 6);
      host.start();
      final late = await LanClient.connect('127.0.0.1', port: port, name: 'Tarde', avatar: 'emoji:🐢', grade: 3);
      final closed = await next<LanClosed>(late.events);
      expect(closed.reason, contains('ya empezó'));
      await leo.close();
    });

    test('si se cierra la sala, el invitado lo sabe', () async {
      final leo = await join('Leo', 6);
      final closed = next<LanClosed>(leo.events);
      await host.close();
      expect((await closed).reason, contains('cerró'));
    });
  });

  group('controlador', () {
    test('al salir libera la plataforma sin usar el Ref ya desechado', () async {
      final platform = _FakePlatform();
      final errors = <Object>[];
      await runZonedGuarded(() async {
        final c = ProviderContainer(overrides: [lanPlatformProvider.overrideWithValue(platform)]);
        c.read(lanGameProvider);
        c.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }, (e, _) => errors.add(e));
      expect(errors, isEmpty);
      expect(platform.ended, 1);
    });
  });
}

class _FakePlatform extends LanPlatform {
  _FakePlatform() : super();
  int ended = 0;

  @override
  Future<void> begin() async {}

  @override
  Future<void> end() async => ended++;
}
