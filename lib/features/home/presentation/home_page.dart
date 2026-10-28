import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/max_content_width.dart';
import '../../../core/responsive/window_size_class.dart';
import '../../../core/utils/school_grade_calculator.dart';
import '../../../core/widgets/offline_badge.dart';
import '../../auth/application/active_child.dart';
import '../../auth/application/session.dart';
import '../../profiles/presentation/avatar_view.dart';

/// Inicio del nino: de aqui va a hablar con su tutor o a leer sus libros.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(activeChildProvider);
    final grade = ref.watch(activeGradeProvider);
    final wide = !WindowSizeClass.of(context).isCompact;

    final cards = [
      _HomeCard(
        icon: Icons.chat_bubble_rounded,
        title: 'Mi tutor',
        subtitle: 'Pregúntale lo que no entiendas',
        color: Theme.of(context).colorScheme.primaryContainer,
        onColor: Theme.of(context).colorScheme.onPrimaryContainer,
        onTap: () => context.push('/tutor'),
      ),
      _HomeCard(
        icon: Icons.menu_book_rounded,
        title: 'Mis libros',
        subtitle: 'Lee tus libros y cuadernos',
        color: Theme.of(context).colorScheme.tertiaryContainer,
        onColor: Theme.of(context).colorScheme.onTertiaryContainer,
        onTap: () => context.push('/books'),
      ),
    ];

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
        child: child == null || grade == null
            ? const Center(child: CircularProgressIndicator())
            : MaxContentWidth(
                maxWidth: 900,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Row(
                      children: [
                        AvatarView(avatar: child.avatar, radius: 30),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('¡Hola, ${child.name}!',
                                  style: Theme.of(context).textTheme.headlineSmall),
                              Text(SchoolGradeCalculator.label(grade),
                                  style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text('¿Qué quieres hacer hoy?', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    if (wide)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: 20),
                            Expanded(child: cards[1]),
                          ],
                        ),
                      )
                    else ...[
                      cards[0],
                      const SizedBox(height: 16),
                      cards[1],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color onColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: ExcludeSemantics(
        child: Card(
          color: color,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(icon, size: 48, color: onColor),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: onColor, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: onColor)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: onColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
