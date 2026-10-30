import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../power/application/power_mode.dart';
import '../domain/flashcard.dart';

/// Tarjeta de doble cara: la pregunta al frente y, al pulsarla, gira y muestra la
/// respuesta. En el modo bateria el giro es instantaneo.
class FlipCard extends ConsumerWidget {
  const FlipCard({super.key, required this.card, required this.flipped, required this.onTap});

  final Flashcard card;
  final bool flipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animate = !ref.watch(batterySaverProvider);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: flipped
          ? 'Respuesta: ${card.back}. Toca para ver la pregunta'
          : 'Pregunta: ${card.front}. Toca para ver la respuesta',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: flipped ? 1 : 0),
            duration: animate ? const Duration(milliseconds: 350) : Duration.zero,
            curve: Curves.easeInOut,
            builder: (context, t, _) {
              final showBack = t >= 0.5;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(pi * t),
                child: showBack
                    // La cara de atras se pinta ya girada media vuelta para que no salga al reves.
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(pi),
                        child: _Face(
                          label: 'Respuesta',
                          text: card.back,
                          footer: card.source,
                          color: scheme.tertiaryContainer,
                          onColor: scheme.onTertiaryContainer,
                        ),
                      )
                    : _Face(
                        label: 'Pregunta',
                        text: card.front,
                        color: scheme.primaryContainer,
                        onColor: scheme.onPrimaryContainer,
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.label,
    required this.text,
    required this.color,
    required this.onColor,
    this.footer,
  });

  final String label;
  final String text;
  final String? footer;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(color: onColor.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 16),
            Text(
              footer!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: onColor.withValues(alpha: 0.7)),
            ),
          ],
        ],
      ),
    );
  }
}
