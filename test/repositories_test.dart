import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/security/pin_hasher.dart';
import 'package:inocencia/core/storage/app_database.dart';
import 'package:inocencia/features/profiles/data/child_profile_repository_impl.dart';
import 'package:inocencia/features/profiles/domain/child_profile.dart';
import 'package:inocencia/features/setup/data/guardian_repository_impl.dart';

void main() {
  late AppDatabase db;
  const hasher = PinHasher(iterations: 10);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('GuardianRepository', () {
    test('sin administrador emite null; luego el creado', () async {
      final repo = GuardianRepositoryImpl(db, hasher);
      expect(await repo.watch().first, isNull);
      await repo.create(name: '  Ana  ', pin: '1234');
      final g = await repo.watch().first;
      expect(g?.name, 'Ana');
      expect(g?.pinLength, 4);
    });

    test('verifyPin acepta el correcto y rechaza el incorrecto', () async {
      final repo = GuardianRepositoryImpl(db, hasher);
      await repo.create(name: 'Ana', pin: '123456');
      expect(await repo.verifyPin('123456'), isTrue);
      expect(await repo.verifyPin('123457'), isFalse);
    });

    test('no permite un segundo administrador', () async {
      final repo = GuardianRepositoryImpl(db, hasher);
      await repo.create(name: 'Ana', pin: '1234');
      expect(() => repo.create(name: 'Luis', pin: '4321'), throwsStateError);
    });
  });

  group('ChildProfileRepository', () {
    final birth = DateTime(2016, 5, 20);
    ChildProfileInput input({String name = 'Leo', int? grade}) => ChildProfileInput(
          name: name,
          avatar: 'emoji:🦊',
          birthDate: birth,
          gradeOverride: grade,
        );

    test('crea, lee y calcula el grado', () async {
      final repo = ChildProfileRepositoryImpl(db, hasher);
      final id = await repo.create(input());
      final c = await repo.getById(id);
      expect(c?.name, 'Leo');
      expect(c?.hasPin, isFalse);
      // 10 anos al 1/09/2026 -> 5.o grado.
      expect(c?.gradeAt(DateTime(2026, 10, 27)), 5);
    });

    test('el grado manual manda sobre el calculado', () async {
      final repo = ChildProfileRepositoryImpl(db, hasher);
      final id = await repo.create(input(grade: 3));
      expect((await repo.getById(id))?.gradeAt(DateTime(2026, 10, 27)), 3);
    });

    test('PIN opcional: crear con PIN, verificar, cambiar y quitar', () async {
      final repo = ChildProfileRepositoryImpl(db, hasher);
      final id = await repo.create(input(), pin: '1111');
      expect((await repo.getById(id))?.pinLength, 4);
      expect(await repo.verifyPin(id, '1111'), isTrue);
      expect(await repo.verifyPin(id, '2222'), isFalse);

      await repo.update(id, input(name: 'Leo M.'), const KeepChildPin());
      expect(await repo.verifyPin(id, '1111'), isTrue);
      expect((await repo.getById(id))?.name, 'Leo M.');

      await repo.update(id, input(), const SetChildPin('222222'));
      expect((await repo.getById(id))?.pinLength, 6);
      expect(await repo.verifyPin(id, '222222'), isTrue);

      await repo.update(id, input(), const RemoveChildPin());
      expect((await repo.getById(id))?.hasPin, isFalse);
      expect(await repo.verifyPin(id, 'cualquiera'), isTrue);
    });

    test('elimina perfiles y watchAll refleja el cambio', () async {
      final repo = ChildProfileRepositoryImpl(db, hasher);
      final a = await repo.create(input(name: 'A'));
      await repo.create(input(name: 'B'));
      expect((await repo.watchAll().first).map((c) => c.name), ['A', 'B']);
      await repo.delete(a);
      expect((await repo.watchAll().first).map((c) => c.name), ['B']);
      expect(await repo.getById(a), isNull);
    });
  });
}
