import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_controller.dart';

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
            Text(label, style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600)),
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
