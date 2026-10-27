import 'package:flutter/material.dart';

/// Indicador de que el tutor funciona en el dispositivo, sin internet.
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Funciona sin internet, en este dispositivo',
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
            Text(
              compact ? 'Sin internet' : 'Funciona sin internet',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
