import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../domain/speech_service.dart';

/// Voz del propio Android mediante `flutter_tts`: funciona sin internet con el
/// motor de sintesis que el telefono ya tenga instalado.
class FlutterTtsService implements SpeechService {
  FlutterTtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  Completer<bool>? _current;
  Future<bool>? _ready;

  /// De la mas cercana al niño a la mas general.
  static const _languages = ['es-CU', 'es-MX', 'es-ES', 'es-US', 'es'];

  /// Un poco mas lenta que lo normal: los ninos la siguen mejor.
  static const rate = 0.45;

  @override
  Future<bool> prepare() => _ready ??= _prepare();

  /// El motor de voz de Android se conecta a destiempo: justo tras crearlo
  /// puede decir que no tiene idiomas. Se reintenta un par de veces.
  Future<bool> _prepare() async {
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final lang = await _pickLanguage();
        if (lang != null) {
          await _tts.setLanguage(lang);
          await _tts.setSpeechRate(rate);
          await _tts.setPitch(1.1);
          await _tts.awaitSpeakCompletion(true);
          _tts.setCompletionHandler(() => _finish(true));
          _tts.setCancelHandler(() => _finish(false));
          _tts.setErrorHandler((_) => _finish(false));
          return true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[voz] no se pudo preparar: $e');
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  /// El idioma preferido que el motor tenga, o cualquier otro en espanol.
  Future<String?> _pickLanguage() async {
    final installed = <String>[
      for (final l in (await _tts.getLanguages as List?) ?? const []) l.toString(),
    ];
    if (kDebugMode) debugPrint('[voz] idiomas del motor: $installed');
    String norm(String l) => l.replaceAll('_', '-').toLowerCase();
    for (final wanted in _languages) {
      for (final l in installed) {
        if (norm(l) == norm(wanted)) return l;
      }
    }
    for (final l in installed) {
      if (norm(l).startsWith('es')) return l;
    }
    return null;
  }

  void _finish(bool completed) {
    final c = _current;
    _current = null;
    if (c != null && !c.isCompleted) c.complete(completed);
  }

  @override
  Future<bool> speak(String sentence) async {
    // Una frase nueva corta la anterior.
    _finish(false);
    final done = Completer<bool>();
    _current = done;
    try {
      await _tts.speak(sentence);
    } catch (e) {
      _finish(false);
    }
    return done.future;
  }

  @override
  Future<void> stop() async {
    _finish(false);
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() => stop();
}
