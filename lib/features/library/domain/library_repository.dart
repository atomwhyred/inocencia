import 'library_book.dart';

abstract class LibraryRepository {
  /// Libros del grado (con su PDF si ya esta en el telefono), libros antes que
  /// cuadernos.
  Future<List<LibraryBook>> booksForGrade(int grade);

  Future<LibraryBook?> find(String id);

  Future<LibraryStatus> status();
}
