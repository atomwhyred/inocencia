import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../mascot/application/mascot_settings.dart';
import '../../pomodoro/application/pomodoro.dart';
import '../../speech/application/speech_controller.dart';

/// Seccion "Apariencia" del panel: claro, oscuro o seguir el dispositivo.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  static const _options = [
    (
      mode: ThemeMode.system,
      title: 'Seguir el dispositivo',
      subtitle: 'Cambia solo entre claro y oscuro como el resto del teléfono.',
      icon: Icons.brightness_auto_rounded,
    ),
    (
      mode: ThemeMode.light,
      title: 'Claro',
      subtitle: 'Fondo blanco con azul y rojo.',
      icon: Icons.light_mode_rounded,
    ),
    (
      mode: ThemeMode.dark,
      title: 'Oscuro',
      subtitle: 'Fondo azul noche, más cómodo con poca luz.',
      icon: Icons.dark_mode_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Apariencia', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('Elige los colores de inocencIA. Se aplica a toda la app.'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Preview(
                label: 'Claro',
                scheme: AppTheme.lightScheme,
                selected: current == ThemeMode.light,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Preview(
                label: 'Oscuro',
                scheme: AppTheme.darkScheme,
                selected: current == ThemeMode.dark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: RadioGroup<ThemeMode>(
            groupValue: current,
            onChanged: (m) {
              if (m != null) ref.read(themeModeProvider.notifier).set(m);
            },
            child: Column(
              children: [
                for (final o in _options)
                  RadioListTile<ThemeMode>(
                    value: o.mode,
                    secondary: Icon(o.icon),
                    title: Text(o.title),
                    subtitle: Text(o.subtitle),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.flutter_dash_rounded),
            title: const Text('Mostrar la mascota'),
            subtitle: const Text(
              'Toco, el tocororo, acompaña al niño en el chat y reacciona mientras el tutor '
              'piensa. Apágalo si el teléfono va lento o se calienta.',
            ),
            value: ref.watch(mascotEnabledProvider),
            onChanged: (v) => ref.read(mascotEnabledProvider.notifier).set(v),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.volume_up_rounded),
            title: const Text('Leer las respuestas en voz alta'),
            subtitle: const Text(
              'Cada respuesta del tutor trae un altavoz para escucharla. Usa la voz en español '
              'del teléfono y funciona sin internet.',
            ),
            value: ref.watch(speechEnabledProvider),
            onChanged: (v) => ref.read(speechEnabledProvider.notifier).set(v),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.timer_outlined),
            title: const Text('Pomodoro infantil'),
            subtitle: const Text(
              'Después de 15 minutos de estudio (1.º a 3.º) o 20 (4.º a 6.º) el chat se pausa '
              '5 minutos para descansar y estirarse. El niño vuelve tocando a Toco.',
            ),
            value: ref.watch(pomodoroEnabledProvider),
            onChanged: (v) => ref.read(pomodoroEnabledProvider.notifier).set(v),
          ),
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.label, required this.scheme, required this.selected});

  final String label;
  final ColorScheme scheme;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Vista previa del modo $label${selected ? ', seleccionado' : ''}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : scheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _Dot(AppColors.blue),
                const SizedBox(width: 8),
                const _Dot(AppColors.red),
                const SizedBox(width: 8),
                _Dot(scheme.surfaceContainerHigh),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text('Botón', style: TextStyle(color: scheme.onPrimary, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.black12),
    ),
  );
}
