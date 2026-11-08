import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/providers.dart';
import '../domain/tutor_diagnostics.dart';

/// Ultimo diagnostico del tutor. Vive aparte del motor (que se libera al salir
/// del chat) para que la zona de padres pueda mostrarlo despues, y se guarda en
/// el telefono para que siga ahi aunque se cierre la app.
class TutorDiagnosticsNotifier extends Notifier<TutorDiagnostics> {
  static const _key = 'tutor_diagnostics';

  SharedPreferences? _prefs;

  @override
  TutorDiagnostics build() {
    try {
      _prefs = ref.read(sharedPreferencesProvider);
    } catch (_) {
      _prefs = null; // en pruebas sin preferencias, solo en memoria
    }
    final saved = _prefs?.getString(_key);
    if (saved == null) return const TutorDiagnostics();
    try {
      return TutorDiagnostics.fromJson(
        jsonDecode(saved) as Map<String, Object?>,
      );
    } catch (_) {
      return const TutorDiagnostics();
    }
  }

  void loaded(TutorDiagnostics d) => _set(d);

  void answered({
    required int firstPieceSeconds,
    required int pieces,
    required int totalSeconds,
    required double piecesPerSecond,
    int? promptChars,
    int? promptTokens,
  }) {
    if (state.isEmpty) return;
    _set(
      state.withAnswer(
        firstPieceSeconds: firstPieceSeconds,
        pieces: pieces,
        totalSeconds: totalSeconds,
        piecesPerSecond: piecesPerSecond,
        promptChars: promptChars,
        promptTokens: promptTokens,
      ),
    );
  }

  void _set(TutorDiagnostics d) {
    state = d;
    _prefs?.setString(_key, jsonEncode(d.toJson())).ignore();
  }
}

final tutorDiagnosticsProvider =
    NotifierProvider<TutorDiagnosticsNotifier, TutorDiagnostics>(
      TutorDiagnosticsNotifier.new,
    );
