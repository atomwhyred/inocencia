import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Padre/madre administrador. Solo hay uno (se crea en el primer arranque).
@DataClassName('GuardianRow')
class Guardians extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get pinHash => text()();
  IntColumn get pinLength => integer()();
}

/// Perfiles infantiles.
@DataClassName('ChildProfileRow')
class ChildProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();

  /// `emoji:<caracter>` o `photo:<ruta absoluta>`.
  TextColumn get avatar => text()();
  DateTimeColumn get birthDate => dateTime()();

  /// Grado fijado a mano por el padre; null = calcular desde la fecha.
  IntColumn get gradeOverride => integer().nullable()();
  TextColumn get pinHash => text().nullable()();
  IntColumn get pinLength => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Guardians, ChildProfiles])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openOnDevice());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openOnDevice() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'inocencia.db'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
