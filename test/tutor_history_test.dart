import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/security/pin_hasher.dart';
import 'package:inocencia/core/storage/app_database.dart';
import 'package:inocencia/features/profiles/data/child_profile_repository_impl.dart';
import 'package:inocencia/features/profiles/domain/child_profile.dart';
import 'package:inocencia/features/tutor/data/tutor_history_repository_impl.dart';
import 'package:inocencia/features/tutor/domain/tutor_history_repository.dart';
import 'package:inocencia/features/tutor/domain/tutor_source.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  // La prueba de migracion abre una segunda base (distinta) a proposito.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late TutorHistoryRepositoryImpl repo;
  late int leo;
  late int ana;

  Future<int> newChild(String name) => ChildProfileRepositoryImpl(db, const PinHasher(iterations: 10))
      .create(ChildProfileInput(name: name, avatar: 'emoji:🦊', birthDate: DateTime(2015, 3, 1)));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TutorHistoryRepositoryImpl(db);
    leo = await newChild('Leo');
    ana = await newChild('Ana');
  });
  tearDown(() => db.close());

  group('TutorHistoryRepository', () {
    test('guarda y carga en orden, con las fuentes', () async {
      await repo.add(leo, const StoredTutorMessage(fromUser: true, text: '¿Qué es un adjetivo?'));
      await repo.add(
        leo,
        const StoredTutorMessage(
          fromUser: false,
          text: 'Dice cómo es algo. ¿Un ejemplo?',
          sources: [
            TutorSource(subject: 'Español', book: '6to_esp', page: 60),
            TutorSource(subject: 'Español', book: '6to_lengua'),
          ],
        ),
      );
      final loaded = await repo.load(leo);
      expect(loaded.map((m) => m.fromUser), [true, false]);
      expect(loaded.first.text, '¿Qué es un adjetivo?');
      expect(loaded.first.sources, isEmpty);
      expect(loaded.last.sources.map((s) => s.label), ['Español · 6to_esp · pág. 60', 'Español · 6to_lengua']);
      expect(loaded.last.sources.first.page, 60);
      expect(loaded.last.createdAt, isNotNull);
    });

    test('con limite devuelve los ultimos, de antiguo a reciente', () async {
      for (var i = 0; i < 10; i++) {
        await repo.add(leo, StoredTutorMessage(fromUser: i.isEven, text: 'm$i'));
      }
      final loaded = await repo.load(leo, limit: 3);
      expect(loaded.map((m) => m.text), ['m7', 'm8', 'm9']);
    });

    test('cada nino ve solo su conversacion', () async {
      await repo.add(leo, const StoredTutorMessage(fromUser: true, text: 'de Leo'));
      await repo.add(ana, const StoredTutorMessage(fromUser: true, text: 'de Ana'));
      expect((await repo.load(leo)).map((m) => m.text), ['de Leo']);
      expect((await repo.load(ana)).map((m) => m.text), ['de Ana']);
      expect(await repo.count(leo), 1);
    });

    test('clear borra solo la conversacion de ese nino', () async {
      await repo.add(leo, const StoredTutorMessage(fromUser: true, text: 'a'));
      await repo.add(leo, const StoredTutorMessage(fromUser: false, text: 'b'));
      await repo.add(ana, const StoredTutorMessage(fromUser: true, text: 'c'));
      await repo.clear(leo);
      expect(await repo.load(leo), isEmpty);
      expect(await repo.count(leo), 0);
      expect(await repo.count(ana), 1);
    });

    test('borrar el perfil borra su conversacion (cascada)', () async {
      await repo.add(leo, const StoredTutorMessage(fromUser: true, text: 'a'));
      await repo.add(ana, const StoredTutorMessage(fromUser: true, text: 'c'));
      await ChildProfileRepositoryImpl(db, const PinHasher(iterations: 10)).delete(leo);
      expect(await repo.count(leo), 0);
      expect(await repo.count(ana), 1);
    });

    test('no se puede guardar para un nino que no existe', () async {
      expect(
        () => repo.add(999, const StoredTutorMessage(fromUser: true, text: 'x')),
        throwsA(isA<Exception>()),
      );
    });

    test('un JSON de fuentes roto no impide abrir la conversacion', () async {
      await db.into(db.tutorMessages).insert(TutorMessagesCompanion.insert(
            childId: leo,
            fromUser: false,
            content: 'hola',
            sources: const Value('{no es json'),
          ));
      final loaded = await repo.load(leo);
      expect(loaded.single.text, 'hola');
      expect(loaded.single.sources, isEmpty);
    });
  });

  group('ReadingProgress', () {
    test('una fila por nino y libro; otro nino puede tener el mismo libro', () async {
      await db.into(db.readingProgress).insert(
          ReadingProgressCompanion.insert(childId: leo, book: '6to_esp', page: 10));
      await db.into(db.readingProgress).insert(
          ReadingProgressCompanion.insert(childId: ana, book: '6to_esp', page: 3));
      expect(
        () => db.into(db.readingProgress).insert(
            ReadingProgressCompanion.insert(childId: leo, book: '6to_esp', page: 11)),
        throwsA(isA<Exception>()),
      );
    });

    test('borrar el perfil borra su progreso (cascada)', () async {
      await db.into(db.readingProgress).insert(
          ReadingProgressCompanion.insert(childId: leo, book: '6to_esp', page: 10));
      await ChildProfileRepositoryImpl(db, const PinHasher(iterations: 10)).delete(leo);
      expect(await db.select(db.readingProgress).get(), isEmpty);
    });
  });

  group('migracion v1 -> v2', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('inocencia_migracion_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('conserva los perfiles de la version 1 y crea las tablas nuevas', () async {
      final path = '${tmp.path}/inocencia.db';
      // Base tal y como la dejaba la version 1: solo `guardians` y `child_profiles`.
      final old = sql.sqlite3.open(path);
      old.execute('''
        CREATE TABLE guardians (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          name TEXT NOT NULL, pin_hash TEXT NOT NULL, pin_length INTEGER NOT NULL);
        CREATE TABLE child_profiles (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          name TEXT NOT NULL, avatar TEXT NOT NULL, birth_date INTEGER NOT NULL,
          grade_override INTEGER NULL, pin_hash TEXT NULL, pin_length INTEGER NULL,
          created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)));
        INSERT INTO child_profiles (name, avatar, birth_date) VALUES ('Leo', 'emoji:🦊', 1426000000);
        PRAGMA user_version = 1;
      ''');
      old.close();

      final upgraded = AppDatabase(NativeDatabase(File(path)));
      addTearDown(upgraded.close);
      final profiles = await upgraded.select(upgraded.childProfiles).get();
      expect(profiles.single.name, 'Leo');

      final history = TutorHistoryRepositoryImpl(upgraded);
      await history.add(profiles.single.id, const StoredTutorMessage(fromUser: true, text: 'hola'));
      expect((await history.load(profiles.single.id)).single.text, 'hola');

      // Y la cascada funciona tambien en la base migrada.
      await ChildProfileRepositoryImpl(upgraded, const PinHasher(iterations: 10)).delete(profiles.single.id);
      expect(await history.count(profiles.single.id), 0);
    });
  });
}
