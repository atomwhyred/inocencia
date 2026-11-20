import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../flashcards/application/flashcard_providers.dart';
import '../data/sqlite_question_bank.dart';
import '../domain/game_question.dart';

/// Abre el banco de preguntas de una base de libros (se sobrescribe en pruebas).
final questionBankFactoryProvider =
    Provider<QuestionBank Function(String path)>(
      (ref) => SqliteQuestionBank.open,
    );

final gameRandomProvider = Provider<Random>((ref) => Random());

/// Si en el juego en red se envía la miniatura de la foto del niño a los demás
/// teléfonos. Apagado por defecto: sin él, el niño aparece con un emoji.
class LanSharePhotoController extends Notifier<bool> {
  static const _key = 'lan_share_photo';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final lanSharePhotoProvider =
    NotifierProvider<LanSharePhotoController, bool>(LanSharePhotoController.new);

/// Por que un nino no tiene preguntas para jugar.
class NoQuestionsException implements Exception {
  const NoQuestionsException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Prepara las preguntas de un nino: banco de su grado + sus tarjetas.
class GameDeckBuilder {
  GameDeckBuilder(this._ref);

  final Ref _ref;

  /// Cuantas preguntas del banco se cargan por nino (de sobra para una partida).
  static const bankQuestions = 60;

  Future<QuestionDeck> build({required int grade, int? childId}) async {
    final random = _ref.read(gameRandomProvider);
    var bank = const <GameQuestion>[];
    final path = _ref.read(externalFilesRepositoryProvider).knowledgePath;
    if (path != null) {
      try {
        final b = _ref.read(questionBankFactoryProvider)(path);
        try {
          bank = b.forGrade(grade, count: bankQuestions, random: random);
        } finally {
          b.close();
        }
      } catch (_) {
        // Base ilegible: se juega solo con las tarjetas.
      }
    }
    var cards = const <GameQuestion>[];
    if (childId != null) {
      final deck = await _ref
          .read(flashcardRepositoryProvider)
          .watchDeck(childId)
          .first;
      cards = CardQuestions.fromDeck(deck, random);
    }
    return QuestionDeck(bank, cards, random);
  }
}

final gameDeckBuilderProvider = Provider<GameDeckBuilder>(GameDeckBuilder.new);
