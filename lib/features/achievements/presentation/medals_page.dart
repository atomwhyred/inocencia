import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/max_content_width.dart';
import '../application/achievement_service.dart';
import '../domain/achievement.dart';

/// "Mis medallas": las que el nino ya ganó y, en gris, las que le faltan.
class MedalsPage extends ConsumerWidget {
  const MedalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(childProgressProvider).value ?? const ChildProgress();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis medallas')),
      body: SafeArea(
        child: MaxContentWidth(
          maxWidth: 900,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_rounded, size: 40, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Semantics(
                    label: '${progress.stars} estrellas',
                    child: Text(
                      '${progress.stars}',
                      style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Ganas una estrella por cada pregunta de quiz que aciertas.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final a in Medals.all)
                    _Medal(achievement: a, earned: progress.earned.containsKey(a.code)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.achievement, required this.earned});

  final Achievement achievement;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '${achievement.title}. ${earned ? 'Ganada' : 'Por ganar: ${achievement.hint}'}',
      excludeSemantics: true,
      child: SizedBox(
        width: 150,
        child: Card(
          color: earned ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Icon(
                  earned ? achievement.icon : Icons.lock_outline_rounded,
                  size: 48,
                  color: earned ? scheme.onPrimaryContainer : scheme.outline,
                ),
                const SizedBox(height: 8),
                Text(
                  achievement.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: earned ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: earned ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
