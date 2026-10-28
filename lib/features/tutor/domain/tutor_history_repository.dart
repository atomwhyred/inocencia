import 'package:equatable/equatable.dart';

import 'tutor_source.dart';

/// Un mensaje de la conversacion tal y como se guarda.
class StoredTutorMessage extends Equatable {
  const StoredTutorMessage({
    required this.fromUser,
    required this.text,
    this.sources = const [],
    this.createdAt,
  });

  final bool fromUser;
  final String text;
  final List<TutorSource> sources;

  /// Lo pone la base al guardar; null en un mensaje aun sin guardar.
  final DateTime? createdAt;

  @override
  List<Object?> get props => [fromUser, text, sources, createdAt];
}

/// Conversaciones del tutor, una por nino.
abstract class TutorHistoryRepository {
  /// Los ultimos [limit] mensajes del nino, del mas antiguo al mas reciente.
  Future<List<StoredTutorMessage>> load(int childId, {int limit = 200});

  Future<void> add(int childId, StoredTutorMessage message);

  /// Borra toda la conversacion del nino.
  Future<void> clear(int childId);

  Future<int> count(int childId);
}
