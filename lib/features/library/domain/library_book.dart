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

/// Que libros hay en el catalogo y cuantos estan ya en el telefono.
class LibraryStatus extends Equatable {
  const LibraryStatus({required this.total, required this.available, required this.folders});

  final int total;
  final int available;

  /// Carpetas donde el padre debe copiar los PDF.
  final List<String> folders;

  @override
  List<Object?> get props => [total, available, folders];
}
