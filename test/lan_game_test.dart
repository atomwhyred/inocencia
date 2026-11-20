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
import 'package:inocencia/features/game/domain/net_sanitize.dart';

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
        LanProtocol.encode('room', {'name': 'Sala del Totí', 'grade': 2, 'mode': 'race', 'players': 1, 'port': 47321})
            .trim(),
      )!;
      final r = RoomBeacon.fromMessage(m, '192.168.43.1')!;
      expect((r.host, r.name, r.grade, r.mode, r.players), ('192.168.43.1', 'Sala del Totí', 2, GameMode.race, 1));
      expect(RoomBeacon.fromMessage({...m, 'v': 99}, 'x'), isNull, reason: 'otra versión');
      final hostile = RoomBeacon.fromMessage({...m, 'name': 'x' * 500, 'grade': 99, 'players': -4}, 'x')!;
      expect((hostile.name.length, hostile.grade, hostile.players), (28, 6, 0));
    });

    test('código y nombre de sala', () {
      for (var i = 0; i < 50; i++) {
        expect(LanProtocol.isRoomCode(LanProtocol.newRoomCode()), isTrue);
      }
      expect(LanProtocol.isRoomCode('12a4'), isFalse);
      expect(LanProtocol.isRoomCode(1234), isFalse);
      expect(LanProtocol.newRoomName(), startsWith('Sala '));
    });
  });

  group('lo que llega por la red se limpia', () {
    test('avatar: nunca una ruta local; miniatura solo si es un PNG pequeño', () {
      expect(NetSanitize.avatar('emoji:🦊'), 'emoji:🦊');
      expect(NetSanitize.avatar('photo:/sdcard/DCIM/foto.jpg'), NetSanitize.defaultAvatar);
      expect(NetSanitize.avatar(42), NetSanitize.defaultAvatar);
      expect(NetSanitize.avatar('img:${'A' * 60000}'), NetSanitize.defaultAvatar, reason: 'demasiado grande');
      expect(NetSanitize.avatar('img:${base64Encode(_png(96, 96))}'), startsWith('img:'));
      expect(NetSanitize.avatar('img:${base64Encode(_png(20000, 20000))}'), NetSanitize.defaultAvatar);
      expect(NetSanitize.avatar('img:${base64Encode(utf8.encode('no soy un png, soy texto largo'))}'),
          NetSanitize.defaultAvatar);
    });

    test('texto: corto, sin control y sin partir emojis', () {
      expect(NetSanitize.text('  Ana\n\u202eLeo ', 24), 'Ana  Leo');
      expect(NetSanitize.text('🦊' * 30, 24).runes.length, 24);
      expect(NetSanitize.text(null, 24, fallback: 'Jugador'), 'Jugador');
    });

    test('jugador recibido del anfitrión', () {
      final p = GamePlayer.fromJson({'id': 'p1', 'name': 'x' * 100, 'avatar': 'photo:/data/a.jpg', 'grade': 'tres', 'color': 1e9.toInt()});
      expect((p.name.length, p.avatar, p.grade, p.color), (GamePlayer.maxNameLength, NetSanitize.defaultAvatar, 1, 63));
    });

    test('líneas con tope: una línea enorme corta el flujo con error', () async {
      final ok = await Stream.fromIterable(['a\nb', 'c\n', 'd']).transform(const BoundedLineSplitter(10)).toList();
      expect(ok, ['a', 'bc', 'd']);
      final errors = <Object>[];
      final lines = <String>[];
      final done = Completer<void>();
      Stream.fromIterable(['corta\n', 'x' * 8, 'x' * 8])
          .transform(const BoundedLineSplitter(10))
          .listen(lines.add, onError: errors.add, onDone: done.complete);
      await done.future;
      expect(lines, ['corta']);
      expect(errors.single, isA<FormatException>());
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
        code: '4821',
        helloTimeout: const Duration(milliseconds: 300),
        revealPause: const Duration(milliseconds: 20),
        grace: Duration.zero,
      );
      port = await host.open();
    });
    tearDown(() => host.close());

    Future<LanClient> join(String name, int grade) async {
      final c = await LanClient.connect('127.0.0.1', port: port, code: '4821', name: name, avatar: 'emoji:🐼', grade: grade);
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
      final late = await LanClient.connect('127.0.0.1', port: port, code: '4821', name: 'Tarde', avatar: 'emoji:🐢', grade: 3);
      final closed = await next<LanClosed>(late.events);
      expect(closed.reason, contains('ya empezó'));
      await leo.close();
    });

    test('sin el código correcto no se entra, y tras varios fallos se ignora esa IP', () async {
      final wrong = await LanClient.connect('127.0.0.1', port: port, code: '0000', name: 'Intruso', avatar: 'emoji:🐸', grade: 3);
      expect((await next<LanClosed>(wrong.events)).reason, contains('código'));
      for (var i = 1; i < LanHost.maxWrongCodes; i++) {
        final c = await LanClient.connect('127.0.0.1', port: port, code: '1111', name: 'X', avatar: 'emoji:🐸', grade: 3);
        await next<LanClosed>(c.events);
      }
      // Ya ni con el código bueno: la IP quedó bloqueada mientras dure la sala.
      final blocked = await LanClient.connect('127.0.0.1', port: port, code: '4821', name: 'X', avatar: 'emoji:🐸', grade: 3);
      expect(await next<LanEvent>(blocked.events), isA<LanClosed>());
      expect(host.players.map((p) => p.name), ['Ana']);
    });

    test('un segundo saludo por la misma conexión no crea jugadores fantasma', () async {
      final raw = await Socket.connect('127.0.0.1', port);
      final hello = LanProtocol.encode('hello', {
        'code': '4821',
        'player': {'name': 'Eco', 'avatar': 'photo:/sdcard/x.jpg', 'grade': 3},
      });
      final lobby = host.events.where((e) => e is LanLobby && e.players.length == 2).first;
      raw.write(hello);
      final players = (await lobby.timeout(const Duration(seconds: 5)) as LanLobby).players;
      expect(players.last.avatar, NetSanitize.defaultAvatar, reason: 'la ruta local no se acepta');
      final gone = host.events.where((e) => e is LanLobby && e.players.length == 1).first;
      raw.write(hello);
      await gone.timeout(const Duration(seconds: 5));
      expect(host.players, hasLength(1));
      raw.destroy();
    });

    test('quien se conecta y no saluda, o manda una línea sin fin, queda fuera', () async {
      final silent = await Socket.connect('127.0.0.1', port);
      final silentClosed = silent.drain<void>().timeout(const Duration(seconds: 5));
      await silentClosed;

      final flood = await Socket.connect('127.0.0.1', port);
      final floodClosed = flood.drain<void>().timeout(const Duration(seconds: 5));
      final chunk = 'x' * 65536;
      try {
        for (var i = 0; i < 8; i++) {
          flood.write(chunk);
          await flood.flush();
        }
      } catch (_) {}
      await floodClosed.catchError((_) {});
      flood.destroy();

      // La sala sigue funcionando.
      final leo = await join('Leo', 6);
      expect(host.players.map((p) => p.name), ['Ana', 'Leo']);
      await leo.close();
    });

    test('un resultado con tipos raros no rompe al anfitrión', () async {
      final errors = <Object>[];
      await runZonedGuarded(() async {
        final raw = await Socket.connect('127.0.0.1', port);
        final lines = boundedLines(raw.cast<List<int>>()).asBroadcastStream();
        final lobby = host.events.where((e) => e is LanLobby && e.players.length == 2).first;
        raw.write(LanProtocol.encode('hello', {
          'code': '4821',
          'player': {'name': 'Raro', 'avatar': 'emoji:🐸', 'grade': 3},
        }));
        await lobby.timeout(const Duration(seconds: 5));
        final roundLine = lines.firstWhere((l) => l.contains('"t":"round"'));
        host.start();
        final round = LanProtocol.decode(await roundLine.timeout(const Duration(seconds: 5)))!['round'];
        final state = host.events.where((e) => e is LanState).first;
        // `ms` como texto y `points` como lista: antes lanzaba TypeError en el socket.
        raw.write(LanProtocol.encode('result', {'round': round, 'correct': true, 'points': [1], 'ms': 'x'}));
        final s = (await state.timeout(const Duration(seconds: 5)) as LanState).game;
        expect(s.answered, contains('p1'));
        raw.destroy();
      }, (e, _) => errors.add(e));
      expect(errors, isEmpty);
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

/// Cabecera mínima de PNG (firma + IHDR) con estas medidas: basta para el saneado.
List<int> _png(int w, int h) {
  List<int> be(int v) => [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255];
  return [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ...be(13), ...'IHDR'.codeUnits, ...be(w), ...be(h), 8, 6, 0, 0, 0];
}
