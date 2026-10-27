import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Quien esta usando la app ahora mismo (solo en memoria).
class SessionState extends Equatable {
  const SessionState({this.parentUnlocked = false, this.activeChildId});

  /// El padre ya introdujo su PIN: puede entrar al panel de administracion.
  final bool parentUnlocked;

  /// Nino que esta estudiando.
  final int? activeChildId;

  SessionState copyWith({
    bool? parentUnlocked,
    int? activeChildId,
    bool clearChild = false,
  }) =>
      SessionState(
        parentUnlocked: parentUnlocked ?? this.parentUnlocked,
        activeChildId: clearChild ? null : (activeChildId ?? this.activeChildId),
      );

  @override
  List<Object?> get props => [parentUnlocked, activeChildId];
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  void unlockParent() => state = state.copyWith(parentUnlocked: true);
  void lockParent() => state = state.copyWith(parentUnlocked: false);
  void selectChild(int id) => state = state.copyWith(activeChildId: id);
  void clearChild() => state = state.copyWith(clearChild: true);

  /// Cierra todo (p. ej. al enviar la app a segundo plano).
  void lockAll() => state = const SessionState();
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
