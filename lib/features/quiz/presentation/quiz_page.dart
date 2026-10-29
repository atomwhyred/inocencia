import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/max_content_width.dart';
import '../../achievements/presentation/medal_toast.dart';
import '../application/quiz_controller.dart';
import '../domain/quiz_prompt.dart';

/// Quiz de 3 preguntas, una a la vez, con respuesta inmediata y sin castigo:
/// si falla, ve cual era la correcta.
class QuizPage extends ConsumerStatefulWidget {
  const QuizPage({super.key, required this.grade});

  final int grade;

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(quizControllerProvider.notifier).start(grade: widget.grade));
  }

  @override
  Widget build(BuildContext context) {
    final quiz = ref.watch(quizControllerProvider);
    final controller = ref.read(quizControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        leading: IconButton(
          tooltip: 'Cerrar el quiz',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: MaxContentWidth(
          maxWidth: 720,
          child: switch (quiz.status) {
            QuizStatus.preparing => const _Message(
              icon: null,
              text: 'Toco está preparando tu quiz…',
            ),
            QuizStatus.failed => _Message(
              icon: Icons.sentiment_neutral_rounded,
              text: quiz.message ?? QuizController.unavailable,
              action: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Volver al chat'),
              ),
            ),
            QuizStatus.waiting => const _Message(
              icon: null,
              text: 'Toco está escribiendo la siguiente pregunta…',
            ),
            QuizStatus.finished => _Result(quiz: quiz, onClose: () => Navigator.of(context).pop()),
            _ => _Question(quiz: quiz, controller: controller),
          },
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData? icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == null) const CircularProgressIndicator() else Icon(icon, size: 64),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.quiz, required this.controller});

  final QuizState quiz;
  final QuizController controller;

  static const _letters = ['A', 'B', 'C'];

  @override
  Widget build(BuildContext context) {
    final q = quiz.question!;
    final answered = quiz.status == QuizStatus.answered;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Pregunta ${quiz.index + 1} de ${quiz.questions.length}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Text(q.text, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        for (var i = 0; i < q.options.length; i++) ...[
          _OptionButton(
            letter: _letters[i],
            text: q.options[i],
            state: !answered
                ? _OptionState.idle
                : i == q.correct
                ? _OptionState.right
                : i == quiz.picked
                ? _OptionState.wrong
                : _OptionState.idle,
            onTap: answered ? null : () => controller.answer(i),
          ),
          const SizedBox(height: 12),
        ],
        if (answered) ...[
          const SizedBox(height: 4),
          Text(
            quiz.pickedRight
                ? '¡Muy bien! Ganaste una estrella ⭐'
                : 'Casi. La respuesta correcta era la ${_letters[q.correct]}.',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: quiz.pickedRight ? scheme.primary : scheme.onSurface),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: controller.next,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(quiz.isLast ? 'Ver mi resultado' : 'Siguiente'),
          ),
        ],
      ],
    );
  }
}

enum _OptionState { idle, right, wrong }

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String letter;
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, icon) = switch (state) {
      _OptionState.right => (scheme.primary, scheme.onPrimary, Icons.check_circle_rounded),
      _OptionState.wrong => (scheme.errorContainer, scheme.onErrorContainer, Icons.cancel_rounded),
      _OptionState.idle => (scheme.surfaceContainerHigh, scheme.onSurface, null),
    };
    return Semantics(
      button: true,
      label: 'Opción $letter: $text',
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: fg.withValues(alpha: 0.15),
                  child: Text(
                    letter,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text, style: TextStyle(fontSize: 18, color: fg)),
                ),
                if (icon != null) Icon(icon, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.quiz, required this.onClose});

  final QuizState quiz;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final total = quiz.questions.length;
    final theme = Theme.of(context);
    final text = quiz.correct == total
        ? '¡Perfecto! Acertaste todas.'
        : quiz.correct == 0
        ? 'No pasa nada: repasa el tema con Toco y lo intentas otra vez.'
        : '¡Buen trabajo! Sigue practicando.';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const MedalToast(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < QuizPrompt.questions && i < total; i++)
              Icon(
                i < quiz.correct ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 56,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            'Acertaste ${quiz.correct} de $total',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.chat_bubble_rounded),
            label: const Text('Volver al chat'),
          ),
        ),
      ],
    );
  }
}
