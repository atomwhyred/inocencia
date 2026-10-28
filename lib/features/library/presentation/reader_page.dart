import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../auth/application/session.dart';
import '../domain/library_book.dart';
import '../domain/reading_progress_repository.dart';
import 'book_viewer.dart';

/// Lee un libro como un libro digital y recuerda por que pagina va el nino.
///
/// [page] es la pagina a la que abrir (p. ej. la que cita una fuente del tutor);
/// sin ella se abre por la ultima pagina guardada.
class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({super.key, required this.bookId, this.page});

  final String bookId;
  final int? page;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  /// Espera tras el ultimo cambio de pagina antes de guardar, para no escribir
  /// en la base a cada fotograma del desplazamiento.
  static const saveDelay = Duration(milliseconds: 700);

  late final BookViewerFactory _viewer;
  late final BookViewerController _controller;
  late final ReadingProgressRepository _progress;
  late final int? _childId;

  LibraryBook? _book;
  int? _startPage;
  bool _loading = true;
  int? _page;
  int? _pendingSave;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    // Se guardan aqui porque `ref` ya no se puede usar en `dispose`.
    _viewer = ref.read(bookViewerFactoryProvider);
    _controller = _viewer.createController();
    _progress = ref.read(readingProgressRepositoryProvider);
    _childId = ref.read(sessionProvider).activeChildId;
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _flush();
    super.dispose();
  }

  Future<void> _load() async {
    final book = await ref.read(libraryRepositoryProvider).find(widget.bookId);
    final saved = _childId == null ? null : await _progress.get(_childId, widget.bookId);
    if (!mounted) return;
    setState(() {
      _book = book;
      // Una pagina pedida (fuente del tutor) gana a la guardada; siempre dentro del libro.
      _startPage = _clamp(widget.page ?? saved ?? 1, book?.pages);
      _page = _startPage;
      _loading = false;
    });
  }

  static int _clamp(int page, int? total) {
    if (page < 1) return 1;
    if (total != null && total > 0 && page > total) return total;
    return page;
  }

  void _onPageChanged(int? page) {
    if (page == null) return;
    if (mounted) setState(() => _page = page);
    _pendingSave = page;
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, _flush);
  }

  /// Guarda la ultima pagina vista. Un fallo de la base no debe impedir leer.
  void _flush() {
    final page = _pendingSave;
    final childId = _childId;
    if (page == null || childId == null) return;
    _pendingSave = null;
    unawaited(_progress.save(childId, widget.bookId, page).catchError((Object e) {
      if (kDebugMode) debugPrint('[lector] no se pudo guardar la página: $e');
    }));
  }

  Future<void> _jumpTo(int page) async {
    if (!_controller.isReady) return;
    await _controller.goToPage(_clamp(page, _controller.pageCount));
  }

  Future<void> _askPage() async {
    final total = _book?.pages ?? (_controller.isReady ? _controller.pageCount : null);
    final go = await showDialog<int>(
      context: context,
      builder: (_) => _GoToPageDialog(total: total),
    );
    if (go != null) await _jumpTo(go);
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    return Scaffold(
      appBar: AppBar(
        title: Text(book?.title ?? 'Libro'),
        actions: [
          if (book != null && book.available)
            IconButton(
              tooltip: 'Ir a una página',
              icon: const Icon(Icons.pin_outlined),
              onPressed: _askPage,
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : book == null || !book.available
                ? _Missing(book: book)
                : _viewerFor(book),
      ),
      bottomNavigationBar: _loading || book == null || !book.available
          ? null
          : _PageBar(
              page: _page ?? 1,
              total: book.pages,
              onPrevious: (_page ?? 1) > 1 ? () => _jumpTo((_page ?? 1) - 1) : null,
              onNext: (_page ?? 1) < book.pages ? () => _jumpTo((_page ?? 1) + 1) : null,
              onTapPage: _askPage,
            ),
    );
  }

  Widget _viewerFor(LibraryBook book) => _viewer.build(
        context,
        BookViewerRequest(
          path: book.path!,
          initialPage: _startPage ?? 1,
          controller: _controller,
          onPageChanged: _onPageChanged,
          background: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
      );
}

class _PageBar extends StatelessWidget {
  const _PageBar({
    required this.page,
    required this.total,
    required this.onPrevious,
    required this.onNext,
    required this.onTapPage,
  });

  final int page;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onTapPage;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Página anterior',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: TextButton(
                  onPressed: onTapPage,
                  child: Text(
                    'Página $page de $total',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Página siguiente',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.book});

  final LibraryBook? book;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_for_offline_outlined,
                  size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                book == null ? 'No encuentro este libro.' : 'Este libro aún no está en el teléfono.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Pide a un adulto que lo copie desde la zona de padres.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
}

/// "Ir a la pagina". Es un widget propio para que el controlador del campo se
/// destruya con el dialogo: si se destruyera al cerrarlo, la animacion de salida
/// seguiria usandolo.
class _GoToPageDialog extends StatefulWidget {
  const _GoToPageDialog({required this.total});

  final int? total;

  @override
  State<_GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<_GoToPageDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ir a la página'),
      content: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Número de página',
          helperText: widget.total == null ? null : 'Del 1 al ${widget.total}',
        ),
        onSubmitted: (v) => Navigator.pop(context, int.tryParse(v)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, int.tryParse(_text.text)),
          child: const Text('Ir'),
        ),
      ],
    );
  }
}
