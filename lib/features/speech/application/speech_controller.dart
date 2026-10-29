import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../pomodoro/application/pomodoro.dart';
import '../data/flutter_tts_service.dart';
import '../domain/speech_service.dart';
import '../domain/speech_text.dart';

/// Si el padre deja que los ninos escuchen las respuestas. Viene activado.
class SpeechEnabledController extends Notifier<bool> {
  static const _key = 'speech_enabled';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final speechEnabledProvider = NotifierProvider<SpeechEnabledController, bool>(
  SpeechEnabledController.new,
);

/// Voz del dispositivo. Las pruebas la sustituyen por una falsa.
final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = FlutterTtsService();
  ref.onDispose(service.dispose);
  return service;
});

class SpeechState extends Equatable {
  const SpeechState({this.messageId, this.status = SpeechStatus.idle});

  /// Mensaje que se esta leyendo (o que esta en pausa).
  final int? messageId;
  final SpeechStatus status;

  bool isActive(int id) => messageId == id && status != SpeechStatus.idle;

  @override
  List<Object?> get props => [messageId, status];
}

/// Lee en voz alta una respuesta del tutor: reproducir, pausar y parar. Solo
/// suena un mensaje a la vez.
class SpeechController extends Notifier<SpeechState> {
  /// Cada lectura nueva (o parada) invalida a la anterior.
  int _token = 0;
  List<String> _sentences = const [];
  int _next = 0;

  @override
  SpeechState build() {
    // En el descanso del Pomodoro el chat se calla.
    ref.listen(chatFrozenProvider, (_, frozen) {
      if (frozen) stop();
    });
    return const SpeechState();
  }

  /// Lee el mensaje [id], o sigue donde lo dejo si estaba en pausa.
  Future<void> play(int id, String text) async {
    final service = ref.read(speechServiceProvider);
    if (state.messageId == id && state.status == SpeechStatus.paused) {
      await _run(service, id, _next);
      return;
    }
    _token++;
    await service.stop();
    _sentences = SpeechText.sentences(text);
    _next = 0;
    if (_sentences.isEmpty) {
      _token++;
      state = const SpeechState();
      return;
    }
    await _run(service, id, 0);
  }

  Future<void> _run(SpeechService service, int id, int from) async {
    final token = ++_token;
    state = SpeechState(messageId: id, status: SpeechStatus.speaking);
    if (!await service.prepare()) {
      if (token == _token) state = SpeechState(messageId: id, status: SpeechStatus.unavailable);
      return;
    }
    for (var i = from; i < _sentences.length; i++) {
      if (token != _token) return;
      _next = i;
      final finished = await service.speak(_sentences[i]);
      if (token != _token) return;
      if (!finished) {
        state = const SpeechState();
        return;
      }
    }
    if (token == _token) state = const SpeechState();
  }

  /// Para y recuerda la frase en que iba para seguir luego.
  Future<void> pause() async {
    if (state.status != SpeechStatus.speaking) return;
    final id = state.messageId;
    _token++;
    await ref.read(speechServiceProvider).stop();
    state = SpeechState(messageId: id, status: SpeechStatus.paused);
  }

  Future<void> stop() async {
    if (state.status == SpeechStatus.idle) return;
    _token++;
    state = const SpeechState();
    await ref.read(speechServiceProvider).stop();
  }
}

final speechProvider = NotifierProvider<SpeechController, SpeechState>(SpeechController.new);
