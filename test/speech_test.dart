import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/di/providers.dart';
import 'package:inocencia/features/pomodoro/application/pomodoro.dart';
import 'package:inocencia/features/speech/application/speech_controller.dart';
import 'package:inocencia/features/speech/domain/speech_service.dart';
import 'package:inocencia/features/speech/domain/speech_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Voz falsa: cada frase queda "sonando" hasta que la prueba la termina.
class FakeSpeechService implements SpeechService {
  bool hasVoice = true;
  final spoken = <String>[];
  int stops = 0;
  Completer<bool>? current;

  @override
  Future<bool> prepare() async => hasVoice;

  @override
  Future<bool> speak(String sentence) {
    spoken.add(sentence);
    current = Completer<bool>();
    return current!.future;
  }

  /// La frase actual acaba sola.
  void finishSentence() => current!.complete(true);

  @override
  Future<void> stop() async {
    stops++;
    final c = current;
    if (c != null && !c.isCompleted) c.complete(false);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('SpeechText', () {
    test('quita formato, viñetas y emojis', () {
      expect(
        SpeechText.clean('**Los adjetivos** dicen cómo es algo 😀\n- uno\n- dos'),
        'Los adjetivos dicen cómo es algo\nuno\ndos',
      );
    });

    test('parte en frases por puntuación y saltos de línea', () {
      expect(SpeechText.sentences('Hola, niño. ¿Cómo estás? ¡Muy bien!\nSigamos'), [
        'Hola, niño.',
        '¿Cómo estás?',
        '¡Muy bien!',
        'Sigamos',
      ]);
    });

    test('ignora lo que no se puede leer y parte las frases larguísimas', () {
      expect(SpeechText.sentences('... --- ***'), isEmpty);
      final long = List.filled(80, 'palabra').join(' ');
      final parts = SpeechText.sentences(long);
      expect(parts.length, greaterThan(1));
      expect(parts.every((p) => p.length <= SpeechText.maxSentence), isTrue);
      expect(parts.join(' '), long);
    });
  });

  group('SpeechController', () {
    late FakeSpeechService voice;
    late ProviderContainer c;

    SpeechController ctl() => c.read(speechProvider.notifier);
    SpeechState st() => c.read(speechProvider);
    Future<void> tick() => Future<void>.delayed(Duration.zero);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      voice = FakeSpeechService();
      c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          speechServiceProvider.overrideWithValue(voice),
        ],
      );
      addTearDown(c.dispose);
      c.listen(speechProvider, (_, _) {});
    });

    test('viene activado y el padre lo puede apagar', () async {
      expect(c.read(speechEnabledProvider), isTrue);
      await c.read(speechEnabledProvider.notifier).set(false);
      expect(c.read(speechEnabledProvider), isFalse);
    });

    test('lee las frases una tras otra y al acabar queda en reposo', () async {
      unawaited(ctl().play(3, 'Hola. ¿Qué tal?'));
      await tick();
      expect(st().status, SpeechStatus.speaking);
      expect(st().messageId, 3);
      expect(voice.spoken, ['Hola.']);
      voice.finishSentence();
      await tick();
      expect(voice.spoken, ['Hola.', '¿Qué tal?']);
      voice.finishSentence();
      await tick();
      expect(st().status, SpeechStatus.idle);
    });

    test('pausar para y seguir continúa desde la misma frase', () async {
      unawaited(ctl().play(1, 'Uno. Dos. Tres.'));
      await tick();
      voice.finishSentence();
      await tick();
      expect(voice.spoken, ['Uno.', 'Dos.']);

      await ctl().pause();
      expect(st().status, SpeechStatus.paused);
      expect(st().messageId, 1);
      await tick();
      expect(voice.spoken, ['Uno.', 'Dos.'], reason: 'en pausa no se lee nada más');

      unawaited(ctl().play(1, 'Uno. Dos. Tres.'));
      await tick();
      expect(st().status, SpeechStatus.speaking);
      expect(voice.spoken, ['Uno.', 'Dos.', 'Dos.']);
      voice.finishSentence();
      await tick();
      expect(voice.spoken.last, 'Tres.');
    });

    test('parar vuelve al reposo y empezar otra vez lee desde el principio', () async {
      unawaited(ctl().play(1, 'Uno. Dos.'));
      await tick();
      await ctl().stop();
      expect(st().status, SpeechStatus.idle);
      unawaited(ctl().play(1, 'Uno. Dos.'));
      await tick();
      expect(voice.spoken, ['Uno.', 'Uno.']);
    });

    test('solo suena un mensaje a la vez', () async {
      unawaited(ctl().play(1, 'Primero.'));
      await tick();
      unawaited(ctl().play(2, 'Segundo.'));
      await tick();
      expect(st().messageId, 2);
      expect(st().status, SpeechStatus.speaking);
      expect(voice.spoken, ['Primero.', 'Segundo.']);
      expect(st().isActive(1), isFalse);
      expect(st().isActive(2), isTrue);
    });

    test('sin voz en español avisa en vez de callar', () async {
      voice.hasVoice = false;
      await ctl().play(1, 'Hola.');
      expect(st().status, SpeechStatus.unavailable);
      expect(voice.spoken, isEmpty);
    });

    test('en el descanso del Pomodoro se calla', () async {
      final frozen = NotifierProvider<_Flag, bool>(_Flag.new);
      final c2 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          speechServiceProvider.overrideWithValue(voice),
          chatFrozenProvider.overrideWith((ref) => ref.watch(frozen)),
        ],
      );
      addTearDown(c2.dispose);
      c2.listen(speechProvider, (_, _) {});
      unawaited(c2.read(speechProvider.notifier).play(1, 'Hola. Adiós.'));
      await tick();
      expect(c2.read(speechProvider).status, SpeechStatus.speaking);

      c2.read(frozen.notifier).state = true;
      await tick();
      expect(c2.read(speechProvider).status, SpeechStatus.idle);
      expect(voice.stops, greaterThan(0));
    });
  });
}

class _Flag extends Notifier<bool> {
  @override
  bool build() => false;

  set state(bool v) => super.state = v;
}
