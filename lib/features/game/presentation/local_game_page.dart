import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/utils/school_grade_calculator.dart';
import '../../profiles/domain/child_profile.dart';
import '../../profiles/presentation/avatar_view.dart';
import '../application/local_game_controller.dart';
import '../domain/game_rules.dart';
import 'game_widgets.dart';

/// Partida en un solo teléfono.
class LocalGamePage extends ConsumerStatefulWidget {
  const LocalGamePage({super.key, required this.mode, required this.kids});

  final GameMode mode;
  final List<ChildProfile> kids;

  @override
  ConsumerState<LocalGamePage> createState() => _LocalGamePageState();
}

class _LocalGamePageState extends ConsumerState<LocalGamePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () =>
          ref.read(localGameProvider.notifier).start(widget.mode, widget.kids),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(localGameProvider);
    // Acierto o fallo: una vibracion corta (parte de la respuesta inmediata).
    ref.listen(localGameProvider.select((v) => v.phase), (prev, next) {
      if (next == LocalPhase.reveal) {
        ref.read(localGameProvider).wasCorrect
            ? HapticFeedback.lightImpact()
            : HapticFeedback.selectionClick();
      }
    });
    final playing =
        view.phase != LocalPhase.finished && view.phase != LocalPhase.failed;
    return PopScope(
      canPop: !playing,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmLeave(context) && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.mode == GameMode.race
                ? 'Carrera de tocororos'
                : 'Entre todos',
          ),
          actions: [
            if (view.game != null && playing)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: Text('Ronda ${view.game!.round}')),
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: switch (view.phase) {
                LocalPhase.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                LocalPhase.failed => _Failed(message: view.message ?? ''),
                LocalPhase.finished => GameResults(
                  game: view.game!,
                  stars: view.stars,
                ),
                _ => _Playing(view: view),
              },
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmLeave(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir de la partida?'),
        content: const Text('Se perderá lo que llevan jugado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir jugando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    ) ??
    false;

class _Playing extends ConsumerWidget {
  const _Playing({required this.view});

  final LocalGameView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = view.game!;
    final player = view.player!;
    final controller = ref.read(localGameProvider.notifier);
    final text = Theme.of(context).textTheme;
    final board = game.mode == GameMode.race
        ? RaceTrack(game: game, highlight: player.id)
        : TeamNest(game: game);

    if (view.phase == LocalPhase.handOff) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          board,
          const SizedBox(height: 28),
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: laneColor(player),
              ),
              child: AvatarView(avatar: player.avatar, radius: 48),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Le toca a ${player.name}',
            textAlign: TextAlign.center,
            style: text.headlineSmall,
          ),
          Text(
            SchoolGradeCalculator.label(player.grade),
            textAlign: TextAlign.center,
            style: text.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Pásale el teléfono. Cuando lo tenga, que toque el botón.',
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 60,
            child: FilledButton.icon(
              onPressed: controller.ready,
              icon: const Icon(Icons.front_hand_rounded),
              label: const Text('¡Estoy listo!'),
            ),
          ),
        ],
      );
    }

    final q = view.question!;
    final revealed = view.phase == LocalPhase.reveal;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        board,
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: PlayerTag(player: player, radius: 16)),
            if (q.ownCard)
              Chip(
                avatar: const Icon(Icons.style_rounded, size: 18),
                label: const Text('Tu tarjeta · vale 2'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (!revealed && view.deadline != null)
          CountdownBar(
            deadline: view.deadline!,
            total: GameRules.timeFor(player.grade),
            now: ref.read(clockProvider),
          ),
        const SizedBox(height: 14),
        Text(
          q.quiz.text,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        AnswerOptions(
          options: q.quiz.options,
          onPick: revealed ? null : controller.pick,
          correct: revealed ? q.quiz.correct : null,
          picked: view.picked,
        ),
        if (revealed) ...[
          const SizedBox(height: 4),
          Center(
            child: view.wasCorrect
                ? PointsPop(points: q.points)
                : Text(
                    view.picked == -1
                        ? '¡Se acabó el tiempo!'
                        : '¡Casi! La buena está en verde.',
                    style: text.titleLarge,
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: controller.next,
              child: const Text('Siguiente'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Podio de la carrera o Toco en su nido, con las estrellas de cada uno.
class GameResults extends ConsumerWidget {
  const GameResults({
    super.key,
    required this.game,
    required this.stars,
    this.onAgain,
  });

  final GameState game;
  final Map<String, int> stars;
  final VoidCallback? onAgain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final won = game.mode == GameMode.race
        ? game.winners.isNotEmpty
        : game.teamWon;
    final names = [
      for (final p in game.players)
        if (game.winners.contains(p.id)) p.name,
    ];
    final title = game.mode == GameMode.race
        ? (names.isEmpty
              ? '¡Buena carrera!'
              : names.length == 1
              ? '¡Ganó ${names.first}!'
              : '¡Empate: ${names.join(' y ')}!')
        : (game.teamWon
              ? '¡Toco llegó a su nido!'
              : '¡Casi! Faltaron ${game.teamGoal - game.teamProgress} aciertos.');
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Image.asset('assets/splash/toco.png', height: 120),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            for (final (i, p) in game.ranking.indexed)
              Card(
                child: ListTile(
                  leading: game.mode == GameMode.race
                      ? CircleAvatar(child: Text('${i + 1}.º'))
                      : const Icon(Icons.favorite_rounded),
                  title: PlayerTag(player: p, radius: 16),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        game.mode == GameMode.race
                            ? '${game.positionOf(p.id)} ${game.positionOf(p.id) == 1 ? 'casilla' : 'casillas'}'
                            : '+${game.positionOf(p.id)} ${game.positionOf(p.id) == 1 ? 'acierto' : 'aciertos'}',
                      ),
                      Text('⭐ ${stars[p.id] ?? 0}', style: text.titleMedium),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Terminar'),
              ),
            ),
          ],
        ),
        if (won && !reducedMotion(context, ref))
          const Positioned.fill(child: Confetti()),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.menu_book_rounded, size: 56),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => context.pop(),
          child: const Text('Volver'),
        ),
      ],
    ),
  );
}
