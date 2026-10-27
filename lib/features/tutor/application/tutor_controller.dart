import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/storage/platform_info.dart';
import '../../external_data/domain/linked_file_status.dart';
import '../../knowledge/data/fts_query.dart';
import '../../knowledge/data/knowledge_repository_impl.dart';
import '../../knowledge/domain/knowledge_chunk.dart';
import '../data/llama_tutor_engine.dart';
import '../domain/tutor_engine.dart';
import '../domain/tutor_prompt.dart';

/// Se sobrescriben en las pruebas.
final tutorEngineProvider = Provider.autoDispose<TutorEngine>((ref) {
  final engine = LlamaTutorEngine(
    nativeLibraryDir: const PlatformInfo().nativeLibraryDir,
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final knowledgeRepositoryFactoryProvider =
    Provider<KnowledgeRepository Function(String path)>(
  (ref) => KnowledgeRepositoryImpl.open,
);

enum TutorStatus {
  /// Aun no se ha intentado preparar el tutor.
  idle,

  /// Faltan o fallan el modelo o los libros: lo arregla el padre.
  needsFiles,
  loading,
  ready,
  error,
}

class TutorMessage extends Equatable {
  const TutorMessage({
    required this.fromUser,
    required this.text,
    this.sources = const [],
    this.streaming = false,
  });

  final bool fromUser;
  final String text;

  /// Libros y paginas en los que se apoya la respuesta.
  final List<String> sources;
  final bool streaming;

  TutorMessage copyWith({String? text, List<String>? sources, bool? streaming}) =>
      TutorMessage(
        fromUser: fromUser,
        text: text ?? this.text,
        sources: sources ?? this.sources,
        streaming: streaming ?? this.streaming,
      );

  @override
  List<Object?> get props => [fromUser, text, sources, streaming];
}

class TutorState extends Equatable {
  const TutorState({
    this.status = TutorStatus.idle,
    this.messages = const [],
    this.problem,
  });

  final TutorStatus status;
  final List<TutorMessage> messages;

  /// Explicacion para el padre cuando [status] es needsFiles o error.
  final String? problem;

  bool get generating => messages.isNotEmpty && messages.last.streaming;

  TutorState copyWith({TutorStatus? status, List<TutorMessage>? messages, String? problem}) =>
      TutorState(
        status: status ?? this.status,
        messages: messages ?? this.messages,
        problem: problem,
      );

  @override
  List<Object?> get props => [status, messages, problem];
}

/// Conversa con el nino: busca en los libros de su grado y deja que el modelo
/// local explique lo encontrado.
class TutorController extends Notifier<TutorState> {
  KnowledgeRepository? _knowledge;
  late TutorEngine _engine;
  StreamSubscription<String>? _sub;
  Completer<void>? _running;

  @override
  TutorState build() {
    // `watch` (no `read`): el motor es autoDispose y solo sigue vivo mientras
    // alguien lo observe; con `read` se destruia a mitad de cargar el modelo.
    _engine = ref.watch(tutorEngineProvider);
    ref.onDispose(() async {
      await _sub?.cancel();
      await _knowledge?.close();
    });
    return const TutorState();
  }

  /// Valida los archivos externos y carga el modelo. Se llama al abrir el chat.
  Future<void> prepare() async {
    if (state.status == TutorStatus.loading || state.status == TutorStatus.ready) return;
    state = state.copyWith(status: TutorStatus.loading);
    try {
      final files = await ref.read(externalFilesRepositoryProvider).check();
      if (!files.model.isReady || !files.knowledge.isReady) {
        state = state.copyWith(
          status: TutorStatus.needsFiles,
          problem: _filesProblem(files),
        );
        return;
      }
      await _knowledge?.close();
      _knowledge = ref.read(knowledgeRepositoryFactoryProvider)(files.knowledge.path!);
      await _engine.load(files.model.path!);
      state = state.copyWith(status: TutorStatus.ready);
    } on TutorEngineException catch (e) {
      state = state.copyWith(status: TutorStatus.error, problem: e.message);
    } catch (e) {
      state = state.copyWith(status: TutorStatus.error, problem: 'No se pudo preparar el tutor: $e');
    }
  }

  static String _filesProblem(LinkedFilesStatus f) {
    final parts = <String>[
      if (!f.model.isReady) 'el modelo de IA${f.model.message == null ? '' : ' (${f.model.message})'}',
      if (!f.knowledge.isReady) 'los libros${f.knowledge.message == null ? '' : ' (${f.knowledge.message})'}',
    ];
    return 'Falta vincular ${parts.join(' y ')} en la zona de padres.';
  }

  /// Pregunta del nino. [grade] es el grado del perfil activo: solo se
  /// consultan los libros de ese grado.
  Future<void> ask(String text, {required int grade}) async {
    final question = text.trim();
    if (question.isEmpty || state.status != TutorStatus.ready || state.generating) return;

    final history = _historyTurns();
    final previousQuestion =
        state.messages.where((m) => m.fromUser).map((m) => m.text).lastOrNull;
    state = state.copyWith(messages: [
      ...state.messages,
      TutorMessage(fromUser: true, text: question),
      const TutorMessage(fromUser: false, text: '', streaming: true),
    ]);

    try {
      // "¿y el plural?" no tiene terminos propios: se apoya en la pregunta anterior.
      final query = keyTerms(question).length < 2 && previousQuestion != null
          ? '$previousQuestion $question'
          : question;
      final chunks = await _knowledge!.search(query, grade: grade);

      if (chunks.isEmpty) {
        final subjects = await _knowledge!.subjectsForGrade(grade);
        _finish(TutorPrompt.noResults(grade, subjects));
        return;
      }

      _setLast(sources: _sources(chunks));
      final turns = TutorPrompt.build(
        grade: grade,
        chunks: chunks,
        history: history,
        question: question,
      );
      await _generate(turns);
    } catch (e) {
      _finish('Ups, algo salió mal y no pude responder. Inténtalo de nuevo.');
    }
  }

  List<String> _sources(List<KnowledgeChunk> chunks) =>
      {for (final c in chunks) TutorPrompt.sourceLabel(c)}.toList();

  List<ChatTurn> _historyTurns() => [
        for (final m in state.messages)
          if (m.text.isNotEmpty && !m.streaming)
            ChatTurn(m.fromUser ? 'user' : 'assistant', m.text),
      ];

  Future<void> _generate(List<ChatTurn> turns) {
    final done = Completer<void>();
    _running = done;
    final buf = StringBuffer();
    final clock = Stopwatch()..start();
    var pieces = 0;
    if (kDebugMode) {
      final chars = turns.fold<int>(0, (n, t) => n + t.content.length);
      debugPrint('[tutor] prompt: ${turns.length} turnos, $chars caracteres');
    }
    void report(String how) {
      if (kDebugMode) {
        debugPrint('[tutor] $how: $pieces piezas, ${clock.elapsedMilliseconds} ms, '
            '${buf.length} caracteres');
      }
    }

    _sub = _engine.generate(turns).listen(
      (piece) {
        if (pieces++ == 0) report('primer token');
        buf.write(piece);
        _setLast(text: buf.toString());
      },
      onError: (Object e) {
        report('error ($e)');
        _finish(buf.isEmpty ? 'No pude generar una respuesta. Inténtalo de nuevo.' : buf.toString().trim());
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        report('fin');
        final text = buf.toString().trim();
        _finish(text.isEmpty ? 'No pude generar una respuesta. Inténtalo de nuevo.' : text);
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    return done.future;
  }

  /// Detiene la respuesta en curso conservando lo que ya se haya escrito.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (state.generating) {
      final partial = state.messages.last.text.trim();
      _finish(partial.isEmpty ? '…' : partial);
    }
    final running = _running;
    if (running != null && !running.isCompleted) running.complete();
  }

  void _setLast({String? text, List<String>? sources}) {
    if (state.messages.isEmpty) return;
    final msgs = [...state.messages];
    msgs[msgs.length - 1] = msgs.last.copyWith(text: text, sources: sources);
    state = state.copyWith(messages: msgs);
  }

  void _finish(String text) {
    if (state.messages.isEmpty) return;
    final msgs = [...state.messages];
    msgs[msgs.length - 1] = msgs.last.copyWith(text: text, streaming: false);
    state = state.copyWith(messages: msgs);
  }
}

final tutorControllerProvider =
    NotifierProvider.autoDispose<TutorController, TutorState>(TutorController.new);
