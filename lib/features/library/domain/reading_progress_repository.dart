/// Por donde va cada nino en cada libro.
abstract class ReadingProgressRepository {
  /// Ultima pagina vista (desde 1), o null si no lo ha abierto.
  Future<int?> get(int childId, String book);

  Future<void> save(int childId, String book, int page);

  /// Todas las paginas guardadas del nino, por libro.
  Future<Map<String, int>> all(int childId);
}
