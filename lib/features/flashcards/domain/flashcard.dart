import 'package:equatable/equatable.dart';

import '../../../core/utils/plain_text.dart';

/// Una tarjeta nueva, aun sin guardar: pregunta al frente y respuesta al reverso.
class FlashcardDraft extends Equatable {
  const FlashcardDraft({required this.front, required this.back, this.source});

  final String front;
  final String back;

  /// De que libro y pagina sale (`Español · 2do_lengua · pág. 138`).
  final String? source;

  FlashcardDraft withSource(String? source) =>
      FlashcardDraft(front: front, back: back, source: source);

  @override
  List<Object?> get props => [front, back, source];
}

/// Una tarjeta guardada de un nino, con lo que lleva de repaso.
class Flashcard extends Equatable {
  const Flashcard({
    required this.id,
    required this.front,
    required this.back,
    this.source,
    this.timesKnown = 0,
    this.timesReviewed = 0,
  });

  final int id;
  final String front;
  final String back;
  final String? source;

  /// Veces que dijo "la sabia" y veces que la repaso.
  final int timesKnown;
  final int timesReviewed;

  @override
  List<Object?> get props => [id, front, back, source, timesKnown, timesReviewed];
}

/// Comprueba que una tarjeta se apoya en el libro. Un modelo pequeno inventa:
/// como el nino memorizaria algo falso, solo se aceptan las tarjetas cuyo
/// reverso esta hecho con palabras del texto del libro y que se entienden sin
/// tener delante la pagina.
class FlashcardGrounding {
  const FlashcardGrounding._();

  /// Parte minima de las palabras importantes del reverso que debe salir del libro.
  static const minShare = 0.6;

  static const maxFront = 140;
  static const maxBack = 220;

  static bool isGrounded(FlashcardDraft card, String bookText) {
    final front = card.front.trim();
    final back = card.back.trim();
    if (front.length < 4 || front.length > maxFront) return false;
    if (back.length < 2 || back.length > maxBack) return false;
    if (plainText(front) == plainText(back)) return false;
    if (dependsOnBookLayout(front) || dependsOnBookLayout(back)) return false;
    final book = ' ${plainText(bookText)} ';
    final words = plainText(back).split(' ').where((w) => w.length >= 4).toSet();
    // Una respuesta corta ("el sol") se busca entera.
    if (words.isEmpty) return book.contains(' ${plainText(back)} ');
    final found = words.where((w) => book.contains(' $w ')).length;
    return found / words.length >= minShare;
  }
}
