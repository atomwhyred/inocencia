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

/// Conversacion de un nino con el tutor. Se borra con el perfil o a mano desde
/// la zona de padres.
@DataClassName('TutorMessageRow')
class TutorMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get childId =>
      integer().references(ChildProfiles, #id, onDelete: KeyAction.cascade)();
  BoolColumn get fromUser => boolean()();

  /// No se llama `text`: ese getter taparia al constructor `text()` de Drift.
  TextColumn get content => text()();

  /// JSON `[{"subject":..,"book":..,"page":..}]` con los libros citados.
  TextColumn get sources => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Ultima pagina leida de cada libro por cada nino.
@DataClassName('ReadingProgressRow')
class ReadingProgress extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get childId =>
      integer().references(ChildProfiles, #id, onDelete: KeyAction.cascade)();

  /// Nombre del PDF sin extension, igual que `chunks.book` (`6to_matematica`).
  TextColumn get book => text()();

  /// Pagina del PDF contando desde 1, igual que `chunks.page`.
  IntColumn get page => integer()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {childId, book},
      ];
}

/// Medallas que ha ganado cada nino. El catalogo (titulos, iconos) vive en el
/// codigo; aqui solo se guarda el codigo y cuando se gano.
@DataClassName('AchievementRow')
class Achievements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get childId =>
      integer().references(ChildProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get code => text()();
  DateTimeColumn get earnedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {childId, code},
      ];
}

/// Contadores de cada nino (aciertos, quizzes, racha...) de los que salen las medallas.
@DataClassName('ChildCounterRow')
class ChildCounters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get childId =>
      integer().references(ChildProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get counter => text()();
  IntColumn get amount => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {childId, counter},
      ];
}

/// Tarjetas de memoria (flashcards) de cada nino: pregunta al frente, respuesta
/// al reverso, y lo que lleva de repaso.
@DataClassName('FlashcardRow')
class Flashcards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get childId =>
      integer().references(ChildProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get front => text()();
  TextColumn get back => text()();

  /// Libro y pagina de donde sale (`Español · 2do_lengua · pág. 138`).
  TextColumn get source => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get timesKnown => integer().withDefault(const Constant(0))();
  IntColumn get timesReviewed => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastReviewedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {childId, front},
      ];
}

@DriftDatabase(
  tables: [
    Guardians,
    ChildProfiles,
    TutorMessages,
    ReadingProgress,
    Achievements,
    ChildCounters,
    Flashcards,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openOnDevice());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(tutorMessages);
            await m.createTable(readingProgress);
          }
          if (from < 3) {
            await m.createTable(achievements);
            await m.createTable(childCounters);
          }
          if (from < 4) {
            await m.createTable(flashcards);
          }
        },
        // SQLite no aplica las claves foraneas (ni su borrado en cascada) si no
        // se activan en cada conexion.
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openOnDevice() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'inocencia.db'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
