import 'package:sqlite3/sqlite3.dart';

/// Abre en solo lectura una base que viene de fuera (la `knowledge.db` se pasa de
/// teléfono a teléfono por ShareIt, Zapya, Bluetooth...) con las defensas de SQLite
/// para esquemas no confiables:
///
/// - `trusted_schema=OFF`: las vistas y disparadores del archivo no pueden llamar a
///   funciones con efectos.
/// - `query_only=ON`: ninguna sentencia puede escribir.
/// - `cell_size_check=ON`: detecta antes una página corrupta o manipulada.
Database openUntrustedDb(String path) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    db.execute('PRAGMA trusted_schema = OFF');
    db.execute('PRAGMA query_only = ON');
    db.execute('PRAGMA cell_size_check = ON');
  } catch (_) {
    db.close();
    rethrow;
  }
  return db;
}
