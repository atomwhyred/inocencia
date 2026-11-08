import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/utils/school_grade_calculator.dart';
import '../application/lan_game_controller.dart';
import '../domain/game_rules.dart';
import 'game_widgets.dart';
import 'local_game_page.dart';

/// Partida entre teléfonos por Wi-Fi local o punto de acceso (sin internet).
class LanGamePage extends ConsumerStatefulWidget {
  const LanGamePage({super.key, required this.mode});

  final GameMode mode;

  @override
  ConsumerState<LanGamePage> createState() => _LanGamePageState();
}

class _LanGamePageState extends ConsumerState<LanGamePage> {
  final _ip = TextEditingController();

  @override
  void dispose() {
    _ip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(lanGameProvider);
    final c = ref.read(lanGameProvider.notifier);
    ref.listen(lanGameProvider.select((v) => v.phase), (prev, next) {
      if (prev == LanPhase.asking && next == LanPhase.waiting) {
        final v = ref.read(lanGameProvider);
        v.picked == v.question?.quiz.correct
            ? HapticFeedback.lightImpact()
            : HapticFeedback.selectionClick();
      }
    });
    final inGame =
        view.phase == LanPhase.asking || view.phase == LanPhase.waiting;
    final inRoom =
        inGame ||
        view.phase == LanPhase.hosting ||
        view.phase == LanPhase.lobby;
    return PopScope(
      canPop: !inRoom,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmLeave(context) && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.mode == GameMode.race
                ? 'Carrera con otros teléfonos'
                : 'Entre todos, en red',
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: switch (view.phase) {
                LanPhase.choose => _Choose(
                  onHost: () => c.host(widget.mode),
                  onSearch: c.search,
                ),
                LanPhase.preparing || LanPhase.connecting => const Center(
                  child: CircularProgressIndicator(),
                ),
                LanPhase.hosting => _HostLobby(
                  view: view,
                  onStart: c.startGame,
                ),
                LanPhase.searching => _Search(
                  view: view,
                  ip: _ip,
                  onJoin: c.join,
                ),
                LanPhase.lobby => _Players(
                  title: 'Ya estás en la sala',
                  subtitle: 'Espera a que el anfitrión empiece la partida.',
                  view: view,
                ),
                LanPhase.asking || LanPhase.waiting => _Round(view: view),
                LanPhase.finished => GameResults(
                  game: view.game!,
                  stars: {if (view.myId != null) view.myId!: view.myStars ?? 0},
                ),
                LanPhase.error => _Error(message: view.message ?? ''),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Choose extends StatelessWidget {
  const _Choose({required this.onHost, required this.onSearch});

  final VoidCallback onHost;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Un niño crea la sala y los demás se unen.',
          textAlign: TextAlign.center,
          style: text.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Conectad todos los teléfonos al mismo Wi-Fi, o que quien crea la sala active el punto de acceso de su '
          'teléfono (no hace falta tener datos ni internet) y los demás se conecten a él.',
          textAlign: TextAlign.center,
          style: text.bodyMedium,
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 64,
          child: FilledButton.icon(
            onPressed: onHost,
            icon: const Icon(Icons.wifi_tethering_rounded),
            label: const Text('Crear sala'),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 64,
          child: FilledButton.tonalIcon(
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Unirme a una sala'),
          ),
        ),
      ],
    );
  }
}

/// Lista de jugadores de la sala, con su avatar, nombre y grado.
class _Players extends StatelessWidget {
  const _Players({
    required this.title,
    required this.subtitle,
    required this.view,
    this.footer,
  });

  final String title;
  final String subtitle;
  final LanView view;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(title, textAlign: TextAlign.center, style: text.headlineSmall),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center, style: text.bodyMedium),
        const SizedBox(height: 16),
        for (final p in view.players)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: PlayerTag(
                player: p,
                radius: 22,
                trailing: p.id == view.myId
                    ? const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Chip(label: Text('Tú')),
                      )
                    : null,
              ),
            ),
          ),
        if (view.players.isEmpty)
          const Center(child: CircularProgressIndicator()),
        ?footer,
      ],
    );
  }
}

class _HostLobby extends StatelessWidget {
  const _HostLobby({required this.view, required this.onStart});

  final LanView view;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final enough = view.players.length >= GameRules.minPlayers;
    return _Players(
      title: 'Tu sala está abierta',
      subtitle: view.addresses.isEmpty
          ? 'Activa el punto de acceso o conéctate a un Wi-Fi para que te encuentren.'
          : 'Si no te encuentran, que escriban esta dirección al unirse:',
      view: view,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in view.addresses)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SelectableText(
                a,
                textAlign: TextAlign.center,
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            height: 60,
            child: FilledButton.icon(
              onPressed: enough ? onStart : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                enough
                    ? '¡Empezar! (${view.players.length} jugadores)'
                    : 'Esperando a otro jugador…',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search({required this.view, required this.ip, required this.onJoin});

  final LanView view;
  final TextEditingController ip;
  final ValueChanged<String> onJoin;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Salas cercanas', style: text.titleLarge),
        const SizedBox(height: 8),
        if (view.rooms.isEmpty)
          const ListTile(
            leading: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            title: Text(
              'Buscando… (conéctate al mismo Wi-Fi o punto de acceso)',
            ),
          ),
        for (final r in view.rooms)
          Card(
            child: ListTile(
              leading: const Icon(Icons.sports_esports_rounded, size: 32),
              title: Text('Sala de ${r.name}'),
              subtitle: Text(
                '${SchoolGradeCalculator.label(r.grade)} · '
                '${r.mode == GameMode.race ? 'Carrera' : 'Entre todos'} · ${r.players} jugando',
              ),
              trailing: FilledButton(
                onPressed: () => onJoin(r.host),
                child: const Text('Entrar'),
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          '¿No aparece? Escribe la dirección que muestra el anfitrión:',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ip,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  hintText: '192.168.43.1',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                if (ip.text.trim().isNotEmpty) onJoin(ip.text);
              },
              child: const Text('Entrar'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Round extends ConsumerWidget {
  const _Round({required this.view});

  final LanView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = view.game!;
    final me = view.me;
    final q = view.question;
    final text = Theme.of(context).textTheme;
    final waiting = view.phase == LanPhase.waiting;
    final board = game.mode == GameMode.race
        ? RaceTrack(game: game, highlight: view.myId)
        : TeamNest(game: game);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Ronda ${game.round}',
          textAlign: TextAlign.center,
          style: text.titleMedium,
        ),
        const SizedBox(height: 8),
        board,
        const SizedBox(height: 16),
        if (q != null && me != null) ...[
          if (!waiting && view.deadline != null)
            CountdownBar(
              deadline: view.deadline!,
              total: GameRules.timeFor(me.grade),
              now: ref.read(clockProvider),
            ),
          const SizedBox(height: 12),
          if (q.ownCard)
            const Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: Icon(Icons.style_rounded, size: 18),
                label: Text('Tu tarjeta · vale 2'),
              ),
            ),
          Text(
            q.quiz.text,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          AnswerOptions(
            options: q.quiz.options,
            onPick: waiting ? null : ref.read(lanGameProvider.notifier).pick,
            correct: waiting ? q.quiz.correct : null,
            picked: view.picked,
          ),
          if (waiting) ...[
            Center(
              child: view.picked == q.quiz.correct
                  ? PointsPop(points: q.points)
                  : Text(
                      view.picked == -1 ? '¡Se acabó el tiempo!' : '¡Casi!',
                      style: text.titleLarge,
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              'Esperando a: ${[for (final p in game.players)
                if (!game.answered.contains(p.id)) p.name].join(', ')}',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ],
        ],
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_off_rounded, size: 56),
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
