import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../splash_phrases.dart';

/// Pantalla de bienvenida de Flutter, justo despues de la nativa de Android (que
/// no admite texto): Toco y, abajo en el centro, una frase al azar distinta en
/// cada apertura. Se pinta encima de la app durante unos instantes y se retira
/// sola; la app ya esta cargando por debajo.
///
/// Usa una animacion (no un `Timer`): en las pruebas `pumpAndSettle` la espera y no
/// quedan temporizadores pendientes.
class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  /// Cuanto dura la pantalla de bienvenida, desvanecimiento incluido.
  static const duration = Duration(milliseconds: 1800);

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate> {
  late final String _phrase = SplashPhrases.pick(
    ref.read(splashPhrasesProvider),
    ref.read(splashRandomProvider),
  );
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_done)
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: SplashGate.duration,
              onEnd: () => setState(() => _done = true),
              builder: (context, t, _) {
                // Entera la mayor parte del tiempo y se desvanece al final.
                final opacity = t < 0.8 ? 1.0 : ((1 - t) / 0.2).clamp(0.0, 1.0);
                return Opacity(
                  opacity: opacity,
                  child: _SplashLayer(phrase: _phrase),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SplashLayer extends StatelessWidget {
  const _SplashLayer({required this.phrase});

  final String phrase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Image.asset(
                    'assets/splash/toco.png',
                    height: 320,
                    fit: BoxFit.contain,
                    semanticLabel: 'Toco, la mascota de inocencIA',
                    // Si la imagen no se pudiera leer, la frase sigue saliendo.
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 36),
              child: Text(
                '“$phrase”',
                key: const Key('splash_phrase'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
