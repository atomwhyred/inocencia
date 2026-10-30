import 'flashcard.dart';

/// Lee las tarjetas que escribe el modelo (`T1: pregunta` / `R: respuesta`).
/// Es tolerante con mayusculas, numeracion y espacios, y descarta las tarjetas
/// mal formadas en vez de fallar.
class FlashcardParser {
  const FlashcardParser._();

  static final _front = RegExp(
    r'^\s*(?:tarjeta|pregunta|t|p)?\s*\d+\s*[:.)\-]\s*(.+)$',
    caseSensitive: false,
  );
  static final _back = RegExp(r'^\s*(?:respuesta|r)\s*[:=\-]\s*(.+)$', caseSensitive: false);

  /// Con [complete] en `false` la ultima tarjeta se deja fuera: el modelo puede
  /// estar aun escribiendo su reverso.
  static List<FlashcardDraft> parse(String raw, {bool complete = true}) {
    final out = <FlashcardDraft>[];
    String? front;
    String? back;

    void close() {
      final f = front;
      final b = back;
      if (f != null && b != null && f.isNotEmpty && b.isNotEmpty) {
        out.add(FlashcardDraft(front: f, back: b));
      }
      front = null;
      back = null;
    }

    for (final line in raw.replaceAll('**', '').split('\n')) {
      final back0 = _back.firstMatch(line);
      if (back0 != null && front != null) {
        back = back0.group(1)!.trim();
        continue;
      }
      final front0 = _front.firstMatch(line);
      if (front0 != null) {
        close();
        front = front0.group(1)!.trim();
      }
    }
    if (complete) close();
    return out;
  }
}
