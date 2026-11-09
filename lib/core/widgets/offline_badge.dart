import 'package:flutter/material.dart';

/// Indicador de que el tutor funciona en el dispositivo, sin internet.
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key, this.compact = false, this.iconOnly = false});

  final bool compact;

  /// Solo el icono, sin texto (para la esquina del chat).
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const label = 'Funciona sin internet, en este dispositivo';
    if (iconOnly) {
      return Semantics(
        label: label,
        child: Tooltip(
          message: 'Sin internet',
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: scheme.tertiaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.wifi_off_rounded, size: 18, color: scheme.onTertiaryContainer),
          ),
        ),
      );
    }
    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 16, color: scheme.onTertiaryContainer),
            const SizedBox(width: 6),
            // En barras estrechas (o con letra grande) se recorta en vez de desbordarse.
            Flexible(
              child: Text(
                compact ? 'Sin internet' : 'Funciona sin internet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
