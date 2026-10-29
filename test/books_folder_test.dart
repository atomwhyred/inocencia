import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inocencia/core/di/providers.dart';
import 'package:inocencia/core/security/pin_hasher.dart';
import 'package:inocencia/core/storage/app_database.dart';
import 'package:inocencia/features/external_data/data/external_files_repository_impl.dart';
import 'package:inocencia/features/external_data/domain/external_files_repository.dart';
import 'package:inocencia/features/external_data/domain/file_exporter.dart';
import 'package:inocencia/features/external_data/domain/linked_file_status.dart';
import 'package:inocencia/features/external_data/presentation/files_section.dart';
import 'package:inocencia/features/external_data/presentation/path_browser_page.dart';
import 'package:inocencia/features/profiles/data/child_profile_repository_impl.dart';
import 'package:inocencia/features/profiles/domain/child_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

class _Files implements ExternalFilesRepository {
  _Files(this.knowledgePath, this.appDir, this.phone);

  @override
  final String? knowledgePath;
  final String appDir;
  final String phone;

  @override
  String? booksFolder;

  @override
  Future<void> setBooksFolder(String? path) async => booksFolder = path;

  @override
  Future<LinkedFilesStatus> check() async => LinkedFilesStatus(
        model: const LinkedFileStatus(state: LinkState.ready, path: '/fake/model.gguf'),
        knowledge: KnowledgeDbStatus(state: LinkState.ready, path: knowledgePath),
      );

  @override
  Future<List<String>> appStorageDirs() async => [appDir];

  @override
  Future<List<String>> browseRoots() async => [appDir, phone];

  @override
  Future<bool> get needsAllFilesAccess async => false;

  @override
  Future<bool> get hasAllFilesAccess async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Apunta lo que la pantalla pide exportar, sin abrir el menu de Android ni copiar.
class _FakeExporter implements FileExporter {
  final shared = <List<ExportItem>>[];
  final copied = <List<ExportItem>>[];

  @override
  Future<bool> share(List<ExportItem> items, {String? title}) async {
    shared.add(items);
    return true;
  }

  @override
  Future<CopyResult> copy(List<ExportItem> items, String destDir,
      {void Function(CopyProgress progress)? onProgress, CopyCancel? cancel}) async {
    copied.add(items);
    return CopyResult(copied: items.length);
  }
}

void main() {
  test('la carpeta de libros que elige el padre se recuerda y se puede quitar', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = ExternalFilesRepositoryImpl(await SharedPreferences.getInstance());
    expect(repo.booksFolder, isNull);
    await repo.setBooksFolder('/storage/emulated/0/Download/libros');
    expect(repo.booksFolder, '/storage/emulated/0/Download/libros');
    // Otra instancia sobre las mismas preferencias (como al reabrir la app).
    expect(ExternalFilesRepositoryImpl(await SharedPreferences.getInstance()).booksFolder,
        '/storage/emulated/0/Download/libros');
    await repo.setBooksFolder(null);
    expect(repo.booksFolder, isNull);
  });

  group('tarjeta "Libros para leer" de la zona de padres', () {
    late Directory tmp;
    late AppDatabase db;
    late _Files files;
    late _FakeExporter exporter;

    // Los tres cuadros de archivos tienen "Quitar vínculo": se toma el de la tarjeta de libros.
    final quitarBooks = find.descendant(
      of: find.ancestor(of: find.text('Libros para leer (PDF)'), matching: find.byType(Card)),
      matching: find.text('Quitar vínculo'),
    );

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 150; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 15));
      }
    }

    Future<void> boot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      tmp = Directory.systemTemp.createTempSync('inocencia_carpeta_');
      Directory('${tmp.path}/files').createSync();
      for (final f in ['6to_matematica', '6to_esp', '3ro_matematica']) {
        File('${tmp.path}/phone/Download/libros/$f.pdf')
          ..createSync(recursive: true)
          ..writeAsBytesSync([0x25, 0x50, 0x44, 0x46]);
      }
      final kb = sql.sqlite3.open('${tmp.path}/knowledge.db');
      kb.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
      kb.execute("INSERT INTO meta VALUES ('books', ?)", [
        jsonEncode([
          {'file': '6to_matematica.pdf', 'subject': 'Matemática', 'grades': [6], 'kind': 'Libro', 'pages': 9},
          {'file': '6to_esp.pdf', 'subject': 'Español', 'grades': [6], 'kind': 'Libro', 'pages': 9},
          {'file': '6to_historia.pdf', 'subject': 'Historia', 'grades': [6], 'kind': 'Libro', 'pages': 9},
          {'file': '3ro_matematica.pdf', 'subject': 'Matemática', 'grades': [3], 'kind': 'Libro', 'pages': 9},
          {'file': '4to_matematica.pdf', 'subject': 'Matemática', 'grades': [4], 'kind': 'Libro', 'pages': 9},
        ]),
      ]);
      kb.close();

      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      final profiles = ChildProfileRepositoryImpl(db, const PinHasher(iterations: 10));
      for (final (name, grade) in [('Leo', 6), ('Ana', 3), ('Teo', 4), ('Eva', 2)]) {
        await profiles.create(ChildProfileInput(
          name: name,
          avatar: 'emoji:🦊',
          birthDate: DateTime(2015, 3, 1),
          gradeOverride: grade,
        ));
      }
      files = _Files('${tmp.path}/knowledge.db', '${tmp.path}/files', '${tmp.path}/phone');
      exporter = _FakeExporter();

      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        externalFilesRepositoryProvider.overrideWithValue(files),
        fileExporterProvider.overrideWithValue(exporter),
        deviceRamProvider.overrideWith((ref) async => null),
      ]);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.runAsync(db.close);
        tmp.deleteSync(recursive: true);
      });
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: FilesSection())),
      ));
      await settle(tester);
    }

    testWidgets('sin carpeta vinculada, cada niño ve que le faltan sus libros', (tester) async {
      await boot(tester);
      expect(find.text('0 de 5 libros están en este teléfono.'), findsOneWidget);
      expect(find.textContaining('Leo (6.º grado): 0 de 3 libros'), findsOneWidget);
      expect(find.textContaining('Ana (3.º grado): 0 de 1 libros'), findsOneWidget);
      expect(find.textContaining('Eva (2.º grado): la base no tiene libros de este grado.'), findsOneWidget);
      expect(quitarBooks, findsNothing);
    });

    testWidgets('Detectar encuentra la carpeta y los libros de cada niño aparecen', (tester) async {
      await boot(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Detectar').last);
      await settle(tester);

      final folder = '${tmp.path}/phone/Download/libros';
      expect(find.text('$folder\n3 libros'), findsOneWidget);
      await tester.tap(find.text('$folder\n3 libros'));
      await settle(tester);

      expect(files.booksFolder, folder);
      expect(find.textContaining('Leo (6.º grado): 2 de 3 libros'), findsOneWidget);
      expect(find.textContaining('Ana (3.º grado): 1 de 1 libros'), findsOneWidget);
      expect(find.textContaining('Teo (4.º grado): 0 de 1 libros'), findsOneWidget);
      expect(find.text('3 de 5 libros están en este teléfono.'), findsOneWidget);
      expect(quitarBooks, findsOneWidget);
    });

    testWidgets('Quitar vínculo vuelve a dejar los libros sin encontrar', (tester) async {
      await boot(tester);
      files.booksFolder = '${tmp.path}/phone/Download/libros';
      await tester.tap(find.text('Comprobar de nuevo'));
      await settle(tester);
      expect(find.textContaining('Leo (6.º grado): 2 de 3 libros'), findsOneWidget);

      await tester.tap(quitarBooks);
      await settle(tester);
      expect(files.booksFolder, isNull);
      expect(find.textContaining('Leo (6.º grado): 0 de 3 libros'), findsOneWidget);
    });

    testWidgets('las tres tarjetas llevan los mismos botones, con "Buscar" igual en todas', (tester) async {
      await boot(tester);
      expect(find.text('Buscar'), findsNWidgets(3));
      expect(find.text('Buscar carpeta'), findsNothing);
      expect(find.text('Detectar'), findsNWidgets(3));
      expect(find.text('Compartir'), findsNWidgets(3));
      expect(find.text('Copiar a…'), findsNWidgets(3));
      // El mismo tipo de boton y el mismo estilo en las tres.
      final browse = tester.widgetList<FilledButton>(find.widgetWithText(FilledButton, 'Buscar')).toList();
      expect(browse, hasLength(3));
      final detect = tester.widgetList<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Detectar')).toList();
      expect(detect, hasLength(3));
    });

    testWidgets('el modelo y la base se pueden compartir; los libros no, mientras no haya ninguno',
        (tester) async {
      await boot(tester);
      OutlinedButton share(int card) =>
          tester.widgetList<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Compartir')).toList()[card];
      expect(share(0).onPressed, isNotNull); // modelo
      expect(share(1).onPressed, isNotNull); // base
      expect(share(2).onPressed, isNull); // libros: ninguno copiado
    });

    testWidgets('compartir el modelo pasa su ruta al menu de compartir', (tester) async {
      await boot(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Compartir').first);
      await tester.pump();
      expect(exporter.shared, hasLength(1));
      expect(exporter.shared.single.single.path, '/fake/model.gguf');
    });

    testWidgets('los libros se eligen por grado y no se repiten al compartir', (tester) async {
      await boot(tester);
      files.booksFolder = '${tmp.path}/phone/Download/libros';
      await tester.tap(find.text('Comprobar de nuevo'));
      await settle(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Compartir').last);
      await settle(tester);

      expect(find.text('Compartir libros'), findsOneWidget);
      expect(find.text('Todos los grados'), findsOneWidget);
      expect(find.text('3.º grado'), findsOneWidget);
      expect(find.text('6.º grado'), findsOneWidget);
      expect(find.text('1 libro · 4 B'), findsOneWidget); // 3.º: un PDF de prueba
      expect(find.text('2 libros · 8 B'), findsOneWidget); // 6.º: dos
      expect(find.text('3 archivos · 12 B'), findsOneWidget);

      // Quitar el 3.º deja solo los de 6.º.
      await tester.tap(find.text('3.º grado'));
      await tester.pump();
      expect(find.text('2 archivos · 8 B'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Compartir'));
      await settle(tester);
      expect(exporter.shared, hasLength(1));
      expect(exporter.shared.single.map((i) => i.path.split('/').last).toList()..sort(),
          ['6to_esp.pdf', '6to_matematica.pdf']);
    });

    testWidgets('sin ningún grado elegido no se envía nada', (tester) async {
      await boot(tester);
      files.booksFolder = '${tmp.path}/phone/Download/libros';
      await tester.tap(find.text('Comprobar de nuevo'));
      await settle(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Compartir').last);
      await settle(tester);

      await tester.tap(find.text('Todos los grados'));
      await tester.pump();
      expect(find.text('No hay ningún grado elegido.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Compartir'));
      await tester.pump();
      expect(exporter.shared, isEmpty);
      expect(find.text('Compartir libros'), findsOneWidget); // el diálogo sigue abierto
    });
  });

  group('explorador en modo carpeta', () {
    late Directory tmp;
    String? picked;

    Future<void> boot(WidgetTester tester) async {
      tmp = Directory.systemTemp.createTempSync('inocencia_explorador_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      Directory('${tmp.path}/phone/libros').createSync(recursive: true);
      File('${tmp.path}/phone/libros/6to_esp.pdf').writeAsBytesSync([0x25, 0x50, 0x44, 0x46]);
      File('${tmp.path}/phone/libros/notas.txt').writeAsStringSync('x');
      picked = null;
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (c, _) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  picked = await c.push<String>('/browse', extra: const BrowseRequest(
                    title: 'Elegir carpeta',
                    extensions: ['.pdf'],
                    pickFolder: true,
                  )),
              child: const Text('abrir'),
            ),
          ),
        ),
        GoRoute(
          path: '/browse',
          builder: (c, state) => PathBrowserPage(request: state.extra! as BrowseRequest),
        ),
      ]);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          externalFilesRepositoryProvider
              .overrideWithValue(_Files(null, '${tmp.path}/phone', '${tmp.path}/phone')),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.tap(find.text('abrir'));
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 15));
      }
    }

    testWidgets('elige la carpeta abierta y cuenta sus PDF; los archivos no se pueden elegir',
        (tester) async {
      await boot(tester);
      await tester.tap(find.text('libros'));
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 15));
      }
      expect(find.text('Usar esta carpeta (1 PDF)'), findsOneWidget);
      expect(find.text('notas.txt'), findsNothing);

      await tester.tap(find.text('6to_esp.pdf'), warnIfMissed: false);
      await tester.pump();
      expect(picked, isNull);

      await tester.tap(find.text('Usar esta carpeta (1 PDF)'));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 15));
      }
      expect(picked, '${tmp.path}/phone/libros');
    });
  });
}
