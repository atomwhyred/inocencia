import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/game_rules.dart';

/// Elegir cómo jugar: en este teléfono o con otros, y carrera o entre todos.
class GameMenuPage extends StatefulWidget {
  const GameMenuPage({super.key});

  @override
  State<GameMenuPage> createState() => _GameMenuPageState();
}

class _GameMenuPageState extends State<GameMenuPage> {
  var _mode = GameMode.race;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Jugar')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Image.asset('assets/splash/toco.png', height: 110),
                const SizedBox(height: 8),
                Text(
                  'Cada uno responde preguntas de su grado: así pueden jugar juntos niños de grados distintos.',
                  textAlign: TextAlign.center,
                  style: text.bodyLarge,
                ),
                const SizedBox(height: 20),
                SegmentedButton<GameMode>(
                  segments: const [
                    ButtonSegment(
                      value: GameMode.race,
                      icon: Icon(Icons.flag_rounded),
                      label: Text('Carrera'),
                    ),
                    ButtonSegment(
                      value: GameMode.team,
                      icon: Icon(Icons.groups_rounded),
                      label: Text('Entre todos'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  _mode == GameMode.race
                      ? 'Carrera de tocororos: cada acierto avanza tu tocororo. Gana quien llegue primero a la meta.'
                      : 'Entre todos: cada acierto ayuda a Toco a volar a su nido. ¡Lleguen juntos antes de que se acaben las rondas!',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                _Choice(
                  icon: Icons.phone_android_rounded,
                  title: 'En este teléfono',
                  subtitle: 'De 2 a 4 niños se pasan el teléfono por turnos.',
                  color: scheme.primaryContainer,
                  onColor: scheme.onPrimaryContainer,
                  onTap: () => context.push('/game/local', extra: _mode),
                ),
                const SizedBox(height: 14),
                _Choice(
                  icon: Icons.wifi_tethering_rounded,
                  title: 'Con otros teléfonos',
                  subtitle: 'Cada niño en su teléfono, conectados por un punto de acceso Wi-Fi. Sin internet.',
                  color: scheme.secondaryContainer,
                  onColor: scheme.onSecondaryContainer,
                  onTap: () => context.push('/game/lan', extra: _mode),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
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
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: ExcludeSemantics(
        child: Card(
          color: color,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(icon, size: 40, color: onColor),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: text.titleLarge?.copyWith(
                            color: onColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: text.bodyMedium?.copyWith(color: onColor),
                        ),
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
