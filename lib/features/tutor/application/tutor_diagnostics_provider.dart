import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tutor_diagnostics.dart';

/// Ultimo diagnostico del tutor. Vive aparte del motor (que se libera al salir
/// del chat) para que la zona de padres pueda mostrarlo despues.
class TutorDiagnosticsNotifier extends Notifier<TutorDiagnostics> {
  @override
  TutorDiagnostics build() => const TutorDiagnostics();

  void loaded(TutorDiagnostics d) => state = d;

  void answered({
    required int firstPieceSeconds,
    required int pieces,
    required int totalSeconds,
    required double piecesPerSecond,
  }) {
    if (state.isEmpty) return;
    state = state.withAnswer(
      firstPieceSeconds: firstPieceSeconds,
      pieces: pieces,
      totalSeconds: totalSeconds,
      piecesPerSecond: piecesPerSecond,
    );
  }
}

final tutorDiagnosticsProvider = NotifierProvider<TutorDiagnosticsNotifier, TutorDiagnostics>(
  TutorDiagnosticsNotifier.new,
);
