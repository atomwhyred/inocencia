import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/responsive/max_content_width.dart';
import '../../../core/utils/school_grade_calculator.dart';
import '../../../core/widgets/offline_badge.dart';
import '../../auth/application/session.dart';
import '../../external_data/domain/linked_file_status.dart';
import '../../profiles/presentation/avatar_view.dart';

/// Marcador de posicion del chat. El motor de IA (Modulo 2) y la interfaz de
/// chat (Modulo 3) llegan en las fases siguientes; aqui ya se ve el perfil
/// activo, su grado y si los archivos externos estan listos.
class TutorPage extends ConsumerWidget {
  const TutorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childId = ref.watch(sessionProvider).activeChildId;
    final child = ref
        .watch(childProfilesProvider)
        .value
        ?.where((c) => c.id == childId)
        .firstOrNull;
    final files = ref.watch(linkedFilesStatusProvider).value;
    final now = ref.read(clockProvider)();

    return Scaffold(
      appBar: AppBar(
        title: const OfflineBadge(compact: true),
        leading: IconButton(
          tooltip: 'Cambiar de perfil',
          icon: const Icon(Icons.swap_horiz_rounded),
          onPressed: () {
            ref.read(sessionProvider.notifier).clearChild();
            context.go('/');
          },
        ),
      ),
      body: SafeArea(
        child: MaxContentWidth(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: child == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AvatarView(avatar: child.avatar, radius: 56),
                        const SizedBox(height: 16),
                        Text(
                          '¡Hola, ${child.name}!',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(SchoolGradeCalculator.label(child.gradeAt(now))),
                        const SizedBox(height: 24),
                        Text(
                          files != null && files.allReady
                              ? 'Tu tutor está casi listo. El chat llegará pronto.'
                              : 'Pide a un adulto que vincule el modelo y los libros '
                                  'en la zona de padres.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (files != null) ...[
                          const SizedBox(height: 12),
                          _Dot(ok: files.model.state == LinkState.ready, label: 'Modelo de IA'),
                          _Dot(ok: files.knowledge.state == LinkState.ready, label: 'Libros de texto'),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
          size: 18,
          color: ok ? Colors.green : Theme.of(context).colorScheme.error,
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
