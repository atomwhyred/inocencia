import 'library_book.dart';

abstract class LibraryRepository {
  /// Libros del grado (con su PDF si ya esta en el telefono), libros antes que
  /// cuadernos.
  Future<List<LibraryBook>> booksForGrade(int grade);

  Future<LibraryBook?> find(String id);

  Future<LibraryStatus> status();

  /// Busca en el almacenamiento carpetas con PDF del catalogo (hasta 3 niveles).
  /// La que mas libros tiene va primero. Fuera de la carpeta de la app solo ve
  /// lo que Android deja listar (hace falta "Acceso a todos los archivos").
  Future<List<BookFolder>> findBookFolders();
}
