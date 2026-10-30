import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../auth/application/session.dart';
import '../../tutor/application/tutor_controller.dart';
import '../data/flashcard_repository_impl.dart';
import '../data/llama_flashcard_generator.dart';
import '../domain/flashcard.dart';
import '../domain/flashcard_generator.dart';
import '../domain/flashcard_repository.dart';

final flashcardRepositoryProvider = Provider<FlashcardRepository>(
  (ref) => FlashcardRepositoryImpl(ref.watch(appDatabaseProvider)),
);

/// Crea las tarjetas con el modelo local. Se sobrescribe en las pruebas.
final flashcardGeneratorProvider = Provider.autoDispose<FlashcardGenerator>(
  (ref) => LlamaFlashcardGenerator(ref.watch(tutorEngineProvider)),
);

/// Orden de las tarjetas en el repaso; las pruebas lo fijan.
final flashcardRandomProvider = Provider<Random>((ref) => Random());

/// Mazo del nino activo, al dia mientras cambie.
final flashcardDeckProvider = StreamProvider.autoDispose<List<Flashcard>>((ref) {
  final id = ref.watch(sessionProvider).activeChildId;
  if (id == null) return const Stream.empty();
  return ref.watch(flashcardRepositoryProvider).watchDeck(id);
});
