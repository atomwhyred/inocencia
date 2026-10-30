import '../../knowledge/domain/knowledge_chunk.dart';
import 'flashcard.dart';

/// Crea tarjetas a partir de textos del libro. La implementacion real usa el
/// modelo local; el resto de la app solo conoce esta interfaz.
abstract class FlashcardGenerator {
  /// Las tarjetas van saliendo en cuanto estan listas (un 3B tarda ~40 s por
  /// tarjeta). El stream termina al acabar; cancelar la suscripcion detiene el
  /// modelo. Lanza si no se puede generar.
  Stream<FlashcardDraft> generate({required int grade, required List<KnowledgeChunk> chunks});
}
