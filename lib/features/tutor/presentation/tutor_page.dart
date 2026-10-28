import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/responsive/max_content_width.dart';
import '../../../core/utils/school_grade_calculator.dart';
import '../../../core/widgets/offline_badge.dart';
import '../../auth/application/session.dart';
import '../../profiles/presentation/avatar_view.dart';
import '../application/tutor_controller.dart';
import '../domain/tutor_prompt.dart';

/// Chat con el tutor. La version actual es funcional pero sencilla: el diseno
/// infantil definitivo (burbujas, animaciones) llega mas adelante.
class TutorPage extends ConsumerStatefulWidget {
  const TutorPage({super.key});

  @override
  ConsumerState<TutorPage> createState() => _TutorPageState();
}

class _TutorPageState extends ConsumerState<TutorPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  /// Pregunta del tutor que el nino toco para contestarla: se muestra sobre la
  /// caja de texto y su siguiente mensaje se trata como respuesta.
  String? _replyingTo;

  @override
  void initState() {
    super.initState();
    // Cargar el modelo tarda unos segundos: se empieza al entrar, no al preguntar.
    Future.microtask(() => ref.read(tutorControllerProvider.notifier).prepare());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send(int grade) {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    final answering = _replyingTo != null;
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
    final child = ref
        .watch(childProfilesProvider)
        .value
        ?.where((c) => c.id == childId)
        .firstOrNull;
    final tutor = ref.watch(tutorControllerProvider);
    ref.listen(tutorControllerProvider.select((s) => s.messages), (_, _) => _scrollToEnd());
    // La conversacion guardada se carga mientras se prepara el tutor: al quedar
    // listo se muestra de golpe por el final, donde el nino se quedo.
    ref.listen(tutorControllerProvider.select((s) => s.status), (_, status) {
      if (status == TutorStatus.ready) _scrollToEnd(animate: false);
    });

    final grade = child?.gradeAt(ref.read(clockProvider)());
    final ready = tutor.status == TutorStatus.ready;

    return Scaffold(
      appBar: AppBar(
        title: const OfflineBadge(compact: true),
        leading: IconButton(
          tooltip: 'Cambiar de perfil',
          icon: const Icon(Icons.swap_horiz_rounded),
          onPressed: () {
            ref.read(sessionProvider.notifier).clearChild();
            context.go('/');
          },
        ),
      ),
      body: SafeArea(
        child: child == null || grade == null
            ? const Center(child: CircularProgressIndicator())
            : MaxContentWidth(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          AvatarView(avatar: child.avatar, radius: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('¡Hola, ${child.name}!',
                                    style: Theme.of(context).textTheme.titleMedium),
                                Text(SchoolGradeCalculator.label(grade),
                                    style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
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
                    if (ready) _InputBar(
                      controller: _input,
                      focusNode: _focus,
                      hint: _replyingTo == null ? 'Escribe tu pregunta…' : 'Escribe tu respuesta…',
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
                'Pregúntame lo que quieras aprender de tus libros.',
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
                _Bubble(message: message),
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
  const _Bubble({required this.message});

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.menu_book_rounded, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      message.sources.map((s) => s.label).join('\n'),
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ],
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

  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
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
        final phrase = _phrases[(_clock.elapsed.inSeconds ~/ _secondsPerPhrase).clamp(0, _phrases.length - 1)];
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
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Respondiendo a: ', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: question),
              ]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
          IconButton(
            tooltip: 'Quitar',
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded),
          ),
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
