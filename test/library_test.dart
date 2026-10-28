import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/security/pin_hasher.dart';
import 'package:inocencia/core/storage/app_database.dart';
import 'package:inocencia/features/external_data/domain/external_files_repository.dart';
import 'package:inocencia/features/library/data/library_repository_impl.dart';
import 'package:inocencia/features/library/data/reading_progress_repository_impl.dart';
import 'package:inocencia/features/profiles/data/child_profile_repository_impl.dart';
import 'package:inocencia/features/profiles/domain/child_profile.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

class _FakeFiles implements ExternalFilesRepository {
  _FakeFiles({this.knowledgePath, this.dirs = const []});

  @override
  final String? knowledgePath;
  final List<String> dirs;

  @override
  Future<List<String>> appStorageDirs() async => dirs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _books = [
  {'file': '1ro_2do_ca_el_mundo.pdf', 'subject': 'El mundo en que vivimos', 'grades': [1, 2], 'kind': 'Libro', 'pages': 27},
  {'file': '6to_matematica.pdf', 'subject': 'Matemática', 'grades': [6], 'kind': 'Libro', 'pages': 242},
  {'file': '6to_ct_matematica.pdf', 'subject': 'Matemática', 'grades': [6], 'kind': 'Cuaderno', 'pages': 80},
  {'file': '6to_esp.pdf', 'subject': 'Español', 'grades': [6], 'kind': 'Libro', 'pages': 200},
  {'file': '6to_lengua.pdf', 'subject': 'Español', 'grades': [6], 'kind': 'Libro', 'pages': 220},
  {'file': '5to_lengua.pdf', 'subject': 'Español', 'grades': [5], 'kind': 'Libro', 'pages': 210},
];

void main() {
  late Directory tmp;
  late String dbPath;
  late String appDir;

  void makeKnowledge({bool withMeta = true}) {
    final db = sql.sqlite3.open(dbPath);
    db.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);'
        'CREATE TABLE chunks (id INTEGER PRIMARY KEY, grade INTEGER NOT NULL, subject TEXT NOT NULL, '
        'book TEXT, chapter TEXT, page INTEGER, text TEXT NOT NULL);');
    if (withMeta) {
      db.execute("INSERT INTO meta VALUES ('books', ?)", [jsonEncode(_books)]);
    } else {
      db.execute("INSERT INTO chunks (grade, subject, book, page, text) VALUES "
          "(6, 'Matemática', '6to_matematica', 10, 'a'), (6, 'Matemática', '6to_matematica', 99, 'b'), "
          "(1, 'Mundo', '1ro_2do_ca_el_mundo', 3, 'c'), (2, 'Mundo', '1ro_2do_ca_el_mundo', 5, 'd'), "
          "(6, 'Matemática', '6to_ct_matematica', 4, 'e')");
    }
    db.close();
  }

  LibraryRepositoryImpl repo({String? knowledge, List<String>? dirs}) =>
      LibraryRepositoryImpl(_FakeFiles(knowledgePath: knowledge ?? dbPath, dirs: dirs ?? [appDir]));

  void pdf(String relative) {
    final f = File('$appDir/$relative')..createSync(recursive: true);
    f.writeAsBytesSync([0x25, 0x50, 0x44, 0x46]); // %PDF
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('inocencia_libros_');
    dbPath = '${tmp.path}/knowledge.db';
    appDir = '${tmp.path}/files';
    Directory(appDir).createSync();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('LibraryRepository', () {
    test('lista los libros del grado, libros antes que cuadernos', () async {
      makeKnowledge();
      final books = await repo().booksForGrade(6);
      expect(books.map((b) => b.id), ['6to_esp', '6to_lengua', '6to_matematica', '6to_ct_matematica']);
    });

    test('un libro de dos grados sale en los dos y en ningún otro', () async {
      makeKnowledge();
      expect((await repo().booksForGrade(1)).map((b) => b.id), ['1ro_2do_ca_el_mundo']);
      expect((await repo().booksForGrade(2)).map((b) => b.id), ['1ro_2do_ca_el_mundo']);
      expect(await repo().booksForGrade(3), isEmpty);
    });

    test('dos libros iguales del mismo grado se numeran; uno solo no lleva número', () async {
      makeKnowledge();
      final titles = {for (final b in await repo().booksForGrade(6)) b.id: b.title};
      expect(titles['6to_esp'], 'Español 1');
      expect(titles['6to_lengua'], 'Español 2');
      expect(titles['6to_matematica'], 'Matemática');
      expect(titles['6to_ct_matematica'], 'Cuaderno · Matemática');
      // En 5.º solo hay uno: sin número.
      expect((await repo().booksForGrade(5)).single.title, 'Español');
    });

    test('un cuaderno de actividades (ca_) se trata como cuaderno', () async {
      makeKnowledge();
      final b = (await repo().booksForGrade(1)).single;
      expect(b.id, '1ro_2do_ca_el_mundo');
      expect(b.isNotebook, isTrue);
      expect(b.title, 'Cuaderno · El mundo en que vivimos');
    });

    test('un libro está disponible si su PDF está en libros/ o en la carpeta de la app', () async {
      makeKnowledge();
      pdf('libros/6to_matematica.pdf');
      pdf('6to_esp.pdf');
      pdf('libros/OTRO.txt');
      final byId = {for (final b in await repo().booksForGrade(6)) b.id: b};
      expect(byId['6to_matematica']!.available, isTrue);
      expect(byId['6to_matematica']!.path, '$appDir/libros/6to_matematica.pdf');
      expect(byId['6to_esp']!.available, isTrue);
      expect(byId['6to_lengua']!.available, isFalse);
      expect(byId['6to_lengua']!.path, isNull);
      expect(byId['6to_matematica']!.pages, 242);
    });

    test('la extensión .PDF en mayúsculas también vale', () async {
      makeKnowledge();
      pdf('libros/6to_esp.PDF');
      expect((await repo().find('6to_esp'))!.available, isTrue);
    });

    test('find devuelve el libro por su id, o null', () async {
      makeKnowledge();
      expect((await repo().find('6to_matematica'))!.title, 'Matemática');
      expect(await repo().find('no_existe'), isNull);
    });

    test('sin meta.books se deduce de los fragmentos', () async {
      makeKnowledge(withMeta: false);
      final books = await repo().booksForGrade(6);
      expect(books.map((b) => b.id), ['6to_matematica', '6to_ct_matematica']);
      expect(books.first.pages, 99);
      expect(books.last.isNotebook, isTrue);
      expect((await repo().booksForGrade(2)).single.grades, [1, 2]);
    });

    test('sin base vinculada o con una base ilegible, no hay libros ni errores', () async {
      expect(await LibraryRepositoryImpl(_FakeFiles(dirs: [appDir])).booksForGrade(6), isEmpty);
      File(dbPath).writeAsStringSync('esto no es sqlite');
      expect(await repo().booksForGrade(6), isEmpty);
    });

    test('status cuenta los PDF copiados y dice dónde copiarlos', () async {
      makeKnowledge();
      pdf('libros/6to_matematica.pdf');
      pdf('libros/5to_lengua.pdf');
      final s = await repo().status();
      expect(s.total, 6);
      expect(s.available, 2);
      expect(s.folders, ['$appDir/libros']);
    });
  });

  group('ReadingProgressRepository', () {
    late AppDatabase db;
    late ReadingProgressRepositoryImpl progress;
    late int leo;
    late int ana;

    Future<int> newChild(String name) =>
        ChildProfileRepositoryImpl(db, const PinHasher(iterations: 10)).create(
          ChildProfileInput(name: name, avatar: 'emoji:🦊', birthDate: DateTime(2015, 3, 1)),
        );

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      progress = ReadingProgressRepositoryImpl(db);
      leo = await newChild('Leo');
      ana = await newChild('Ana');
    });
    tearDown(() => db.close());

    test('sin abrir el libro no hay página guardada', () async {
      expect(await progress.get(leo, '6to_matematica'), isNull);
      expect(await progress.all(leo), isEmpty);
    });

    test('guarda y actualiza la misma fila', () async {
      await progress.save(leo, '6to_matematica', 10);
      await progress.save(leo, '6to_matematica', 57);
      expect(await progress.get(leo, '6to_matematica'), 57);
      expect(await db.select(db.readingProgress).get(), hasLength(1));
    });

    test('cada niño tiene su página en el mismo libro', () async {
      await progress.save(leo, '6to_matematica', 57);
      await progress.save(ana, '6to_matematica', 3);
      await progress.save(leo, '6to_esp', 8);
      expect(await progress.get(ana, '6to_matematica'), 3);
      expect(await progress.all(leo), {'6to_matematica': 57, '6to_esp': 8});
    });

    test('una página menor que 1 no se guarda', () async {
      await progress.save(leo, '6to_matematica', 0);
      expect(await progress.get(leo, '6to_matematica'), isNull);
    });
  });
}
