import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/utils/school_grade_calculator.dart';
import '../../auth/application/session.dart';
import '../../profiles/presentation/avatar_view.dart';
import '../domain/game_rules.dart';

/// Elegir quién juega en este teléfono (de 2 a 4 niños, cada uno con su grado).
class LocalSetupPage extends ConsumerStatefulWidget {
  const LocalSetupPage({super.key, required this.mode});

  final GameMode mode;

  @override
  ConsumerState<LocalSetupPage> createState() => _LocalSetupPageState();
}

class _LocalSetupPageState extends ConsumerState<LocalSetupPage> {
  Set<int>? _picked;

  @override
  Widget build(BuildContext context) {
    final kids = ref.watch(childProfilesProvider).value ?? const [];
    final now = ref.read(clockProvider)();
    _picked ??= {?ref.read(sessionProvider).activeChildId};
    final picked = _picked!;
    final canStart =
        picked.length >= GameRules.minPlayers &&
        picked.length <= GameRules.maxLocalPlayers;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == GameMode.race
              ? 'Carrera: ¿quién juega?'
              : 'Entre todos: ¿quién juega?',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    kids.length < GameRules.minPlayers
                        ? 'Hacen falta al menos 2 perfiles de niños en este teléfono. Un adulto puede crearlos en la zona de padres.'
                        : 'Elige de 2 a 4 jugadores. Cada uno responderá preguntas de su grado.',
                    textAlign: TextAlign.center,
                    style: text.bodyLarge,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final k in kids)
                        CheckboxListTile(
                          value: picked.contains(k.id),
                          onChanged: (v) => setState(() {
                            if (v == true &&
                                picked.length < GameRules.maxLocalPlayers) {
                              picked.add(k.id);
                            } else {
                              picked.remove(k.id);
                            }
                          }),
                          secondary: AvatarView(avatar: k.avatar, radius: 24),
                          title: Text(k.name, style: text.titleMedium),
                          subtitle: Text(
                            SchoolGradeCalculator.label(k.gradeAt(now)),
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: canStart
                          ? () => context.pushReplacement(
                              '/game/local/play',
                              extra: (
                                widget.mode,
                                [
                                  for (final k in kids)
                                    if (picked.contains(k.id)) k,
                                ],
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        canStart
                            ? '¡A jugar! (${picked.length})'
                            : 'Elige al menos 2',
                      ),
                    ),
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
