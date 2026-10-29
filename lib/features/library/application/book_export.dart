import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../external_data/domain/file_exporter.dart';
import '../domain/library_repository.dart';

/// Los PDF de un grado que estan en el telefono y se pueden exportar.
/// Un libro de varios grados (p. ej. 1.º y 2.º) sale en cada uno de ellos.
class GradeExport extends Equatable {
  const GradeExport({required this.grade, required this.byId});

  final int grade;

  /// `id del libro -> archivo`.
  final Map<String, ExportItem> byId;

  int get count => byId.length;
  int get bytes => byId.values.fold(0, (sum, i) => sum + i.sizeBytes);

  @override
  List<Object?> get props => [grade, byId];
}

/// Un [GradeExport] por cada grado que tenga algun PDF disponible, de menor a mayor.
Future<List<GradeExport>> loadGradeExports(LibraryRepository library) async {
  final status = await library.status();
  final result = <GradeExport>[];
  for (final grade in status.byGrade.keys.toList()..sort()) {
    final byId = <String, ExportItem>{};
    for (final book in await library.booksForGrade(grade)) {
      final path = book.path;
      if (path == null) continue;
      final file = File(path);
      if (!file.existsSync()) continue;
      byId[book.id] = ExportItem(path: path, sizeBytes: file.lengthSync());
    }
    if (byId.isNotEmpty) result.add(GradeExport(grade: grade, byId: byId));
  }
  return result;
}

/// Los archivos de los grados elegidos, sin repetir un libro que sirve a varios.
List<ExportItem> exportItemsFor(List<GradeExport> all, Set<int> grades) {
  final byId = <String, ExportItem>{};
  for (final g in all) {
    if (grades.contains(g.grade)) byId.addAll(g.byId);
  }
  return byId.values.toList()..sort((a, b) => a.path.compareTo(b.path));
}

final gradeExportsProvider = FutureProvider.autoDispose<List<GradeExport>>(
  (ref) => loadGradeExports(ref.watch(libraryRepositoryProvider)),
);
