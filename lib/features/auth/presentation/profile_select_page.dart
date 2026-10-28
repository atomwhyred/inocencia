import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/di/providers.dart';
import '../../../core/responsive/max_content_width.dart';
import '../../../core/widgets/offline_badge.dart';
import '../../profiles/domain/child_profile.dart';
import '../../profiles/presentation/avatar_view.dart';
import '../application/session.dart';

/// Pantalla de inicio: el nino elige su perfil; el padre entra por el candado.
class ProfileSelectPage extends ConsumerWidget {
  const ProfileSelectPage({super.key});

  void _open(BuildContext context, WidgetRef ref, ChildProfile child) {
    if (child.hasPin) {
      context.push('/child-pin/${child.id}');
    } else {
      ref.read(sessionProvider.notifier).selectChild(child.id);
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(childProfilesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(appName),
        actions: [
          IconButton(
            tooltip: 'Zona de padres',
            icon: const Icon(Icons.lock_outline_rounded),
            onPressed: () {
              final session = ref.read(sessionProvider);
              context.push(session.parentUnlocked ? '/admin' : '/parent-pin');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: MaxContentWidth(
          maxWidth: 900,
          child: profiles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('No se pudieron cargar los perfiles: $e')),
            data: (list) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  list.isEmpty ? '¡Hola!' : '¿Quién va a aprender hoy?',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Center(child: OfflineBadge()),
                const SizedBox(height: 28),
                if (list.isEmpty)
                  _EmptyState(onOpenParents: () => context.push('/parent-pin'))
                else
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      for (final c in list)
                        _ProfileCard(child: c, onTap: () => _open(context, ref, c)),
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.child, required this.onTap});

  final ChildProfile child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: Column(
              children: [
                AvatarView(avatar: child.avatar, radius: 44),
                const SizedBox(height: 12),
                Text(
                  child.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (child.hasPin)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.lock_outline_rounded, size: 16),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onOpenParents});

  final VoidCallback onOpenParents;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Todavía no hay perfiles de niños.\n'
          'Pide a un adulto que cree uno desde la zona de padres.',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onOpenParents,
          icon: const Icon(Icons.lock_outline_rounded),
          label: const Text('Zona de padres'),
        ),
      ],
    );
  }
}
