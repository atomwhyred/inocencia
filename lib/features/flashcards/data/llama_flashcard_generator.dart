import 'dart:async';

import '../../knowledge/domain/knowledge_chunk.dart';
import '../../tutor/domain/tutor_engine.dart';
import '../../tutor/domain/tutor_source.dart';
import '../domain/flashcard.dart';
import '../domain/flashcard_generator.dart';
import '../domain/flashcard_parser.dart';
import '../domain/flashcard_prompt.dart';

/// Genera las tarjetas con el modelo local (el mismo [TutorEngine] del chat).
class LlamaFlashcardGenerator implements FlashcardGenerator {
  LlamaFlashcardGenerator(this._engine);

  final TutorEngine _engine;

  @override
  Stream<FlashcardDraft> generate({
    required int grade,
    required List<KnowledgeChunk> chunks,
  }) async* {
    final turns = FlashcardPrompt.build(grade: grade, chunks: chunks);
    final bookText = chunks.map((c) => c.text).join(' ');
    final source = chunks.isEmpty ? null : TutorSource.fromChunk(chunks.first).label;
    final seen = <String>{};
    var emitted = 0;

    // Si la primera vez no sale ninguna tarjeta valida se reintenta una vez.
    for (var attempt = 0; attempt < 2 && emitted == 0; attempt++) {
      final buf = StringBuffer();
      await for (final piece in _engine.generate(turns, maxTokens: FlashcardPrompt.maxTokens)) {
        buf.write(piece);
        // Mientras llega el texto, la ultima tarjeta puede estar a medias.
        final ready = FlashcardParser.parse(buf.toString(), complete: false);
        for (final card in ready) {
          if (emitted >= FlashcardPrompt.cards) break;
          if (!seen.add(card.front) || !FlashcardGrounding.isGrounded(card, bookText)) continue;
          emitted++;
          yield card.withSource(source);
        }
        if (emitted >= FlashcardPrompt.cards) return;
      }
      for (final card in FlashcardParser.parse(buf.toString())) {
        if (emitted >= FlashcardPrompt.cards) break;
        if (!seen.add(card.front) || !FlashcardGrounding.isGrounded(card, bookText)) continue;
        emitted++;
        yield card.withSource(source);
      }
    }
  }
}
