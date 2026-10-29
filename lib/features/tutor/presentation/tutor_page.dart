import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/responsive/max_content_width.dart';
import '../../../core/utils/school_grade_calculator.dart';
import '../../../core/widgets/offline_badge.dart';
import '../../auth/application/session.dart';
import '../../achievements/presentation/medal_toast.dart';
import '../../mascot/application/mascot_settings.dart';
import '../../mascot/domain/mascot_cheers.dart';
import '../../mascot/domain/mascot_mood.dart';
import '../../mascot/presentation/mascot_view.dart';
import '../../pomodoro/application/pomodoro.dart';
import '../../quiz/presentation/quiz_page.dart';
import '../../speech/application/speech_controller.dart';
import '../../speech/presentation/speak_button.dart';
import '../application/tutor_controller.dart';
import '../domain/tutor_prompt.dart';
import '../domain/tutor_source.dart';

/// Chat con el tutor, acompanado de Toco, la mascota: grande al saludar y
/// mientras el modelo piensa, pequena junto al nombre mientras se lee.
class TutorPage extends ConsumerStatefulWidget {
  const TutorPage({super.key});

  @override
  ConsumerState<TutorPage> createState() => _TutorPageState();
}

class _TutorPageState extends ConsumerState<TutorPage> with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  /// Pregunta del tutor que el nino toco para contestarla: se muestra sobre la
  /// caja de texto y su siguiente mensaje se trata como respuesta.
  String? _replyingTo;

  /// Mensaje de animo que Toco dice al tocarlo; se desvanece solo.
  String? _cheer;
  int _cheers = 0;

  void _onMascotTap() {
    setState(() => _cheer = mascotCheer(_cheers++));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // El Pomodoro cuenta el estudio mientras el chat esta abierto y a la vista.
    ref.read(pomodoroProvider.notifier).resume();
    final every = ref.read(pomodoroTickProvider);
    if (every != null) _pomodoroTimer = Timer.periodic(every, (_) => _tickPomodoro());
    // Cargar el modelo tarda unos segundos: se empieza al entrar, no al preguntar.
    Future.microtask(() => ref.read(tutorControllerProvider.notifier).prepare());
  }

  Timer? _pomodoroTimer;
  PomodoroController? _pomodoro;
  SpeechController? _speech;
  PomodoroPlan _plan = PomodoroPlan.forGrade(1);

  void _tickPomodoro() {
    if (!mounted || !ref.read(pomodoroEnabledProvider)) return;
    ref
        .read(pomodoroProvider.notifier)
        .tick(_plan, busy: ref.read(tutorControllerProvider).generating);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(pomodoroProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      notifier.resume();
      _tickPomodoro();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      notifier.pause();
      _speech?.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pomodoro = ref.read(pomodoroProvider.notifier);
    _speech = ref.read(speechProvider.notifier);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pomodoroTimer?.cancel();
    _pomodoro?.pause();
    _speech?.stop();
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send(int grade) {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    final answering = _replyingTo != null;
    ref.read(speechProvider.notifier).stop();
    _input.clear();
    setState(() => _replyingTo = null);
    ref.read(tutorControllerProvider.notifier).ask(text, grade: grade, answering: answering);
  }

  /// Toca la pregunta del tutor: queda a la vista y se abre el teclado.
  void _answer(String question) {
    setState(() => _replyingTo = question);
    _focus.requestFocus();
  }

  void _scrollToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(end, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
      } else {
        _scroll.jumpTo(end);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final childId = ref.watch(sessionProvider).activeChildId;
    final child = ref.watch(childProfilesProvider).value?.where((c) => c.id == childId).firstOrNull;
    final tutor = ref.watch(tutorControllerProvider);
    ref.listen(tutorControllerProvider.select((s) => s.messages), (_, _) => _scrollToEnd());
    // La conversacion guardada se carga mientras se prepara el tutor: al quedar
    // listo se muestra de golpe por el final, donde el nino se quedo.
    ref.listen(tutorControllerProvider.select((s) => s.status), (_, status) {
      if (status == TutorStatus.ready) _scrollToEnd(animate: false);
    });

    final grade = child?.gradeAt(ref.read(clockProvider)());
    if (grade != null) _plan = PomodoroPlan.forGrade(grade);
    final pomodoro = ref.watch(pomodoroProvider);
    final resting = ref.watch(pomodoroEnabledProvider) && pomodoro.resting;
    // El quiz se hace sobre un tema ya consultado y con el modelo libre.
    final quizReady = tutor.status == TutorStatus.ready &&
        !tutor.generating &&
        tutor.messages.any((m) => !m.fromUser && m.sources.isNotEmpty);
    final ready = tutor.status == TutorStatus.ready;
    final mascotOn = ref.watch(mascotEnabledProvider);
    var mood = moodFor(tutor, replying: _replyingTo != null && !tutor.generating);
    // Al tocarlo, Toco se alegra un momento (si no esta ocupado con la respuesta).
    if (_cheer != null && mood.activity == MascotActivity.idle) {
      mood = const MascotMood(MascotActivity.idle, MascotEmotion.happy);
    }
    // Grande al saludar, mientras carga y mientras espera la primera palabra;
    // pequena el resto. Con el teclado abierto o en pantallas bajas, siempre
    // pequena para no quitar sitio al chat.
    final screen = MediaQuery.sizeOf(context);
    final roomy = MediaQuery.viewInsetsOf(context).bottom == 0 && screen.height >= 500;
    final waiting = mood.activity == MascotActivity.thinking;
    final bigMascot = mascotOn && roomy && (!ready || tutor.messages.isEmpty || waiting);
    final bigHeight = (screen.height * 0.21).clamp(130.0, 200.0);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Hacer un quiz',
            icon: const Icon(Icons.quiz_rounded),
            onPressed: !quizReady || grade == null
                ? null
                : () {
                    ref.read(speechProvider.notifier).stop();
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => QuizPage(grade: grade),
                    ));
                  },
          ),
          const Padding(padding: EdgeInsets.only(right: 12), child: OfflineBadge(iconOnly: true)),
        ],
        // El inicio del nino es la pantalla anterior; la flecha vuelve a el.
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: child == null || grade == null
            ? const Center(child: CircularProgressIndicator())
            : resting
            ? _RestView(
                state: pomodoro,
                mascotOn: mascotOn,
                height: bigHeight,
                onContinue: () => ref.read(pomodoroProvider.notifier).finishRest(),
              )
            : MaxContentWidth(
                child: Column(
                  children: [
                    if (mascotOn)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        alignment: Alignment.topCenter,
                        // Al encoger o crecer la mascota la lista cambia de alto:
                        // se vuelve al final para que la ultima pregunta se vea.
                        onEnd: _scrollToEnd,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: MascotView(
                            mood: mood,
                            height: bigMascot ? bigHeight : 52,
                            size: bigMascot ? MascotSize.large : MascotSize.small,
                            onTap: _onMascotTap,
                          ),
                        ),
                      ),
                    const MedalToast(),
                    if (_cheer != null)
                      _CheerBubble(
                        key: ValueKey(_cheer! + _cheers.toString()),
                        text: _cheer!,
                        onDone: () => setState(() => _cheer = null),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Column(
                        children: [
                          Text(
                            '¡Hola, ${child.name}!',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            SchoolGradeCalculator.label(grade),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _body(context, tutor)),
                    if (ready && _replyingTo != null && !tutor.generating)
                      _ReplyBanner(
                        question: _replyingTo!,
                        onCancel: () => setState(() => _replyingTo = null),
                      ),
                    if (ready)
                      _InputBar(
                        controller: _input,
                        focusNode: _focus,
                        hint: _replyingTo == null
                            ? 'Escribe tu pregunta…'
                            : 'Escribe tu respuesta…',
                        generating: tutor.generating,
                        onSend: () => _send(grade),
                        onStop: () => ref.read(tutorControllerProvider.notifier).stop(),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _body(BuildContext context, TutorState tutor) {
    switch (tutor.status) {
      case TutorStatus.idle:
      case TutorStatus.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Preparando a tu tutor…'),
            ],
          ),
        );
      case TutorStatus.needsFiles:
      case TutorStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tutor.status == TutorStatus.error
                      ? Icons.error_outline_rounded
                      : Icons.folder_open_rounded,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  tutor.problem ?? 'Pide a un adulto que revise la zona de padres.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.read(tutorControllerProvider.notifier).prepare(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        );
      case TutorStatus.ready:
        if (tutor.messages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Soy Toco, tu tutor. Pregúntame lo que quieras aprender de tus libros.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          );
        }
        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          itemCount: tutor.messages.length,
          itemBuilder: (_, i) {
            final message = tutor.messages[i];
            // Solo la ultima respuesta del tutor ofrece su pregunta como boton.
            final isLast = i == tutor.messages.length - 1;
            final question = isLast && !message.fromUser && !message.streaming
                ? TutorPrompt.lastQuestion(message.text)
                : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bubble(index: i, message: message),
                if (question != null)
                  _QuestionButton(
                    question: question,
                    selected: _replyingTo == question,
                    onTap: () => _answer(question),
                  ),
              ],
            );
          },
        );
    }
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.index, required this.message});

  /// Posicion en la conversacion: identifica el mensaje para la voz.
  final int index;
  final TutorMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.fromUser;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
        decoration: BoxDecoration(
          color: mine ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.text.isEmpty && message.streaming)
              const _Thinking()
            else
              SelectableText(
                message.text,
                style: TextStyle(
                  fontSize: 17,
                  color: mine ? scheme.onPrimaryContainer : scheme.onSurface,
                ),
              ),
            if (message.sources.isNotEmpty && !message.streaming) ...[
              const SizedBox(height: 8),
              for (final source in message.sources) _SourceChip(source: source),
            ],
            if (!mine && !message.streaming && message.text.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: SpeakButton(messageId: index, text: message.text),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un libro y pagina en los que se apoya el tutor. Al tocarlo se abre el libro en
/// esa pagina (si el PDF esta en el telefono).
class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});

  final TutorSource source;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final book = source.book;
    final page = source.page;
    final style = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.menu_book_rounded, size: 16, color: scheme.primary),
        const SizedBox(width: 6),
        Flexible(child: Text(source.label, style: style)),
        if (book != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.open_in_new_rounded, size: 14, color: scheme.primary),
        ],
      ],
    );
    if (book == null) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: label);
    }
    return Semantics(
      button: true,
      label: 'Abrir ${source.label}',
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push('/books/$book${page == null ? '' : '?page=$page'}'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Align(alignment: Alignment.centerLeft, child: label),
          ),
        ),
      ),
    );
  }
}

/// Espera del primer token (~30 s en un telefono modesto): tres puntos que
/// saltan y un texto que cambia, para que el nino sepa que el tutor trabaja.
class _Thinking extends StatefulWidget {
  const _Thinking();

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking> with SingleTickerProviderStateMixin {
  static const _phrases = [
    'Estoy buscando en tu libro…',
    'Estoy pensando cómo explicártelo…',
    'Un momentito más…',
    'Ya casi lo tengo…',
  ];
  static const _secondsPerPhrase = 7;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();
  final _clock = Stopwatch()..start();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) {
        final phrase =
            _phrases[(_clock.elapsed.inSeconds ~/ _secondsPerPhrase).clamp(0, _phrases.length - 1)];
        return Semantics(
          label: phrase,
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Transform.translate(
                      offset: Offset(0, -6 * _bounce((_anim.value - i * 0.15) % 1)),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    phrase,
                    style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Salto de 0 a 1 y vuelta a 0 durante el primer tercio del ciclo; luego reposo.
  static double _bounce(double t) => t < 0.4 ? (1 - (t / 0.2 - 1).abs()).clamp(0.0, 1.0) : 0;
}

/// La pregunta con la que el tutor cierra su mensaje, como boton grande: al
/// tocarla se prepara la respuesta del nino (no se envia nada).
class _QuestionButton extends StatelessWidget {
  const _QuestionButton({required this.question, required this.selected, required this.onTap});

  final String question;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
        child: Semantics(
          button: true,
          label: 'Responder a: $question',
          child: ExcludeSemantics(
            child: FilledButton.tonal(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                backgroundColor: selected ? scheme.primary : null,
                foregroundColor: selected ? scheme.onPrimary : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected ? Icons.edit_rounded : Icons.touch_app_rounded, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(question, style: const TextStyle(fontSize: 16, height: 1.25)),
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

/// Recuerda a que pregunta se esta contestando, con una ✕ para dejarlo.
class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({required this.question, required this.onCancel});

  final String question;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Respondiendo a: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: question),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
          IconButton(tooltip: 'Quitar', onPressed: onCancel, icon: const Icon(Icons.close_rounded)),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.generating,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool generating;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !generating,
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(hintText: hint),
            ),
          ),
          const SizedBox(width: 8),
          generating
              ? IconButton.filledTonal(
                  tooltip: 'Detener',
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_rounded),
                )
              : IconButton.filled(
                  tooltip: 'Enviar',
                  onPressed: onSend,
                  icon: const Icon(Icons.send_rounded),
                ),
        ],
      ),
    );
  }
}

/// Globo con el mensaje de Toco: aparece, se queda unos segundos y se va solo
/// (con una animacion, sin `Timer`).
class _CheerBubble extends StatelessWidget {
  const _CheerBubble({super.key, required this.text, required this.onDone});

  final String text;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 5),
      onEnd: onDone,
      builder: (context, t, child) {
        // Entra en el primer 8 %, sale en el ultimo 15 %.
        final opacity =
            (t < 0.08
                    ? t / 0.08
                    : t > 0.85
                    ? (1 - t) / 0.15
                    : 1.0)
                .clamp(0.0, 1.0);
        return Opacity(opacity: opacity, child: child);
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 4, 24, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Descanso del Pomodoro: el chat esta congelado y Toco, en el centro, invita a
/// estirarse. Solo su mensaje (o tocarlo) devuelve al estudio, y solo cuando
/// la cuenta atras llego a cero.
class _RestView extends StatelessWidget {
  const _RestView({
    required this.state,
    required this.mascotOn,
    required this.height,
    required this.onContinue,
  });

  final PomodoroState state;
  final bool mascotOn;
  final double height;
  final VoidCallback onContinue;

  static String clock(Duration d) {
    final s = d.inSeconds < 0 ? 0 : d.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = state.restOver;
    final mood = MascotMood(
      MascotActivity.idle,
      over ? MascotEmotion.happy : MascotEmotion.neutral,
    );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mascotOn)
              MascotView(mood: mood, height: height, onTap: over ? onContinue : null)
            else
              const Icon(Icons.self_improvement_rounded, size: 96),
            const SizedBox(height: 12),
            Text(
              over ? '¡Descansaste muy bien!' : '¡Buen trabajo! Es hora de descansar: levántate, estira los brazos y respira hondo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (!over)
              Semantics(
                label: 'Descanso, quedan ${clock(state.restLeft)}',
                child: Text(
                  clock(state.restLeft),
                  style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('¡Listo, sigamos!'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
