import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/responsive/max_content_width.dart';
import '../../../core/responsive/window_size_class.dart';
import '../../../core/utils/school_grade_calculator.dart';
import '../../auth/application/session.dart';
import '../../external_data/presentation/files_section.dart';
import '../../notifications/presentation/reminders_section.dart';
import '../../profiles/presentation/avatar_view.dart';
import '../../profiles/presentation/profile_form.dart';

/// Panel de administracion (protegido por el PIN del padre/madre).
class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  int _section = 0;

  static const _destinations = [
    (icon: Icons.child_care_rounded, label: 'Perfiles'),
    (icon: Icons.folder_open_rounded, label: 'Archivos'),
    (icon: Icons.notifications_active_outlined, label: 'Avisos'),
  ];

  void _exit() {
    ref.read(sessionProvider.notifier).lockParent();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final size = WindowSizeClass.of(context);
    final content = switch (_section) {
      0 => const _ProfilesSection(),
      1 => const MaxContentWidth(maxWidth: 720, child: FilesSection()),
      _ => const MaxContentWidth(maxWidth: 720, child: RemindersSection()),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zona de padres'),
        actions: [
          TextButton.icon(
            onPressed: _exit,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Salir'),
          ),
        ],
      ),
      bottomNavigationBar: size.isCompact
          ? NavigationBar(
              selectedIndex: _section,
              onDestinationSelected: (i) => setState(() => _section = i),
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            )
          : null,
      body: SafeArea(
        child: size.isCompact
            ? content
            : Row(
                children: [
                  NavigationRail(
                    selectedIndex: _section,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (i) => setState(() => _section = i),
                    destinations: [
                      for (final d in _destinations)
                        NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              ),
      ),
    );
  }
}

class _ProfilesSection extends ConsumerStatefulWidget {
  const _ProfilesSection();

  @override
  ConsumerState<_ProfilesSection> createState() => _ProfilesSectionState();
}

class _ProfilesSectionState extends ConsumerState<_ProfilesSection> {
  int? _selectedId;
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final twoPane = WindowSizeClass.of(context).isExpanded;
    final list = _ProfileList(
      selectedId: twoPane ? _selectedId : null,
      onSelect: (id) {
        if (twoPane) {
          setState(() {
            _selectedId = id;
            _creating = false;
          });
        } else {
          context.push('/admin/profile/$id');
        }
      },
      onCreate: () {
        if (twoPane) {
          setState(() {
            _selectedId = null;
            _creating = true;
          });
        } else {
          context.push('/admin/profile/new');
        }
      },
    );

    if (!twoPane) return MaxContentWidth(maxWidth: 720, child: list);

    final Widget detail;
    if (_creating || _selectedId != null) {
      detail = MaxContentWidth(
        maxWidth: 560,
        child: ProfileForm(
          key: ValueKey(_creating ? 'new' : 'edit-$_selectedId'),
          childId: _creating ? null : _selectedId,
          onDone: () => setState(() {
            _selectedId = null;
            _creating = false;
          }),
        ),
      );
    } else {
      detail = const Center(child: Text('Elige un perfil o crea uno nuevo'));
    }
    return Row(
      children: [
        SizedBox(width: 340, child: list),
        const VerticalDivider(width: 1),
        Expanded(child: detail),
      ],
    );
  }
}

class _ProfileList extends ConsumerWidget {
  const _ProfileList({
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
  });

  final int? selectedId;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(childProfilesProvider);
    final now = ref.read(clockProvider)();
    return Column(
      children: [
        Expanded(
          child: profiles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (list) => list.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aún no hay perfiles.\nCrea el primero para tu hijo o hija.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return ListTile(
                        selected: c.id == selectedId,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        leading: AvatarView(avatar: c.avatar, radius: 24),
                        title: Text(c.name),
                        subtitle: Text(SchoolGradeCalculator.label(c.gradeAt(now))),
                        trailing: c.hasPin
                            ? const Icon(Icons.lock_outline_rounded, size: 18)
                            : null,
                        onTap: () => onSelect(c.id),
                      );
                    },
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo perfil'),
            ),
          ),
        ),
      ],
    );
  }
}
