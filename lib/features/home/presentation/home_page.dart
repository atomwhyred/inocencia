import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/max_content_width.dart';
import '../../../core/widgets/offline_badge.dart';
import '../../achievements/application/achievement_service.dart';
import '../../auth/application/active_child.dart';
import '../../flashcards/application/flashcard_providers.dart';
import '../../mascot/domain/mascot_mood.dart';
import '../../mascot/presentation/mascot_view.dart';
import '../../auth/application/session.dart';
import '../../power/application/power_mode.dart';
import '../../power/presentation/power_toggle.dart';
import '../../profiles/presentation/avatar_view.dart';
import 'floating_nav_bar.dart';

/// Inicio del nino: Toco le da la bienvenida, un resumen de su progreso y una barra
/// flotante abajo para ir al tutor, los libros, las medallas o las tarjetas, con su
/// perfil (avatar y nombre) a la derecha del todo.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(activeChildProvider);
    final grade = ref.watch(activeGradeProvider);
    final progress = ref.watch(childProgressProvider).value;
    final medalsSubtitle = progress == null
        ? 'Tus estrellas y medallas'
        : '${progress.earned.length} ${progress.earned.length == 1 ? 'medalla' : 'medallas'} · '
              '${progress.stars} ${progress.stars == 1 ? 'estrella' : 'estrellas'}';

    final deckSize = ref.watch(flashcardDeckProvider).value?.length;
    final flashcardsSubtitle = deckSize == null || deckSize == 0
        ? 'Repasa lo que aprendes'
        : '$deckSize ${deckSize == 1 ? 'tarjeta' : 'tarjetas'}';

    final scheme = Theme.of(context).colorScheme;
    // En el tema claro los "container" son pastel y se pierden sobre la barra:
    // ahi se usan los colores solidos de la bandera.
    final light = Theme.of(context).brightness == Brightness.light;
    final navItems = [
      FloatingNavItem(
        icon: Icons.chat_bubble_rounded,
        label: 'Tutor',
        semanticLabel: 'Mi tutor. Pregúntale lo que no entiendas',
        primary: true,
        onTap: () => context.push('/tutor'),
      ),
      FloatingNavItem(
        icon: Icons.menu_book_rounded,
        label: 'Libros',
        semanticLabel: 'Mis libros. Lee tus libros y cuadernos',
        // Blanco en tema oscuro y oscuro en el claro: contrasta con la barra.
        color: scheme.inverseSurface,
        onColor: scheme.onInverseSurface,
        onTap: () => context.push('/books'),
      ),
      // Las medallas se abren desde la tarjeta roja del resumen.
      FloatingNavItem(
        icon: Icons.sports_esports_rounded,
        label: 'Jugar',
        semanticLabel: 'Jugar con otros niños',
        color: light ? scheme.secondary : scheme.secondaryContainer,
        onColor: light ? scheme.onSecondary : scheme.onSecondaryContainer,
        onTap: () => context.push('/game'),
      ),
      FloatingNavItem(
        icon: Icons.style_rounded,
        label: 'Tarjetas',
        semanticLabel: 'Mis tarjetas. $flashcardsSubtitle',
        color: light ? scheme.tertiary : scheme.primaryContainer,
        onColor: light ? scheme.onTertiary : scheme.onPrimaryContainer,
        onTap: () => context.push('/flashcards'),
      ),
    ];

    // Hueco bajo el contenido para que la barra flotante no lo tape.
    final bottomGap = FloatingNavBar.reservedHeight + MediaQuery.paddingOf(context).bottom + 8;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const OfflineBadge(compact: true),
        actions: const [PowerToggle(), SizedBox(width: 4)],
        leading: IconButton(
          tooltip: 'Cambiar de perfil',
          icon: const Icon(Icons.swap_horiz_rounded),
          onPressed: () {
            ref.read(sessionProvider.notifier).clearChild();
            context.go('/');
          },
        ),
      ),
      bottomNavigationBar: child == null || grade == null
          ? null
          : FloatingNavBar(
              items: navItems,
              trailing: _ProfileButton(
                avatar: child.avatar,
                name: child.name,
                onTap: () {
                  ref.read(sessionProvider.notifier).clearChild();
                  context.go('/');
                },
              ),
            ),
      body: SafeArea(
        bottom: false,
        child: child == null || grade == null
            ? const Center(child: CircularProgressIndicator())
            : MaxContentWidth(
                maxWidth: 600,
                // Sin desplazarse: el resumen abajo con su alto natural y Toco, en el
                // centro, con el alto que sobre (crece y encoge con la pantalla y con el
                // aviso de bateria). Solo en pantallas muy bajas (o con letra muy grande)
                // vuelve a desplazarse, con un Toco pequeno.
                child: BatteryWatcher(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final summary = IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _SummaryTile(
                                icon: Icons.emoji_events_rounded,
                                value: progress == null ? '–' : '${progress.earned.length}',
                                caption: progress == null
                                    ? 'Medallas'
                                    : '${progress.earned.length == 1 ? 'medalla' : 'medallas'} · '
                                          '${progress.stars} ${progress.stars == 1 ? 'estrella' : 'estrellas'}',
                                color: scheme.secondaryContainer,
                                onColor: scheme.onSecondaryContainer,
                                semanticLabel: 'Mis medallas. $medalsSubtitle',
                                onTap: () => context.push('/medals'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _SummaryTile(
                                icon: Icons.style_rounded,
                                value: deckSize == null ? '–' : '$deckSize',
                                caption: deckSize == 0 || deckSize == null
                                    ? 'tarjetas: créalas desde el tutor'
                                    : deckSize == 1
                                    ? 'tarjeta para repasar'
                                    : 'tarjetas para repasar',
                                color: scheme.primaryContainer,
                                onColor: scheme.onPrimaryContainer,
                                semanticLabel: 'Mis tarjetas. $flashcardsSubtitle',
                                onTap: () => context.push('/flashcards'),
                              ),
                            ),
                          ],
                        ),
                      );
                      final fits =
                          box.maxHeight - 16 - bottomGap >= MediaQuery.textScalerOf(context).scale(_minFitHeight);
                      final padding = EdgeInsets.fromLTRB(24, 16, 24, bottomGap);
                      if (!fits) {
                        return SingleChildScrollView(
                          padding: padding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Greeting(onTap: () => context.push('/tutor'), tocoHeight: 120),
                              const SizedBox(height: 16),
                              summary,
                            ],
                          ),
                        );
                      }
                      return Padding(
                        padding: padding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Center(child: _Greeting(onTap: () => context.push('/tutor'))),
                            ),
                            const SizedBox(height: 16),
                            summary,
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}

/// Alto minimo (a letra normal) para que el inicio quepa sin desplazarse: globo
/// con el aviso de bateria, un Toco pequeno y el resumen.
const double _minFitHeight = 400;

/// Toco grande con un globo de bienvenida. Tocarlo abre el tutor. Con poca
/// bateria el globo trae el aviso y sus botones en lugar del saludo.
class _Greeting extends ConsumerWidget {
  const _Greeting({required this.onTap, this.tocoHeight});

  final VoidCallback onTap;

  /// Alto fijo de Toco; sin el, Toco ocupa el alto que deje el globo (hasta [_maxToco]).
  final double? tocoHeight;

  static const _maxToco = 340.0;
  static const _minToco = 72.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final lowBattery = ref.watch(lowBatterySuggestionProvider);
    Widget toco(double h) => MascotView(mood: const MascotMood(MascotActivity.idle), height: h, onTap: onTap);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(24)),
            child: lowBattery
                ? const LowBatteryMessage(center: true)
                : Text(
                    '¿Qué aprendemos hoy?',
                    textAlign: TextAlign.center,
                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        // Pico del globo, apuntando a Toco.
        CustomPaint(size: const Size(24, 12), painter: _BubbleTail(scheme.surfaceContainerHigh)),
        const SizedBox(height: 4),
        if (tocoHeight != null)
          toco(tocoHeight!)
        else
          Flexible(
            child: LayoutBuilder(
              builder: (context, box) {
                final h = box.maxHeight.isFinite ? box.maxHeight.clamp(0.0, _maxToco) : _maxToco;
                return h < _minToco ? const SizedBox.shrink() : toco(h);
              },
            ),
          ),
      ],
    );
  }
}

class _BubbleTail extends CustomPainter {
  const _BubbleTail(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BubbleTail old) => old.color != color;
}

/// Resumen pequeño (medallas o tarjetas) que abre su pantalla.
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.value,
    required this.caption,
    required this.color,
    required this.onColor,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String caption;
  final Color color;
  final Color onColor;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Card(
          color: color,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: onColor, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        value,
                        style: text.headlineMedium?.copyWith(color: onColor, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(caption, style: text.bodyMedium?.copyWith(color: onColor)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El nino en la barra: su avatar y su nombre. Tocarlo vuelve a elegir perfil.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.avatar, required this.name, required this.onTap});

  final String avatar;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$name. Cambiar de perfil',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 52,
                  child: Center(child: AvatarView(avatar: avatar, radius: 22)),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
