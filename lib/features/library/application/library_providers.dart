import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../auth/application/active_child.dart';
import '../domain/library_book.dart';

/// Libros del grado del nino activo, con su PDF si ya esta en el telefono.
final childBooksProvider = FutureProvider.autoDispose<List<LibraryBook>>((ref) async {
  final grade = ref.watch(activeGradeProvider);
  if (grade == null) return const [];
  return ref.watch(libraryRepositoryProvider).booksForGrade(grade);
});

/// Pagina por la que va el nino en cada libro. Se invalida al volver del lector.
final readingProgressProvider =
    FutureProvider.autoDispose.family<Map<String, int>, int>(
  (ref, childId) => ref.watch(readingProgressRepositoryProvider).all(childId),
);

/// Cuantos libros hay en el catalogo y cuantos estan ya en el telefono.
final libraryStatusProvider = FutureProvider.autoDispose<LibraryStatus>(
  (ref) => ref.watch(libraryRepositoryProvider).status(),
);
