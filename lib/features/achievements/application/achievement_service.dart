import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../auth/application/session.dart';
import '../data/achievement_repository_impl.dart';
import '../domain/achievement.dart';
import '../domain/achievement_repository.dart';

final achievementRepositoryProvider = Provider<AchievementRepository>(
  (ref) => AchievementRepositoryImpl(ref.watch(appDatabaseProvider)),
);

/// Medallas recien ganadas que aun no se han mostrado al nino.
class NewMedalsController extends Notifier<List<Achievement>> {
  @override
  List<Achievement> build() => const [];

  void add(List<Achievement> medals) {
    if (medals.isNotEmpty) state = [...state, ...medals];
  }

  /// El nino ya vio la primera.
  void dismiss() {
    if (state.isNotEmpty) state = state.sublist(1);
  }
}

final newMedalsProvider = NotifierProvider<NewMedalsController, List<Achievement>>(
  NewMedalsController.new,
);

/// Progreso del nino activo (medallas y estrellas).
final childProgressProvider = StreamProvider.autoDispose<ChildProgress>((ref) {
  final id = ref.watch(sessionProvider.select((s) => s.activeChildId));
  if (id == null) return const Stream.empty();
  return ref.watch(achievementRepositoryProvider).watch(id);
});

/// Cuenta lo que hace el nino y da las medallas cuando llega a la meta.
class AchievementService {
  AchievementService(this._repo, this._now, this._announce);

  final AchievementRepository _repo;
  final DateTime Function() _now;
  final void Function(List<Achievement>) _announce;

  Future<void> _award(int childId, Achievement a, List<Achievement> fresh) async {
    if (await _repo.award(childId, a.code, _now())) fresh.add(a);
  }

  /// Corre [body] y avisa de las medallas nuevas. Un fallo con las medallas
  /// nunca debe estropear el chat.
  Future<void> _record(Future<void> Function(List<Achievement> fresh) body) async {
    try {
      final fresh = <Achievement>[];
      await body(fresh);
      _announce(fresh);
    } catch (e) {
      if (kDebugMode) debugPrint('[medallas] no se pudo anotar: $e');
    }
  }

  /// El tutor acabo de explicar algo apoyado en los libros.
  Future<void> topicLearned(int childId) => _record((fresh) async {
    await _repo.addToCounter(childId, Counters.topics, 1);
    await _award(childId, Medals.firstTopic, fresh);
  });

  /// El nino termino un quiz con [correct] aciertos de [total].
  Future<void> quizFinished(int childId, {required int correct, required int total}) =>
      _record((fresh) async {
        final quizzes = await _repo.addToCounter(childId, Counters.quizzes, 1);
        final right = await _repo.addToCounter(childId, Counters.correct, correct);
        if (quizzes >= 1) await _award(childId, Medals.firstQuiz, fresh);
        if (right >= 5) await _award(childId, Medals.correct5, fresh);
        if (right >= 20) await _award(childId, Medals.correct20, fresh);
        if (total > 0 && correct == total) await _award(childId, Medals.perfectQuiz, fresh);
      });

  /// El nino termino una partida del juego y gano [stars] estrellas.
  Future<void> gameFinished(int childId, {required int stars}) => _record((fresh) async {
    final right = await _repo.addToCounter(childId, Counters.correct, stars);
    if (right >= 5) await _award(childId, Medals.correct5, fresh);
    if (right >= 20) await _award(childId, Medals.correct20, fresh);
  });

  /// Estudio un bloque entero del Pomodoro y llego al descanso.
  Future<void> studySessionDone(int childId) =>
      _record((fresh) => _award(childId, Medals.sessionDone, fresh));

  /// El nino abre la app hoy: cuenta los dias seguidos.
  Future<void> dayOpened(int childId) => _record((fresh) async {
    final today = _epochDay(_now());
    final last = await _repo.counter(childId, Counters.lastDay);
    if (last == today) return;
    final streak = last == today - 1 ? await _repo.counter(childId, Counters.streak) + 1 : 1;
    await _repo.setCounter(childId, Counters.lastDay, today);
    await _repo.setCounter(childId, Counters.streak, streak);
    if (streak >= 3) await _award(childId, Medals.streak3, fresh);
  });

  /// Dias desde 1970, por fecha local (no por horas: cambiar de hora no rompe la racha).
  static int _epochDay(DateTime t) =>
      DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}

final achievementServiceProvider = Provider<AchievementService>((ref) {
  return AchievementService(
    ref.watch(achievementRepositoryProvider),
    ref.watch(clockProvider),
    (medals) => ref.read(newMedalsProvider.notifier).add(medals),
  );
});
