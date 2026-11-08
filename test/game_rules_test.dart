import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/features/game/domain/game_rules.dart';

const ana = GamePlayer(id: 'ana', name: 'Ana', avatar: 'emoji:🦊', grade: 2, color: 0, childId: 1);
const leo = GamePlayer(id: 'leo', name: 'Leo', avatar: 'emoji:🐼', grade: 6, color: 1, childId: 2);
const ivan = GamePlayer(id: 'ivan', name: 'Iván', avatar: 'emoji:🦁', grade: 4, color: 2);

GameState round(GameState s, Map<String, bool> hits, {Map<String, int> points = const {}}) {
  for (final e in hits.entries) {
    s = GameRules.answer(s, AnswerResult(playerId: e.key, correct: e.value, points: points[e.key] ?? 1));
  }
  return GameRules.closeRound(s);
}

void main() {
  group('Carrera de tocororos', () {
    test('cada acierto avanza una casilla y una tarjeta propia dos', () {
      var s = GameRules.start(GameMode.race, [ana, leo]);
      s = round(s, {'ana': true, 'leo': false}, points: {'ana': 2});
      expect(s.positionOf('ana'), 2);
      expect(s.positionOf('leo'), 0);
      expect(s.round, 2);
      expect(s.answered, isEmpty);
    });

    test('no se responde dos veces en la misma ronda ni juega quien no está', () {
      var s = GameRules.start(GameMode.race, [ana, leo]);
      s = GameRules.answer(s, const AnswerResult(playerId: 'ana', correct: true));
      s = GameRules.answer(s, const AnswerResult(playerId: 'ana', correct: true));
      s = GameRules.answer(s, const AnswerResult(playerId: 'pepe', correct: true));
      expect(s.positionOf('ana'), 1);
      expect(s.roundComplete, isFalse);
    });

    test('termina al cerrar la ronda en que alguien llega: todos responden igual número de veces', () {
      var s = GameRules.start(GameMode.race, [ana, leo]);
      for (var i = 0; i < 9; i++) {
        s = round(s, {'ana': true, 'leo': true});
      }
      s = GameRules.answer(s, const AnswerResult(playerId: 'ana', correct: true));
      expect(s.finished, isFalse, reason: 'Leo aún no respondió en esta ronda');
      s = round(s, {'leo': true});
      expect(s.finished, isTrue);
      expect(s.winners, unorderedEquals(['ana', 'leo']), reason: 'empate en la meta');
      expect(s.positionOf('ana'), GameRules.raceLength);
    });

    test('la meta no se pasa y gana quien llega solo', () {
      var s = GameRules.start(GameMode.race, [ana, leo]);
      for (var i = 0; i < 5; i++) {
        s = round(s, {'ana': true, 'leo': false}, points: {'ana': 2});
      }
      expect(s.finished, isTrue);
      expect(s.winners, ['ana']);
      expect(s.positionOf('ana'), GameRules.raceLength);
      expect(s.ranking.first, ana);
    });

    test('si nadie llega, al límite de rondas gana quien va delante', () {
      var s = GameRules.start(GameMode.race, [ana, leo]);
      for (var i = 0; i < GameRules.maxRaceRounds; i++) {
        s = round(s, {'ana': i.isEven, 'leo': false});
      }
      expect(s.finished, isTrue);
      expect(s.winners, ['ana']);
    });
  });

  group('Entre todos', () {
    test('los aciertos de todos llenan la barra y todos ganan', () {
      var s = GameRules.start(GameMode.team, [ana, leo]);
      expect(s.teamGoal, 12);
      for (var i = 0; i < 6; i++) {
        s = round(s, {'ana': true, 'leo': true});
      }
      expect(s.finished, isTrue);
      expect(s.teamWon, isTrue);
      expect(s.winners, unorderedEquals(['ana', 'leo']));
    });

    test('si se acaban las rondas, Toco no llega (nadie pierde contra nadie)', () {
      var s = GameRules.start(GameMode.team, [ana, leo]);
      for (var i = 0; i < GameRules.maxTeamRounds; i++) {
        s = round(s, {'ana': false, 'leo': i < 3});
      }
      expect(s.finished, isTrue);
      expect(s.teamWon, isFalse);
      expect(s.teamProgress, 3);
    });
  });

  group('en red', () {
    test('quien se va deja de contar; si queda uno solo, termina', () {
      var s = GameRules.start(GameMode.race, [ana, leo, ivan]);
      s = GameRules.answer(s, const AnswerResult(playerId: 'ana', correct: true));
      s = GameRules.answer(s, const AnswerResult(playerId: 'leo', correct: true));
      s = GameRules.removePlayer(s, 'ivan');
      expect(s.roundComplete, isTrue);
      s = GameRules.removePlayer(s, 'leo');
      expect(s.finished, isTrue);
      expect(s.winners, ['ana']);
    });

    test('el estado viaja en JSON', () {
      var s = GameRules.start(GameMode.team, [ana, ivan]);
      s = GameRules.answer(s, const AnswerResult(playerId: 'ivan', correct: true, points: 2));
      final back = GameState.fromJson(s.toJson());
      expect(back.positionOf('ivan'), 2);
      expect(back.teamProgress, 2);
      expect(back.answered, {'ivan'});
      expect(back.players.map((p) => p.grade), [2, 4]);
    });
  });

  test('tiempo, estrellas y mínimo de jugadores', () {
    expect(GameRules.timeFor(1), const Duration(seconds: 35));
    expect(GameRules.timeFor(6), const Duration(seconds: 25));
    var s = GameRules.start(GameMode.race, [ana, leo]);
    for (var i = 0; i < 5; i++) {
      s = round(s, {'ana': true, 'leo': false}, points: {'ana': 2});
    }
    expect(GameRules.starsFor(s, 'ana'), 1 + 10 ~/ 3 + 2);
    expect(GameRules.starsFor(s, 'leo'), 1);
    expect(() => GameRules.start(GameMode.race, [ana]), throwsArgumentError);
  });
}
