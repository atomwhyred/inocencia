import 'package:flutter/material.dart';

/// Un destino de la [FloatingNavBar].
class FloatingNavItem {
  const FloatingNavItem({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.primary = false,
    this.color,
    this.onColor,
  });

  final IconData icon;
  final String label;

  /// Lo que lee el lector de pantalla ("Mi tutor. Pregúntale lo que no entiendas").
  final String semanticLabel;
  final VoidCallback onTap;

  /// La accion principal (el tutor): pastilla rellena y algo mas grande.
  final bool primary;

  /// Color de la pastilla del icono y del icono (por defecto, los del tema).
  final Color? color;
  final Color? onColor;
}

/// Barra inferior flotante y centrada del inicio del nino: una "isla" redondeada
/// con sombra suave que deja ver el fondo alrededor. Se coloca en
/// `Scaffold.bottomNavigationBar` con `extendBody: true`.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({super.key, required this.items, this.trailing});

  final List<FloatingNavItem> items;

  /// Elemento fijo a la derecha del todo, separado por una linea fina (el perfil
  /// del nino).
  final Widget? trailing;

  static const maxWidth = 460.0;

  /// Alto que ocupa la barra con sus margenes (sin la zona segura del sistema):
  /// el contenido de la pantalla debe dejar al menos este hueco abajo.
  static const reservedHeight = 112.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.45 : 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  for (final item in items) Expanded(child: _NavButton(item: item)),
                  if (trailing != null) ...[
                    Container(
                      width: 1,
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: scheme.outlineVariant,
                    ),
                    Expanded(child: trailing!),
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

class _NavButton extends StatefulWidget {
  const _NavButton({required this.item});

  final FloatingNavItem item;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _pressed = false;

  void _press(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final scheme = Theme.of(context).colorScheme;
    final pillColor =
        item.color ??
        (item.primary ? scheme.primary : scheme.secondaryContainer);
    final iconColor =
        item.onColor ??
        (item.primary ? scheme.onPrimary : scheme.onSecondaryContainer);
    final pill = item.primary ? 52.0 : 44.0;
    final animate = !MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      label: item.semanticLabel,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _press(true),
          onTapUp: (_) => _press(false),
          onTapCancel: () => _press(false),
          onTap: item.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1,
            duration: animate
                ? const Duration(milliseconds: 120)
                : Duration.zero,
            curve: Curves.easeOut,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mismo alto para todos los iconos: las etiquetas quedan alineadas
                  // aunque la pastilla del tutor sea mayor.
                  SizedBox(
                    height: 52,
                    child: Center(
                      child: Container(
                        width: pill + 12,
                        height: pill,
                        decoration: BoxDecoration(
                          color: pillColor,
                          borderRadius: BorderRadius.circular(pill / 2),
                          boxShadow: item.primary
                              ? [
                                  BoxShadow(
                                    color: scheme.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          item.icon,
                          color: iconColor,
                          size: item.primary ? 30 : 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: item.primary ? scheme.primary : scheme.onSurface,
                      fontWeight: item.primary
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
