import 'flashcard.dart';

abstract class FlashcardRepository {
  /// Mazo del nino, al dia mientras cambie (mas nuevas primero).
  Stream<List<Flashcard>> watchDeck(int childId);

  /// Guarda las tarjetas nuevas y devuelve cuantas entraron (se omiten las que
  /// el nino ya tiene con la misma pregunta).
  Future<int> addAll(int childId, List<FlashcardDraft> drafts, DateTime at);

  /// Anota un repaso de la tarjeta [id].
  Future<void> markReviewed(int id, {required bool known, required DateTime at});

  Future<void> delete(int id);
}
