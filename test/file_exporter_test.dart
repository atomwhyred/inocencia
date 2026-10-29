import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/features/external_data/data/file_exporter_impl.dart';
import 'package:inocencia/features/external_data/domain/file_exporter.dart';
import 'package:inocencia/features/library/application/book_export.dart';
import 'package:inocencia/features/library/domain/library_book.dart';
import 'package:inocencia/features/library/domain/library_repository.dart';

void main() {
  late Directory tmp;
  late Directory src;
  late Directory dst;

  File make(String name, int bytes, {Directory? dir}) {
    final f = File('${(dir ?? src).path}/$name')..createSync(recursive: true);
    f.writeAsBytesSync(Uint8List.fromList(List.generate(bytes, (i) => (i * 7 + 3) % 251)));
    return f;
  }

  ExportItem item(File f) => ExportItem(path: f.path, sizeBytes: f.lengthSync());

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('inocencia_export_');
    src = Directory('${tmp.path}/origen')..createSync();
    dst = Directory('${tmp.path}/destino')..createSync();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('copiar', () {
    test('copia byte a byte, informa del avance y no deja .part', () async {
      final a = make('modelo.gguf', 2500);
      final b = make('libro.pdf', 1200);
      final progress = <CopyProgress>[];
      final result = await FileExporterImpl(chunkBytes: 1000, freeBytes: (_) async => null)
          .copy([item(a), item(b)], dst.path, onProgress: progress.add);

      expect(result.ok, isTrue);
      expect(result.copied, 2);
      expect(File('${dst.path}/modelo.gguf').readAsBytesSync(), a.readAsBytesSync());
      expect(File('${dst.path}/libro.pdf').readAsBytesSync(), b.readAsBytesSync());
      expect(dst.listSync().map((e) => e.path.split('/').last), isNot(contains(endsWith('.part'))));

      expect(progress.last.doneBytes, 3700);
      expect(progress.last.totalBytes, 3700);
      expect(progress.last.fraction, 1);
      expect(progress.first.fileIndex, 1);
      expect(progress.last.fileIndex, 2);
      expect(progress.last.fileCount, 2);
      expect(progress.last.fileName, 'libro.pdf');
      // El avance no retrocede nunca.
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i].doneBytes, greaterThan(progress[i - 1].doneBytes));
      }
    });

    test('un archivo vacío también se copia', () async {
      final a = make('vacio.db', 0);
      final result = await FileExporterImpl(freeBytes: (_) async => null).copy([item(a)], dst.path);
      expect(result.copied, 1);
      expect(File('${dst.path}/vacio.db').lengthSync(), 0);
    });

    test('cancelar a medias borra el .part y no deja un archivo roto', () async {
      final a = make('grande.gguf', 5000);
      final cancel = CopyCancel();
      final result = await FileExporterImpl(chunkBytes: 1000, freeBytes: (_) async => null).copy(
        [item(a)],
        dst.path,
        cancel: cancel,
        onProgress: (p) {
          if (p.doneBytes >= 2000) cancel.cancel();
        },
      );
      expect(result.cancelled, isTrue);
      expect(result.ok, isFalse);
      expect(dst.listSync(), isEmpty);
    });

    test('cancelar tras el primero conserva el que ya terminó', () async {
      final a = make('uno.pdf', 1000);
      final b = make('dos.pdf', 3000);
      final cancel = CopyCancel();
      final result = await FileExporterImpl(chunkBytes: 1000, freeBytes: (_) async => null).copy(
        [item(a), item(b)],
        dst.path,
        cancel: cancel,
        onProgress: (p) {
          if (p.fileIndex == 2) cancel.cancel();
        },
      );
      expect(result.cancelled, isTrue);
      expect(result.copied, 1);
      expect(dst.listSync().map((e) => e.path.split('/').last), ['uno.pdf']);
    });

    test('sin espacio en el destino ni empieza, y dice cuánto falta', () async {
      final a = make('modelo.gguf', 1000);
      final result = await FileExporterImpl(freeBytes: (_) async => 10).copy([item(a)], dst.path);
      expect(result.copied, 0);
      expect(result.error, contains('No hay espacio suficiente'));
      expect(dst.listSync(), isEmpty);
    });

    test('exige margen libre, no solo el tamaño justo', () async {
      final a = make('modelo.gguf', 1000);
      final result =
          await FileExporterImpl(freeBytes: (_) async => 1000).copy([item(a)], dst.path);
      expect(result.error, isNotNull);
    });

    test('copiar a la carpeta de origen se rechaza sin tocar el archivo', () async {
      final a = make('modelo.gguf', 1000);
      final result = await FileExporterImpl(freeBytes: (_) async => null).copy([item(a)], src.path);
      expect(result.error, contains('misma carpeta'));
      expect(a.lengthSync(), 1000);
    });

    test('un destino que no existe da un error claro', () async {
      final a = make('modelo.gguf', 10);
      final result = await FileExporterImpl(freeBytes: (_) async => null)
          .copy([item(a)], '${tmp.path}/no_existe');
      expect(result.error, contains('no existe'));
    });

    test('sustituye un archivo anterior con el mismo nombre', () async {
      final a = make('libro.pdf', 800);
      File('${dst.path}/libro.pdf').writeAsStringSync('viejo');
      final result = await FileExporterImpl(freeBytes: (_) async => null).copy([item(a)], dst.path);
      expect(result.ok, isTrue);
      expect(File('${dst.path}/libro.pdf').lengthSync(), 800);
    });

    test('sin archivos no hace nada', () async {
      final result = await FileExporterImpl(freeBytes: (_) async => null).copy([], dst.path);
      expect(result.copied, 0);
      expect(result.ok, isTrue);
    });
  });

  group('compartir', () {
    test('pasa al menú de Android solo los archivos que existen', () async {
      final a = make('uno.pdf', 10);
      List<String>? sent;
      String? sentTitle;
      final exporter = FileExporterImpl(shareFiles: (paths, title) async {
        sent = paths;
        sentTitle = title;
        return true;
      });
      final ok = await exporter.share([
        item(a),
        ExportItem(path: '${src.path}/borrado.pdf', sizeBytes: 5),
      ], title: 'Libros');
      expect(ok, isTrue);
      expect(sent, [a.path]);
      expect(sentTitle, 'Libros');
    });

    test('si no queda ningún archivo, no abre el menú y devuelve false', () async {
      var called = false;
      final exporter = FileExporterImpl(shareFiles: (_, _) async {
        called = true;
        return true;
      });
      expect(await exporter.share([ExportItem(path: '${src.path}/nada.pdf', sizeBytes: 1)]), isFalse);
      expect(called, isFalse);
    });
  });

  group('libros a exportar por grado', () {
    late File mates;
    late File mundo;
    late File lengua5;

    setUp(() {
      mates = make('6to_matematica.pdf', 600);
      mundo = make('1ro_2do_ca_el_mundo.pdf', 100);
      lengua5 = make('5to_lengua.pdf', 500);
    });

    LibraryBook book(String id, List<int> grades, File? file) => LibraryBook(
          id: id,
          title: id,
          subject: id,
          kind: 'Libro',
          grades: grades,
          pages: 10,
          path: file?.path,
        );

    _FakeLibrary library() => _FakeLibrary({
          1: [book('1ro_2do_ca_el_mundo', [1, 2], mundo)],
          2: [book('1ro_2do_ca_el_mundo', [1, 2], mundo)],
          3: [book('3ro_esp', [3], null)], // no esta en el telefono
          5: [book('5to_lengua', [5], lengua5)],
          6: [
            book('6to_matematica', [6], mates),
            book('6to_historia', [6], null),
          ],
        });

    test('un grado por cada uno con libros disponibles, de menor a mayor', () async {
      final all = await loadGradeExports(library());
      expect(all.map((g) => g.grade), [1, 2, 5, 6]);
      expect(all.last.count, 1);
      expect(all.last.bytes, 600);
    });

    test('los grados sin ningún PDF en el teléfono no salen', () async {
      final all = await loadGradeExports(library());
      expect(all.any((g) => g.grade == 3), isFalse);
    });

    test('un libro de dos grados no se repite al elegir ambos', () async {
      final all = await loadGradeExports(library());
      final items = exportItemsFor(all, {1, 2});
      expect(items, hasLength(1));
      expect(items.single.path, mundo.path);
    });

    test('solo los grados elegidos, con sus tamaños', () async {
      final all = await loadGradeExports(library());
      final items = exportItemsFor(all, {5, 6});
      expect(items.map((i) => i.sizeBytes).toList()..sort(), [500, 600]);
      expect(exportItemsFor(all, {}), isEmpty);
    });

    test('un libro borrado del teléfono tras detectarlo no se ofrece', () async {
      final lib = library();
      mates.deleteSync();
      final all = await loadGradeExports(lib);
      expect(all.any((g) => g.grade == 6), isFalse);
    });
  });
}

class _FakeLibrary implements LibraryRepository {
  _FakeLibrary(this.byGrade);

  final Map<int, List<LibraryBook>> byGrade;

  @override
  Future<List<LibraryBook>> booksForGrade(int grade) async => byGrade[grade] ?? const [];

  @override
  Future<LibraryStatus> status() async => LibraryStatus(
        total: 0,
        available: 0,
        folders: const [],
        byGrade: {for (final g in byGrade.keys) g: const GradeBooks(total: 1, available: 1)},
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
