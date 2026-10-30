import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/max_content_width.dart';
import '../application/flashcard_providers.dart';
import '../application/flashcards_controller.dart';
import '../domain/flashcard.dart';

/// "Mis tarjetas": el mazo del nino. Si llega con [generateForGrade] (desde el
/// chat), pide al modelo local tarjetas del tema que se esta viendo.
class FlashcardsPage extends ConsumerStatefulWidget {
  const FlashcardsPage({super.key, this.generateForGrade});

  final int? generateForGrade;

  @override
  ConsumerState<FlashcardsPage> createState() => _FlashcardsPageState();
}

class _FlashcardsPageState extends ConsumerState<FlashcardsPage> {
  @override
  void initState() {
    super.initState();
    final grade = widget.generateForGrade;
    if (grade != null) {
      Future.microtask(
        () => ref.read(flashcardsControllerProvider.notifier).generate(grade: grade),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deck = ref.watch(flashcardDeckProvider).value ?? const <Flashcard>[];
    final gen = ref.watch(flashcardsControllerProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis tarjetas')),
      body: SafeArea(
        child: MaxContentWidth(
          maxWidth: 800,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (gen.generating)
                _Banner(
                  icon: Icons.auto_awesome_rounded,
                  text: gen.added == 0
                      ? 'Toco está preparando tus tarjetas… puede tardar un poquito.'
                      : 'Toco ya preparó ${gen.added} ${gen.added == 1 ? 'tarjeta' : 'tarjetas'}…',
                  busy: true,
                  action: TextButton(
                    onPressed: () => ref.read(flashcardsControllerProvider.notifier).stop(),
                    child: const Text('Parar'),
                  ),
                )
              else if (gen.status == FlashcardsGenStatus.failed)
                _Banner(icon: Icons.info_outline_rounded, text: gen.message ?? '')
              else if (gen.status == FlashcardsGenStatus.done)
                _Banner(
                  icon: Icons.check_circle_rounded,
                  text:
                      '¡Listo! ${gen.added} ${gen.added == 1 ? 'tarjeta nueva' : 'tarjetas nuevas'}.',
                ),
              if (deck.isEmpty && !gen.generating)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.style_rounded, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Aún no tienes tarjetas',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Abre Mi tutor, pregúntale algo de tus libros y pulsa el botón de tarjetas '
                        'debajo de su respuesta para crear las tuyas.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else ...[
                if (deck.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: FilledButton.icon(
                      onPressed: () => context.push('/flashcards/study'),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text('Estudiar (${deck.length})'),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                    ),
                  ),
                for (final card in deck) _DeckTile(card: card),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, this.busy = false, this.action});

  final IconData icon;
  final String text;
  final bool busy;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer)),
                ),
                ?action,
              ],
            ),
            if (busy) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
          ],
        ),
      ),
    );
  }
}

class _DeckTile extends ConsumerWidget {
  const _DeckTile({required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(card.front, style: theme.textTheme.titleMedium),
        subtitle: card.timesReviewed == 0
            ? const Text('Sin repasar')
            : Text('La sabías ${card.timesKnown} de ${card.timesReviewed} veces'),
        trailing: IconButton(
          tooltip: 'Borrar tarjeta',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => ref.read(flashcardRepositoryProvider).delete(card.id),
        ),
      ),
    );
  }
}
