import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/school_grade_calculator.dart';
import '../../mascot/application/mascot_settings.dart';
import '../../profiles/presentation/avatar_view.dart';
import '../domain/game_rules.dart';

/// `true` si hay que evitar movimiento (modo batería o accesibilidad del sistema).
bool reducedMotion(BuildContext context, WidgetRef ref) =>
    !ref.watch(mascotAnimateProvider) ||
    MediaQuery.disableAnimationsOf(context);

Color laneColor(GamePlayer p) =>
    Color(GameRules.laneColors[p.color % GameRules.laneColors.length]);

/// Avatar, nombre y grado de un jugador (lo que los demás ven de él).
class PlayerTag extends StatelessWidget {
  const PlayerTag({
    super.key,
    required this.player,
    this.radius = 18,
    this.trailing,
  });

  final GamePlayer player;
  final double radius;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: laneColor(player),
          ),
          child: AvatarView(avatar: player.avatar, radius: radius),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                SchoolGradeCalculator.label(player.grade),
                style: text.bodySmall,
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Carriles de la carrera: un tocororo por niño que salta de casilla en casilla.
class RaceTrack extends ConsumerWidget {
  const RaceTrack({super.key, required this.game, this.highlight});

  final GameState game;

  /// Jugador al que le toca (su carril se resalta).
  final String? highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final still = reducedMotion(context, ref);
    return Column(
      children: [
        for (final p in game.players)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              decoration: BoxDecoration(
                color: p.id == highlight
                    ? laneColor(p).withValues(alpha: 0.18)
                    : scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: p.id == highlight
                    ? Border.all(color: laneColor(p), width: 2)
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(width: 108, child: PlayerTag(player: p, radius: 14)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _Lane(
                      player: p,
                      position: game.positionOf(p.id),
                      still: still,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({
    required this.player,
    required this.position,
    required this.still,
  });

  final GamePlayer player;
  final int position;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final x = -1 + 2 * position / GameRules.raceLength;
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Casillas.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i <= GameRules.raceLength; i++)
                Container(
                  width: i == GameRules.raceLength ? 12 : 6,
                  height: i == GameRules.raceLength ? 12 : 6,
                  decoration: BoxDecoration(
                    shape: i == GameRules.raceLength
                        ? BoxShape.rectangle
                        : BoxShape.circle,
                    color: i <= position
                        ? laneColor(player)
                        : scheme.outlineVariant,
                  ),
                ),
            ],
          ),
          AnimatedAlign(
            alignment: Alignment(x, 0),
            duration: still ? Duration.zero : const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            child: Image.asset(
              'assets/splash/toco.png',
              height: 38,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modo "Entre todos": Toco vuela hacia su nido con los aciertos de todos.
class TeamNest extends ConsumerWidget {
  const TeamNest({super.key, required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final still = reducedMotion(context, ref);
    final f = (game.teamProgress / game.teamGoal).clamp(0.0, 1.0);
    return Column(
      children: [
        Text(
          '${game.teamProgress} de ${game.teamGoal} aciertos · ronda ${game.round} de ${GameRules.maxTeamRounds}',
          style: text.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  widthFactor: f,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ),
              AnimatedAlign(
                alignment: Alignment(-1 + 2 * f, 0),
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 500),
                curve: Curves.easeOutBack,
                child: Image.asset('assets/splash/toco.png', height: 50),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.cottage_rounded,
                  size: 34,
                  color: scheme.secondary,
                  semanticLabel: 'Nido',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final p in game.players)
              PlayerTag(
                player: p,
                radius: 12,
                trailing: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '+${game.positionOf(p.id)}',
                    style: text.titleSmall,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Las tres opciones. Tras responder: verde la buena, roja la elegida si falló.
class AnswerOptions extends StatelessWidget {
  const AnswerOptions({
    super.key,
    required this.options,
    required this.onPick,
    this.correct,
    this.picked,
  });

  final List<String> options;
  final ValueChanged<int>? onPick;

  /// Se rellenan al revelar la respuesta.
  final int? correct;
  final int? picked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const green = Color(0xFF2E7D32);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Builder(
              builder: (context) {
                final revealed = correct != null;
                final isRight = revealed && i == correct;
                final isWrongPick = revealed && i == picked && i != correct;
                final bg = isRight
                    ? green
                    : isWrongPick
                    ? scheme.error
                    : scheme.surfaceContainerHigh;
                final fg = isRight || isWrongPick
                    ? Colors.white
                    : scheme.onSurface;
                final state = isRight
                    ? ', correcta'
                    : isWrongPick
                    ? ', tu respuesta, incorrecta'
                    : '';
                // Cada opción es su propio botón también al revelar (si no, el lector
                // de pantalla las juntaría en una sola frase).
                return Semantics(
                  container: true,
                  button: true,
                  enabled: !revealed && onPick != null,
                  label: 'Opción ${'ABC'[i]}: ${options[i]}$state',
                  excludeSemantics: true,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: revealed || onPick == null
                            ? null
                            : () => onPick!(i),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 60),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: fg.withValues(alpha: 0.15),
                                  child: Text(
                                    'ABC'[i],
                                    style: TextStyle(
                                      color: fg,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    options[i],
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: fg),
                                  ),
                                ),
                                if (isRight)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                  ),
                                if (isWrongPick)
                                  const Icon(
                                    Icons.cancel_rounded,
                                    color: Colors.white,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Barra de tiempo que se vacía hasta [deadline].
class CountdownBar extends StatelessWidget {
  const CountdownBar({
    super.key,
    required this.deadline,
    required this.total,
    required this.now,
  });

  final DateTime deadline;
  final Duration total;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final left = deadline.difference(now());
    final start = (left.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      key: ValueKey(deadline),
      tween: Tween(begin: start, end: 0),
      duration: left.isNegative ? Duration.zero : left,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: v,
          minHeight: 10,
          color: v < 0.25
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
          semanticsLabel: 'Tiempo',
        ),
      ),
    );
  }
}

/// "+1" o "+2" que aparece con rebote y se desvanece (acierto).
class PointsPop extends ConsumerWidget {
  const PointsPop({super.key, required this.points});

  final int points;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = Theme.of(context).textTheme.displaySmall
        ?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF2E7D32));
    final label = Text('+$points', style: style);
    if (reducedMotion(context, ref)) return label;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (_, v, child) =>
          Transform.scale(scale: 0.4 + 0.6 * v, child: child),
      child: label,
    );
  }
}

/// Confeti breve al final (solo si hay movimiento).
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();
  final _bits = List.generate(
    40,
    (i) => (Random(i).nextDouble(), Random(i * 7 + 1).nextDouble(), i % 6),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(_c.value, _bits),
      ),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.bits);

  final double t;
  final List<(double, double, int)> bits;

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final paint = Paint();
    for (final (x, speed, color) in bits) {
      paint.color = Color(GameRules.laneColors[color]).withValues(alpha: 1 - t);
      final dy = Curves.easeIn.transform(t) * size.height * (0.6 + 0.6 * speed);
      final dx = sin((t * 6 + x * 10)) * 18;
      canvas.drawRect(
        Rect.fromLTWH(x * size.width + dx, dy - 20, 8, 12),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
