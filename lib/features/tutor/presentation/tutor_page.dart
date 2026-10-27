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

/// Chat con el tutor. La version actual es funcional pero sencilla: el diseno
/// infantil definitivo (burbujas, animaciones, historial) llega en la Fase 3.
class TutorPage extends ConsumerStatefulWidget {
  const TutorPage({super.key});

  @override
  ConsumerState<TutorPage> createState() => _TutorPageState();
}

class _TutorPageState extends ConsumerState<TutorPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

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
    super.dispose();
  }

  void _send(int grade) {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(tutorControllerProvider.notifier).ask(text, grade: grade);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
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
                    if (ready) _InputBar(
                      controller: _input,
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
          itemBuilder: (_, i) => _Bubble(message: tutor.messages[i]),
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
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
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
                      message.sources.join('\n'),
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

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.generating,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
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
              enabled: !generating,
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(hintText: 'Escribe tu pregunta…'),
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
