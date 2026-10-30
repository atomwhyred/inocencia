import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/max_content_width.dart';
import '../application/flashcard_providers.dart';
import '../application/study_controller.dart';
import 'flip_card.dart';

/// Una ronda de repaso: se voltea la tarjeta y el nino dice si la sabia.
class StudyPage extends ConsumerStatefulWidget {
  const StudyPage({super.key});

  @override
  ConsumerState<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends ConsumerState<StudyPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final deck = await ref.read(flashcardDeckProvider.future);
      if (mounted) ref.read(studyControllerProvider.notifier).start(deck);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(studyControllerProvider);
    final n = ref.read(studyControllerProvider.notifier);
    final theme = Theme.of(context);
    final card = s.current;
    return Scaffold(
      appBar: AppBar(title: const Text('Repasar tarjetas')),
      body: SafeArea(
        child: MaxContentWidth(
          maxWidth: 700,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: s.total == 0
                ? const Center(child: CircularProgressIndicator())
                : s.finished
                ? _Finished(known: s.knownFirstTry, total: s.total)
                : Column(
                    children: [
                      Text(
                        'Tarjeta ${(s.total - s.queue.length + 1).clamp(1, s.total)} de ${s.total}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: FlipCard(card: card!, flipped: s.flipped, onTap: n.flip),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!s.flipped)
                        Text(
                          'Toca la tarjeta para ver la respuesta',
                          style: theme.textTheme.bodyLarge,
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => n.answer(known: false),
                                icon: const Icon(Icons.replay_rounded),
                                label: const Text('A repasar'),
                                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => n.answer(known: true),
                                icon: const Icon(Icons.check_rounded),
                                label: const Text('La sabía'),
                                style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Finished extends StatelessWidget {
  const _Finished({required this.known, required this.total});

  final int known;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = known == total
        ? '¡Te las sabías todas!'
        : known == 0
        ? '¡Sigue repasando, cada vez te saldrán mejor!'
        : '¡Buen trabajo!';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 72, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(message, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Sabías $known de $total tarjetas a la primera.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: FilledButton.styleFrom(minimumSize: const Size(200, 56)),
            child: const Text('Terminar'),
          ),
        ],
      ),
    );
  }
}
