import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/speech_controller.dart';
import '../domain/speech_service.dart';

/// Altavoz de una respuesta del tutor: escuchar, pausar y parar.
class SpeakButton extends ConsumerWidget {
  const SpeakButton({super.key, required this.messageId, required this.text});

  final int messageId;
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(speechEnabledProvider)) return const SizedBox.shrink();
    final speech = ref.watch(speechProvider);
    final controller = ref.read(speechProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final mine = speech.messageId == messageId;
    final status = mine ? speech.status : SpeechStatus.idle;

    if (status == SpeechStatus.unavailable) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'Este teléfono no tiene la voz en español. Pide a un adulto que la instale: Ajustes › '
          'Sistema › Idiomas › Salida de texto a voz › Motor de Google › Instalar datos de voz › '
          'Español.',
          style: TextStyle(fontSize: 13, color: scheme.error),
        ),
      );
    }

    final speaking = status == SpeechStatus.speaking;
    final paused = status == SpeechStatus.paused;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            tooltip: speaking ? 'Pausar' : (paused ? 'Seguir escuchando' : 'Escuchar la respuesta'),
            icon: Icon(speaking ? Icons.pause_rounded : Icons.volume_up_rounded),
            onPressed: () => speaking ? controller.pause() : controller.play(messageId, text),
          ),
          if (speaking || paused)
            IconButton(
              tooltip: 'Parar',
              icon: const Icon(Icons.stop_rounded),
              onPressed: controller.stop,
            ),
        ],
      ),
    );
  }
}
