import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/security/pin_hasher.dart';
import 'package:inocencia/core/storage/app_database.dart';
import 'package:inocencia/features/achievements/application/achievement_service.dart';
import 'package:inocencia/features/achievements/data/achievement_repository_impl.dart';
import 'package:inocencia/features/achievements/domain/achievement.dart';
import 'package:inocencia/features/profiles/data/child_profile_repository_impl.dart';
import 'package:inocencia/features/profiles/domain/child_profile.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late AchievementRepositoryImpl repo;
  late AchievementService service;
  late DateTime now;
  late List<List<Achievement>> announced;
  late int leo;
  late int ana;

  Future<int> newChild(String name) =>
      ChildProfileRepositoryImpl(db, const PinHasher(iterations: 10))
          .create(ChildProfileInput(name: name, avatar: 'emoji:🦊', birthDate: DateTime(2015, 3, 1)));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = AchievementRepositoryImpl(db);
    now = DateTime(2026, 10, 29, 9);
    announced = [];
    service = AchievementService(repo, () => now, announced.add);
    leo = await newChild('Leo');
    ana = await newChild('Ana');
  });
  tearDown(() => db.close());

  Future<Set<String>> earned(int child) async => (await repo.watch(child).first).earned.keys.toSet();

  group('AchievementRepository', () {
    test('award da la medalla una sola vez y es por niño', () async {
      expect(await repo.award(leo, 'first_topic', now), isTrue);
      expect(await repo.award(leo, 'first_topic', now), isFalse);
      expect(await repo.award(ana, 'first_topic', now), isTrue);
      expect(await earned(leo), {'first_topic'});
    });

    test('los contadores suman, se fijan y no se mezclan entre niños', () async {
      expect(await repo.counter(leo, 'correct'), 0);
      expect(await repo.addToCounter(leo, 'correct', 2), 2);
      expect(await repo.addToCounter(leo, 'correct', 3), 5);
      await repo.setCounter(leo, 'streak', 7);
      expect(await repo.counter(leo, 'streak'), 7);
      expect(await repo.counter(ana, 'correct'), 0);
    });

    test('watch emite de nuevo al ganar una medalla o una estrella', () async {
      final seen = <ChildProgress>[];
      final sub = repo.watch(leo).listen(seen.add);
      addTearDown(sub.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await repo.award(leo, 'first_quiz', now);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await repo.addToCounter(leo, Counters.correct, 3);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(seen.last.earned.keys, ['first_quiz']);
      expect(seen.last.stars, 3);
    });

    test('borrar el perfil borra sus medallas y contadores (cascada)', () async {
      await repo.award(leo, 'first_topic', now);
      await repo.addToCounter(leo, 'correct', 1);
      await ChildProfileRepositoryImpl(db, const PinHasher(iterations: 10)).delete(leo);
      expect(await db.select(db.achievements).get(), isEmpty);
      expect(await db.select(db.childCounters).get(), isEmpty);
    });
  });

  group('AchievementService', () {
    test('el primer tema da su medalla y la anuncia una sola vez', () async {
      await service.topicLearned(leo);
      expect(announced.last.map((a) => a.code), ['first_topic']);
      await service.topicLearned(leo);
      expect(announced.last, isEmpty);
    });

    test('quizzes: primer quiz, 5 y 20 aciertos, y quiz perfecto', () async {
      await service.quizFinished(leo, correct: 2, total: 3);
      expect(announced.last.map((a) => a.code), ['first_quiz']);
      await service.quizFinished(leo, correct: 3, total: 3);
      expect(announced.last.map((a) => a.code).toSet(), {'correct_5', 'perfect_quiz'});
      expect((await repo.watch(leo).first).stars, 5);
      for (var i = 0; i < 5; i++) {
        await service.quizFinished(leo, correct: 3, total: 3);
      }
      expect(await earned(leo), containsAll(['correct_20']));
    });

    test('sesión de estudio completada', () async {
      await service.studySessionDone(leo);
      expect(announced.last.map((a) => a.code), ['session_done']);
    });

    test('racha: tres días seguidos; saltarse uno la reinicia; el mismo día no suma', () async {
      await service.dayOpened(leo);
      await service.dayOpened(leo);
      expect(await repo.counter(leo, Counters.streak), 1);
      now = now.add(const Duration(days: 1));
      await service.dayOpened(leo);
      expect(await repo.counter(leo, Counters.streak), 2);
      expect(await earned(leo), isEmpty);
      now = now.add(const Duration(days: 1));
      await service.dayOpened(leo);
      expect(announced.last.map((a) => a.code), ['streak_3']);

      now = now.add(const Duration(days: 3));
      await service.dayOpened(leo);
      expect(await repo.counter(leo, Counters.streak), 1);
    });

    test('un fallo con la base no rompe el chat', () async {
      await db.close();
      await service.topicLearned(leo); // no lanza
      db = AppDatabase(NativeDatabase.memory());
    });
  });

  test('catálogo: códigos únicos y todos con pista', () {
    final codes = Medals.all.map((a) => a.code).toList();
    expect(codes.toSet().length, codes.length);
    expect(Medals.all.every((a) => a.hint.isNotEmpty && a.title.isNotEmpty), isTrue);
    expect(Medals.byCode('streak_3'), Medals.streak3);
    expect(Medals.byCode('no_existe'), isNull);
  });

  group('migración v2 -> v3', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('inocencia_mig3_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('conserva los perfiles de la v2 y crea medallas y contadores', () async {
      final path = '${tmp.path}/inocencia.db';
      final old = sql.sqlite3.open(path);
      old.execute('''
        CREATE TABLE guardians (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          name TEXT NOT NULL, pin_hash TEXT NOT NULL, pin_length INTEGER NOT NULL);
        CREATE TABLE child_profiles (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          name TEXT NOT NULL, avatar TEXT NOT NULL, birth_date INTEGER NOT NULL,
          grade_override INTEGER NULL, pin_hash TEXT NULL, pin_length INTEGER NULL,
          created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)));
        CREATE TABLE tutor_messages (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          child_id INTEGER NOT NULL REFERENCES child_profiles (id) ON DELETE CASCADE,
          from_user INTEGER NOT NULL, content TEXT NOT NULL, sources TEXT NOT NULL DEFAULT '[]',
          created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)));
        CREATE TABLE reading_progress (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          child_id INTEGER NOT NULL REFERENCES child_profiles (id) ON DELETE CASCADE,
          book TEXT NOT NULL, page INTEGER NOT NULL,
          updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
          UNIQUE (child_id, book));
        INSERT INTO child_profiles (name, avatar, birth_date) VALUES ('Leo', 'emoji:🦊', 1426000000);
        PRAGMA user_version = 2;
      ''');
      old.close();

      final upgraded = AppDatabase(NativeDatabase(File(path)));
      addTearDown(upgraded.close);
      final child = (await upgraded.select(upgraded.childProfiles).get()).single;
      expect(child.name, 'Leo');

      final r = AchievementRepositoryImpl(upgraded);
      expect(await r.award(child.id, 'first_topic', now), isTrue);
      await r.addToCounter(child.id, 'correct', 2);
      expect((await r.watch(child.id).first).stars, 2);

      await ChildProfileRepositoryImpl(upgraded, const PinHasher(iterations: 10)).delete(child.id);
      expect(await upgraded.select(upgraded.achievements).get(), isEmpty);
    });
  });
}
