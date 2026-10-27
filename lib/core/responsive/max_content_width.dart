import 'package:flutter/material.dart';

/// Centra el contenido con un ancho maximo de lectura (evita estirar en tablets).
class MaxContentWidth extends StatelessWidget {
  const MaxContentWidth({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
