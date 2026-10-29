import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/achievement_service.dart';

/// Aviso de "¡Nueva medalla!" con la primera medalla pendiente. Aparece, se queda
/// unos segundos y se va solo (animacion, sin `Timer`).
///
/// Solo se pinta en la pantalla que el nino tiene delante: asi una pantalla
/// tapada por otra no se "come" el aviso.
class MedalToast extends ConsumerWidget {
  const MedalToast({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medals = ref.watch(newMedalsProvider);
    if (medals.isEmpty || !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return const SizedBox.shrink();
    }
    final medal = medals.first;
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      key: ValueKey('${medal.code}-${medals.length}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 5),
      onEnd: () => ref.read(newMedalsProvider.notifier).dismiss(),
      builder: (context, t, child) {
        final opacity =
            (t < 0.08
                    ? t / 0.08
                    : t > 0.85
                    ? (1 - t) / 0.15
                    : 1.0)
                .clamp(0.0, 1.0);
        return Opacity(opacity: opacity, child: child);
      },
      child: Semantics(
        liveRegion: true,
        label: '¡Nueva medalla! ${medal.title}',
        child: Container(
          margin: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(medal.icon, color: scheme.onPrimaryContainer),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '¡Nueva medalla: ${medal.title}!',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
