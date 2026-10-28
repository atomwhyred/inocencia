import 'package:equatable/equatable.dart';

/// Un libro del catalogo. El texto de los libros va en la base de conocimiento;
/// el libro para leer es el PDF original, que se copia al telefono aparte.
class LibraryBook extends Equatable {
  const LibraryBook({
    required this.id,
    required this.title,
    required this.subject,
    required this.kind,
    required this.grades,
    required this.pages,
    this.path,
  });

  /// Nombre del PDF sin extension (`6to_matematica`): el mismo `book` que cita
  /// el tutor en sus fuentes.
  final String id;
  final String title;
  final String subject;

  /// `Libro` o `Cuaderno`.
  final String kind;
  final List<int> grades;
  final int pages;

  /// Donde esta el PDF en el telefono; null si aun no se ha copiado.
  final String? path;

  bool get available => path != null;
  bool get isNotebook => kind == 'Cuaderno';

  @override
  List<Object?> get props => [id, title, subject, kind, grades, pages, path];
}

/// Cuantos libros de un grado hay en el catalogo y cuantos estan en el telefono.
class GradeBooks extends Equatable {
  const GradeBooks({required this.total, required this.available});

  final int total;
  final int available;

  @override
  List<Object?> get props => [total, available];
}

/// Una carpeta del telefono que contiene PDF del catalogo.
class BookFolder extends Equatable {
  const BookFolder({required this.path, required this.count});

  final String path;

  /// PDF del catalogo que hay dentro (con subcarpetas).
  final int count;

  @override
  List<Object?> get props => [path, count];
}

/// Que libros hay en el catalogo y cuantos estan ya en el telefono.
class LibraryStatus extends Equatable {
  const LibraryStatus({
    required this.total,
    required this.available,
    required this.folders,
    this.linkedFolder,
    this.byGrade = const {},
  });

  final int total;
  final int available;

  /// Carpetas de la app donde el padre puede copiar los PDF.
  final List<String> folders;

  /// Carpeta que el padre vinculo para buscar mas PDF, si la hay.
  final String? linkedFolder;

  /// Por grado, para decir a cada padre si los libros de su hijo estan.
  final Map<int, GradeBooks> byGrade;

  @override
  List<Object?> get props => [total, available, folders, linkedFolder, byGrade];
}
